---
name: code-standards
description: Enforces high-quality software engineering principles, clean code patterns, and descriptive naming conventions. Use when writing or refactoring code to ensure adherence to SOLID principles and project standards.
---

# Code Standards

## Context: Senior Full-Stack Engineer

You are operating in a workspace maintained by a **Senior Full-Stack Developer** specializing in **TypeScript** development.

This skill defines the foundational coding standards and engineering philosophy expected in this workspace.

## 1. Core Philosophy

- **Conflict Resolution**: If this skill's instructions conflict with project-specific instructions or existing project patterns, the **Project-Specific standards always take priority**.
- **SOLID Principles**: Mandatory application of SOLID principles across all modules.
- **Architectural Patterns**: Apply architectural patterns (e.g., Factory, Adapter, Singleton, Composite, Closure-Based Dependency Injection, etc.) to maintain structural integrity and scalability.
- **Independence**: If a module or component *can* be independent, it *should* be independent.

## 2. SOLID Principles

- **Single Responsibility (SRP)**: A function or component should do ONE thing.
  - _Bad_: A getter that also updates state/history (`getNextNotificationText`).
  - _Good_: A getter that returns text, and a separate effect/callback that updates history.
- **Open/Closed**: Software entities should be open for extension but closed for modification.
- **Liskov Substitution**: Objects of a superclass should be replaceable with objects of its subclasses without breaking the application.
- **Interface Segregation**: Prefer many client-specific interfaces over one general-purpose interface.
- **Dependency Inversion**: Depend on abstractions, not concretions.

## 3. Clean Code Patterns

- **DRY (Don't Repeat Yourself)**: Abstract common logic into shared hooks or utils.
- **Explicit over Implicit**: Prefer explicit types and clear naming over "clever" or hidden logic.
- **Descriptive Naming**: NEVER use short, cryptic variable names (e.g., `e`, `t`, `i`, `val`, `data`). Use descriptive names that convey the variable's purpose (e.g., `event`, `translation`, `index`, `exerciseValue`, `completedExercises`).
- **Guard Clauses**: Always use early returns to avoid nesting.

## 4. Naming Conventions

- **Variables & Functions:** Always use `camelCase`.
- **Classes, Interfaces, & Types:** Always use `PascalCase`.
- **Booleans:** Adjectives describing the state (Best: `opened`, `completed`; Good: `isVisible`).
- **No Prefixes:** No `I` or `T` prefixes for types/interfaces.

## 5. Organization & Modularity

- **Alphabetical Sorting**: Mandatory for imports, exports, and destructuring.
- **Module Decomposition**: Modules should be as small as possible.
- **Soft Limit**: Keep files under 200 lines. Evaluate for decomposition if exceeded.
- **File Structure**: Folder-per-module structure (e.g., `Component/Component.tsx`, `Component/utils/util.ts`).
- **Exports**: Always use **Named Exports**.

## 6. Implementation Guidelines

- **Arrow Functions**: Prefer `const myFunction = () => {}` over `function`.
- **Async/Await**: Always use `async/await` instead of `.then()`.
- **Parallelism**: Use `Promise.all` for independent async tasks.

## 7. Testing & Quality

- **TDD**: Follow Test-Driven Development.
- **Commits**: Use **Conventional Commits** (e.g., `feat:`, `fix:`).
- **PRs**: Small, frequent Pull Requests.

## Workflow

1. **Self-Audit**: Before concluding a task, review your new functions. Do they violate SRP?
2. **Refactor**: If a function handles both "calculation" and "storage", split them immediately.
3. **Verify**: Ensure that the code remains readable and that another "senior engineer" would immediately understand the intent.
