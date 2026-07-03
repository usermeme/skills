---
name: code-standards
description: Foundational engineering standards for this workspace — SOLID, clean code, naming, module organization, error handling, plus TypeScript, React, and slot-based UI composition guidance. Use whenever writing, reviewing, or refactoring code in any language, even for small edits — it defines the naming, file structure, typing, and component patterns every change must follow. For TypeScript, React, or Vue work, also read the matching file in references/.
---

# Code Standards

Foundational coding standards for a workspace maintained by a senior full-stack engineer specializing in TypeScript. The goal behind every rule here is the same: code that another senior engineer can read once and immediately understand.

**Precedence**: Project-specific instructions and existing project patterns always override this skill. Consistency within a codebase beats consistency with this document.

## Language & Framework References

Read the relevant reference **before** writing code in that domain:

| Working on… | Read |
|---|---|
| TypeScript (any code in `.ts`/`.tsx`) | [references/typescript.md](references/typescript.md) |
| React components or hooks | [references/react.md](references/react.md) |
| Page layouts, dashboards, reusable UI composition (React or Vue) | [references/slot-based-layout.md](references/slot-based-layout.md) |

## Core Philosophy

- **Independence**: If a module or component *can* be independent, it *should* be independent. Independent units are easier to test, reuse, and delete.
- **Explicit over implicit**: Prefer clear naming and visible data flow over "clever" or hidden logic. Cleverness costs every future reader more than it saved the author.
- **Design patterns are tools, not goals**: Apply patterns (Factory, Adapter, Composite, closure-based dependency injection) when they solve a real structural problem. Avoid Singletons except for genuinely global, stateless concerns — shared mutable singletons hide dependencies and break test isolation.

## SOLID Principles

Apply SOLID across all modules:

- **Single Responsibility**: A function or component does ONE thing.
  - _Bad_: a getter that also updates state/history (`getNextNotificationText` that mutates history).
  - _Good_: a getter that returns text, plus a separate effect/callback that updates history.
- **Open/Closed**: Extend behavior through composition and configuration, not by editing stable modules.
- **Liskov Substitution**: A subtype must be usable anywhere its base type is expected without surprises.
- **Interface Segregation**: Prefer several small, client-specific interfaces over one general-purpose one.
- **Dependency Inversion**: Depend on abstractions, not concretions — pass dependencies in rather than importing them deep inside.

## Clean Code

- **DRY**: Extract logic shared by two or more call sites into hooks or utils. Don't abstract prematurely on the first occurrence — wrong abstractions cost more than duplication.
- **Guard clauses**: Use early returns to keep the happy path un-nested.
- **Side-effect-free getters**: Anything named `get…` or returning a value must not mutate state or trigger side effects. Retrieval and mutation are always separate functions.

## Naming

- **Variables & functions**: `camelCase`. **Classes, interfaces, types**: `PascalCase`. No `I`/`T` prefixes.
- **Descriptive names, always**: Never `e`, `t`, `i`, `val`, `data`. Write `event`, `translation`, `index`, `exerciseValue`, `completedExercises`. The name should make a comment unnecessary.
- **Booleans**: Adjectives describing state — best: `opened`, `completed`, `visible`; acceptable: `isVisible`, `hasErrors`.

## Organization & Modularity

- **Named exports only** — they survive renames, enable reliable find-references, and keep imports honest.
- **Alphabetical sorting** for imports, exports, and destructuring — removes merge conflicts and bike-shedding about order.
- **Small modules**: Keep files under ~200 lines (soft limit). When exceeded, evaluate for decomposition rather than mechanically splitting.
- **Folder-per-module**: `Component/Component.tsx`, `Component/utils/formatLabel.ts`.

## Error Handling

- Model **expected failures** as data, not exceptions: return a discriminated union (`{ status: 'success', value } | { status: 'error', error }`) so callers are forced to handle both branches.
- Reserve `throw` for genuinely exceptional, unrecoverable situations (programming errors, broken invariants).
- Never swallow errors silently — handle, propagate, or log with context.

## Implementation Defaults

- **Arrow functions**: `const myFunction = () => {}` over `function` declarations.
- **`async/await`** over `.then()` chains.
- **`Promise.all`** for independent async work — never await sequentially what can run in parallel.

## Testing & Delivery

- **TDD**: Write the failing test first when the behavior is well-defined; at minimum, every bug fix starts with a test that reproduces it.
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `chore:`, ….
- **Small, frequent PRs** — reviewable in one sitting.

## Self-Audit Before Finishing

1. Do any new functions violate SRP (e.g., calculate **and** store)? Split them.
2. Are all names descriptive enough that a comment isn't needed?
3. Would another senior engineer understand the intent on first read?
