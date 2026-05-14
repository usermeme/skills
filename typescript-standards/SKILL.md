---
name: typescript-standards
description: TypeScript-specific best practices, type definitions, and coding patterns. Use this skill to ensure strict type safety, consistent use of interfaces vs types, and clean type inference.
---

# TypeScript Standards

This skill defines the TypeScript-specific standards and patterns for the workspace.

## Conflict Resolution

- If this skill's instructions conflict with project-specific instructions or existing project patterns, the **Project-Specific standards always take priority**.

## Core Definitions

- **Interfaces:** Use for defining the shape of Objects and Classes.
- **Types:** Use for everything else, including Union Types, Intersections, and Aliases.
- **Naming:** Follow the `PascalCase` convention for all types and interfaces. Do not use prefixes like `I` or `T`.
- **Arrays:** 
    - Use the `number[]` syntax instead of `Array<number>`.
    - Avoid inline object arrays (e.g., `{ id: number }[]`). Always define a separate interface for the object first.

## Type Safety & Strictness

- **Any:** Strictly forbidden. Use `unknown` if the type is truly dynamic.
- **Inference:** Prefer TypeScript's type inference whenever possible. 
    - Explicit return types are not required if the inference is clear, but should be used for complex functions or public APIs.
- **Casting:** Avoid `as` type assertions (casting) where possible.
- **Type Guards:** Prefer using Type Guards (`isUser(data)`) or validation libraries (like Zod) to ensure data safety instead of casting.

## Immutability

- **Readonly:** While not strictly required for every property, use `readonly` or `ReadonlyArray` when defining constants or stable data structures that should not be mutated.

## Advanced Patterns

- **Union Types:** This is the preferred way to handle states and expected failures (see `code-standards` error handling).
- **Generics:** Use descriptive `PascalCase` names for generics (e.g., `Entity`, `TResponse`).
