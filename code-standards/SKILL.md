---
name: code-standards
description: Foundational coding standards and engineering philosophy. Includes mandatory SOLID principles, architectural pattern strategy, naming conventions, and modularity rules.
---

# Code Standards

## Context: Senior Full-Stack Engineer
You are operating in a workspace maintained by a **Senior Full-Stack Developer** specializing in **TypeScript** development.

- **Primary Stack:** TypeScript, React/React Native, Next, Vue/Nuxt, NestJS.

This skill defines the foundational coding standards and engineering philosophy expected in this workspace.

## Core Philosophy

- **Conflict Resolution:** If this skill's instructions conflict with project-specific instructions or existing project patterns, the **Project-Specific standards always take priority**.
- **SOLID Principles:** Mandatory application of SOLID principles across all modules.
- **Architectural Patterns:** Apply architectural patterns (e.g., Factory, Adapter, Singleton, Composite, Closure-Based Dependency Injection, etc.) to maintain structural integrity and scalability.
- **Independence:** If a module or component *can* be independent, it *should* be independent.

## Naming Conventions

- **Variables & Functions:** Always use `camelCase`.
- **Classes, Interfaces, & Types:** Always use `PascalCase`.
- **Booleans:** Adjectives describing the state (Best: `opened`, `completed`; Good: `isVisible`).
- **No Prefixes:** No `I` or `T` prefixes for types/interfaces.

## Organization & Modularity

- **Alphabetical Sorting:** Mandatory for imports, exports, and destructuring.
- **Module Decomposition:** Modules should be as small as possible.
- **Soft Limit:** Keep files under 200 lines. Evaluate for decomposition if exceeded.
- **File Structure:** Folder-per-module structure (e.g., `Component/Component.tsx`, `Component/utils/util.ts`).

## Implementation Guidelines

- **Arrow Functions:** Prefer `const myFunction = () => {}` over `function`.
- **Guard Clauses:** Always use early returns to avoid nesting.
- **Async/Await:** Always use `async/await` instead of `.then()`.
- **Parallelism:** Use `Promise.all` for independent async tasks.
- **Exports:** Always use **Named Exports**.

## Testing & Quality

- **TDD:** Follow Test-Driven Development.
- **Commits:** Use **Conventional Commits** (e.g., `feat:`, `fix:`).
- **PRs:** Small, frequent Pull Requests.
- **Formatting:** Single quotes `'`, 80-character maximum line length.
