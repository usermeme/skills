---
name: code-standards
description: Foundational coding standards (SOLID, clean code, naming, modularity, error handling) plus TypeScript, React, and layout references. Use whenever writing or modifying code in any language — features, fixes, refactors, scripts, or tests.
---

# Code Standards

Foundational coding standards for a workspace maintained by a senior full-stack engineer specializing in TypeScript. They apply to every line of code you write or change, in any language — not only new modules; TypeScript and React specifics live in the references. The goal behind every rule here is the same: code that another senior engineer can read once and immediately understand.

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

## Comments — Hard Rule

**Never write inline or block comments.** Code is the single source of truth for intent; a comment is a second source that drifts out of sync and starts lying. This rule overrides "match the surrounding comment density" — existing comments are no license to add more.

- **Allowed**: JSDoc/TSDoc on exported declarations (functions, types, components, modules) — or the language's native doc-comment equivalent on declarations (Python docstrings, Go doc comments, Rust `///`) — and Markdown documents (`README.md`, `AGENTS.md`, ADRs, module docs).
- **Allowed only as tooling directives**: `eslint-disable-next-line <rule> -- <reason>`, `@ts-expect-error <reason>`, and similar — the justification goes inside the directive, never on a separate comment line.
- **Forbidden**: comments that narrate what the code does, `TODO`/`FIXME` notes (open an issue instead), section dividers, commented-out code, and change notes addressed to a reviewer.
- **When you feel the urge to comment**, fix the code instead: rename the variable, extract a well-named function or constant, introduce a type, or add a test that pins the behavior. A non-obvious constraint (library quirk, ordering requirement) goes in the JSDoc of the declaration it constrains or in the module's Markdown doc.

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

## Self-Audit Before Finishing

1. Do any new functions violate SRP (e.g., calculate **and** store)? Split them.
2. Does the diff contain any comment other than JSDoc or a tooling directive? Delete it and make the code say it.
3. Would another senior engineer understand the intent on first read?
