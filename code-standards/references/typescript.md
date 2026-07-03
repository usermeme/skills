# TypeScript Standards

TypeScript-specific rules. Naming, exports, and organization rules from the main SKILL.md apply on top of these.

## Interfaces vs Types

- **`interface`**: shapes of objects and classes.
- **`type`**: everything else — unions, intersections, aliases, mapped/conditional types.
- No `I`/`T` prefixes anywhere, including generics. Generic parameters get descriptive `PascalCase` names: `Entity`, `Response`, `Item` — not `T`, `K`, `TResponse`.

## Arrays

- `number[]` syntax, not `Array<number>`.
- No inline object arrays (`{ id: number }[]`). Name the element shape first:

```ts
interface User {
  id: number;
}

const users: User[] = [];
```

A named element type documents intent and gets reused the moment a second consumer appears.

## Type Safety & Strictness

- **`any` is forbidden.** It silently disables checking for everything it touches. Use `unknown` for truly dynamic data — it forces narrowing before use.
- **Avoid `as` assertions.** A cast is a promise the compiler can't verify. Instead:
  - **Type guards**: `const isUser = (value: unknown): value is User => …`
  - **Validation libraries** (e.g., Zod) at trust boundaries — API responses, storage, user input.
  - If a third-party library's types force a cast, isolate it in one place with an `eslint-disable` comment and a one-line technical justification.
- **Inference first**: Let TypeScript infer local types. Write explicit return types for public APIs and for functions complex enough that the inferred type wouldn't be obvious to a reader.

## Modeling State & Failures

Discriminated unions are the default for states and expected failures (see Error Handling in SKILL.md):

```ts
type FetchState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: User[] }
  | { status: 'error'; error: Error };
```

The compiler then enforces that every branch is handled — impossible states become unrepresentable.

## Immutability

- Use `readonly` properties and `ReadonlyArray` for constants and stable data structures that must not be mutated. Not required on every property — apply it where mutation would be a bug.
- Prefer `as const` for literal constant objects/tuples.
