---
name: react-code-standards
description: Enforces high-quality React patterns. Use when writing or refactoring React components and hooks to ensure predictable state management and component lifecycle.
---

# React Code Standards

This skill defines the standards for React development in this workspace, focusing on component architecture, hook management, and predictable state.

## 1. Hook Ordering

ALWAYS follow this order when declaring hooks inside a component or another hook:

1.  **Higher-order hooks**: `useTranslation`, `useRouter`, `useNavigation`, `useDispatch`, `useSelector`.
2.  **State hooks**: `useState`, `useReducer`.
3.  **Ref hooks**: `useRef`.
4.  **Memo hooks**: `useMemo`.
5.  **Callback hooks**: `useCallback`, `useLatestCallback`.
6.  **Effect hooks**: `useEffect`, `useLayoutEffect`, `useEachDayEffect`.

## 2. Predictable Hooks

- Hooks should have clear inputs (params) and outputs (return values).
- Avoid "magic" side effects that aren't obvious from the hook's name.
- Keep `useCallback` and `useLatestCallback` focused on a single logical transaction (Pure Callbacks).

## 3. Side-Effect Free Getters

- Functions that retrieve data (e.g., `get...`, `use...Value`) MUST NOT mutate state or trigger side effects.
- Separate data retrieval from state updates.

## 4. Composition over Inheritance

- Use the "Provider Stack" and high-level compositions instead of deep inheritance.
- Leverage slots and layout components for UI flexibility.

## 5. Strict Typing

- **No `any`**: Use strict typing.
- If a third-party library has poor types, use a safe cast with an `eslint-disable` comment and a technical justification.

## 6. Implementation Guidelines

- **Arrow Functions**: Prefer `const MyComponent = () => {}` over `function MyComponent() {}`.
- **Named Exports**: Always use named exports for components and hooks.
