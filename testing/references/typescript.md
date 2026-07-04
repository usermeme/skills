# Testing in TypeScript — Vitest/Jest, React, Node services

Framework-level guidance for the TypeScript stack. The philosophy lives in [SKILL.md](../SKILL.md); this file is the "how" for this ecosystem. Vitest syntax is shown; almost everything maps 1:1 to Jest (`vi` ↔ `jest`).

## Project conventions

- Colocate unit tests with the code (`thing.ts` → `thing.test.ts`) unless the project already uses a `test/` tree — match what exists.
- Type test code as strictly as production code. `any` in tests hides exactly the bugs types would catch; if a test needs to violate a type to set up a case, that case can't happen in production and may not need a test.
- Builders over fixtures:

```ts
function makeOrder(overrides: Partial<Order> = {}): Order {
  return { id: 'ord_1', status: 'pending', items: [], total: 0, ...overrides };
}
```

## Async

- `await` every promise; enable lint rules that catch floating promises in tests (`@typescript-eslint/no-floating-promises` covers test files too).
- Test rejections with `await expect(fn()).rejects.toThrow(NotFoundError)` — not try/catch with an assertion in `catch`, which silently passes when nothing throws. If you must use try/catch, add `expect.assertions(n)`.
- Waiting on conditions: `await vi.waitFor(() => expect(listener).toHaveBeenCalled())` — never `setTimeout` sleeps.

## Time and randomness

```ts
beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

it('expires the cache entry after the TTL', async () => {
  cache.set('k', 'v', { ttlMs: 60_000 });
  await vi.advanceTimersByTimeAsync(60_001);
  expect(cache.get('k')).toBeUndefined();
});
```

- Use `advanceTimersByTimeAsync` (not the sync variant) when timers schedule promises.
- Better than faking globally: inject a clock (`now: () => Date`) into the unit — then most tests need no timer setup at all.
- Seed or inject randomness; `vi.spyOn(Math, 'random').mockReturnValue(0.5)` as a last resort.

## Module mocking — prefer injection

`vi.mock('./module')` is a heavy hammer: hoisted, whole-module, and it couples the test to the import graph. Prefer passing dependencies in (constructor/parameter injection) so tests substitute a fake with no module magic. Reserve `vi.mock` for true boundaries you can't inject (SDK singletons, config side effects), and keep the factory typed:

```ts
vi.mock('@anthropic-ai/sdk', () => ({ default: vi.fn(() => fakeClient) }));
```

## Network boundary

Use **MSW** (or `nock`) to intercept HTTP at the transport level rather than mocking your own fetch wrapper — the test then covers your request building, serialization, and error mapping for free:

```ts
const server = setupServer(
  http.get('https://api.example.com/tickets/:id', ({ params }) =>
    HttpResponse.json(makeTicket({ id: params.id as string })),
  ),
);
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: 'error'` is the important line — it turns forgotten network calls into loud failures instead of flaky timeouts.

## React — Testing Library

Test components the way a user experiences them: render, interact, assert on what's on screen.

- **Query priority**: `getByRole` (with accessible name) > `getByLabelText` > `getByText` > `getByTestId` as the escape hatch. If a component is unreachable by role/label, users of assistive tech can't reach it either — the test just found an accessibility bug.
- **`userEvent` over `fireEvent`**: `await userEvent.click(button)` simulates the real event sequence (hover, focus, click). With fake timers, create it as `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })` or interactions hang.
- **Async UI**: `await screen.findByText('Saved')` for things that appear; `await waitForElementToBeRemoved(spinner)` for things that leave. Never assert absence without first awaiting the state you expect (`queryBy*` only after settling).
- Don't assert on hook internals, state variable values, or child props — that's implementation. If logic is complex enough to test in isolation, extract it into a plain function or custom hook and test that (`renderHook`).
- Wrap providers once in a custom `render` (theme, router, query client) in `test/utils.tsx`; tests import that, not the raw one.

## Node services — routes and databases

- **Routes**: test through the HTTP interface with `supertest` (or `fetch` against `app.listen(0)`), not by calling handler functions directly — routing, middleware, parsing, and status mapping are exactly the wiring that breaks.

```ts
const response = await request(app).post('/webhook').send(payload).set('x-hub-signature-256', sig);
expect(response.status).toBe(202);
```

- **Databases**: integration-test queries against a real engine — Testcontainers, or the project's docker-compose in CI. SQLite-in-memory is only acceptable when production is SQLite; otherwise dialect differences (returning clauses, JSON operators, `ON CONFLICT`) hide real bugs. Isolate per test with a transaction rolled back in `afterEach`, or truncate between tests.
- Anything cheaper than a real DB (in-memory fake repository) belongs in unit tests of the layer above — it complements, not replaces, the handful of real-DB tests for the SQL itself.

## Snapshots

- Prefer `toMatchInlineSnapshot()` for small stable outputs — the expectation lives in the test where reviewers see diffs.
- Never snapshot whole rendered component trees or large API responses; assert the fields that constitute the contract.
- Treat a snapshot update in a PR as a behavior change requiring the same scrutiny as a code change — auto-accepting `--u` output is deleting the test's judgment.

## Vitest specifics worth knowing

- `test.each` for input/output tables — one behavior, many cases, without copy-paste:

```ts
test.each([
  ['DPL-123 in text', ['DPL-123']],
  ['no refs here', []],
])('extractRefs(%s) → %j', (input, expected) => {
  expect(provider.extractRefs(input)).toEqual(expected);
});
```

- `describe.concurrent` speeds suites, but only after tests are state-isolated (§6 of SKILL.md).
- Put global infra (containers, MSW server) in `setupFiles`; keep per-test data in the tests.
