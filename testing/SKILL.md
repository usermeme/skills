---
name: testing
description: How to write tests that catch real regressions — what deserves a test, behavior-first structure, mocking only at boundaries, unit vs integration choice, determinism, and honest assertions. Use whenever writing or modifying tests, adding coverage to existing code, fixing a failing or flaky test, writing a regression test for a bug, or implementing a feature that needs tests alongside it — even if the user didn't explicitly ask for tests. For TypeScript, Vitest/Jest, React Testing Library, or Node service tests, also read references/typescript.md.
---

# Testing

A test exists to do two jobs: **catch a regression** when someone changes the code later, and **document a behavior** precisely enough that a reader learns the contract from the test name and body. Every guideline below follows from those two jobs. A test that can't fail on a real defect, or that breaks when internals change without behavior changing, is doing neither job — it's maintenance load pretending to be safety.

**Precedence**: the project's existing test conventions win. Match the framework, file layout, and naming already in use before applying anything here.

## 1. Test behavior through the public interface

Exercise the code the way its real callers do — the exported function, the HTTP route, the rendered component — and assert on what a caller can observe: return values, emitted events, state visible through the interface, side effects at the boundary.

Don't reach into internals: private methods, internal state shape, "was this helper called". Tests coupled to internals fail on every refactor and pass on real bugs — the exact inversion of their job. If something feels impossible to test through the public surface, that's a design signal (extract it into its own unit with its own public interface), not a reason to test privates.

## 2. What deserves a test — and what doesn't

Spend tests where defects are likely and expensive:

- **Decision logic** — branches, calculations, state machines, anything with an `if`.
- **Boundaries and edge cases** — empty input, one item, maximum size, zero, negative, unicode, `null`/`undefined`, concurrent access. The bug is almost never in the happy path.
- **Error paths** — what happens when the dependency fails, the input is malformed, the timeout fires. Error handling is the least-exercised, most-shipped-broken code in most systems.
- **Every bug you fix** — write the test first, watch it fail for the same reason the bug report describes, then fix. A fix without a failing-first test may not fix the reported bug at all, and the regression can return silently.
- **Contracts others depend on** — public API shapes, serialization formats, event payloads.

Don't spend tests on: trivial pass-throughs and getters, the framework's own behavior (routing libraries route; you don't need to prove it), third-party libraries, or generated code. A test that cannot plausibly fail is not free — it costs reading time forever.

## 3. Structure and naming

- **Arrange–Act–Assert**, visibly. Setup, one action, assertions — a reader should identify the three blocks at a glance.
- **One behavior per test.** When a test asserts five unrelated things, the first failure hides the other four, and the name can't say what broke.
- **The name states the behavior and the condition**: `rejects expired tokens`, `returns empty list when no discussions match`, `retries once on 5xx then surfaces the error`. If you can't name the test this way, you don't yet know what it's testing. Never `works`, `test1`, `handles edge cases`.
- **Keep setup visible and local.** Prefer builder/factory functions with overridable defaults (`makeOrder({status: 'refunded'})`) over deep `beforeEach` chains and shared mutable fixtures — a test you can read top-to-bottom without scrolling to three hooks is a test someone will actually maintain. Shared setup is fine for infrastructure (DB connection), not for the data under test.

## 4. Mocking discipline — the more you mock, the less you've proven

Replace only what you genuinely can't or shouldn't run in a test: **the system's boundaries** — network, clock, randomness, filesystem, external services, message queues. Everything inside the boundary should be the real code, because the real code is what ships.

- **Don't mock what you own.** Mocking your own repository/service/util to test the layer above verifies your assumptions about the collaborator, not the integration — and the assumptions are exactly where bugs live.
- **Prefer fakes over interaction mocks.** An in-memory repository that actually stores and returns things lets you assert on outcomes. A mock asserting `save was called with X` couples the test to call choreography — it breaks on refactor and passes when `save` is broken.
- Assert call counts/arguments only when the calls **are** the contract (e.g., "sends exactly one email", "never calls the payment API on validation failure").
- If a test's assertions only verify that mocks were invoked, delete it or widen it — it tests the mock.

## 5. Choosing the level: unit vs integration vs end-to-end

- **Unit** (pure logic, real collaborators in-process, boundaries faked): the default for decision logic. Fast, precise failure location.
- **Integration** (real wiring — the HTTP route through the real handler, the query against a real database in a container): the only thing that catches wiring bugs — wrong SQL, mis-registered route, schema drift. Every persistence layer and route deserves a few. A unit test with the DB mocked cannot tell you your SQL is wrong.
- **End-to-end** (whole system, real UI): a handful, for the flows whose breakage is a company incident — login, checkout, publish. E2E is slow and flaky by nature; it earns its cost only on critical paths.

The common failure is a mushy middle: "unit" tests with everything mocked (prove nothing) and no integration tests (wiring unprotected). When in doubt, move one level up and mock one level less.

## 6. Determinism — a flaky test is worse than no test

A test that fails 2% of the time trains everyone to click retry, which means the day it fails for a real reason, nobody looks. Flakiness has a short list of causes; eliminate them mechanically:

- **Time**: never depend on wall-clock. Inject the clock or use the framework's fake timers. No `sleep(500)` and hope — wait on the actual condition with a timeout.
- **Network**: no real network in unit/integration tests. Intercept at the boundary.
- **Shared state**: each test creates what it needs and cleans up; runnable in any order and in parallel. A test that depends on another test's leftovers is one reordering away from red.
- **Randomness**: seed it or inject it.
- **Async**: await everything; a floating promise resolves after the test ends and either hides a failure or corrupts the next test.

## 7. Honest assertions

- Assert on **specific outcomes**: the value, the state, the emitted record — precise enough to catch a wrong answer, not so brittle they break on irrelevant formatting. Asserting `error.message` equals an exact sentence breaks on every reword; asserting the error's type/code catches the actual contract.
- **Snapshots** are for output that is genuinely stable and reviewable (a rendered document, a serialized config). A 300-line snapshot nobody reads is an auto-approve rubber stamp, not a test. Prefer small inline snapshots or explicit field assertions.
- **Never weaken an assertion to make a test green.** If the test fails after your change, either the code is wrong (fix it) or the expected behavior legitimately changed (change the test *and say so*). Softening `toEqual` to `toBeTruthy` to pass CI is deleting the test while keeping its cost.

## 8. Coverage is a map, not a target

Use coverage to find untested decision logic — then test the *behaviors* there. Chasing a percentage produces the worst tests in any codebase: assertion-free executions that inflate the number and catch nothing. An honest 70% covering every branch that matters beats a gamed 95%.

## Language & framework specifics

| Working in… | Read |
|---|---|
| TypeScript — Vitest/Jest, React Testing Library, Node services | [references/typescript.md](references/typescript.md) |
