# React Standards

React-specific rules. TypeScript rules from [typescript.md](typescript.md) and the general rules from SKILL.md apply on top of these.

## Components

- **Arrow function components**: `const MyComponent = () => {}`, exported by name.
- **Composition over inheritance**: Build features by composing small components, provider stacks, and layout/slot components — never class hierarchies. For layouts and dashboards, use the slot pattern: [slot-based-layout.md](slot-based-layout.md).
- **Props are the component's public API**: type them explicitly with an `interface`, keep them minimal, and pass `ReactNode` slots instead of drilling business data through structural components.

## Hook Ordering

Declare hooks in this order inside a component or custom hook, so every component reads the same way — context first, then state, then derived values, then effects:

1. **Framework/context hooks**: `useTranslation`, `useRouter`, `useNavigation`, `useDispatch`, `useSelector`
2. **State hooks**: `useState`, `useReducer`
3. **Ref hooks**: `useRef`
4. **Memo hooks**: `useMemo`
5. **Callback hooks**: `useCallback` (and project equivalents like `useLatestCallback`)
6. **Effect hooks**: `useEffect`, `useLayoutEffect` (and project custom effects)

## Predictable Hooks

- A hook's behavior must be fully described by its name, params, and return value — no "magic" side effects a caller can't anticipate.
- Keep each `useCallback` focused on a single logical transaction. A callback that saves *and* navigates *and* tracks analytics is three callbacks composed at the call site.
- **Side-effect-free getters**: `get…`/`use…Value` functions MUST NOT mutate state or trigger side effects. Reading and writing are separate hooks/functions — this is Single Responsibility applied to hooks.

## State

- Derive, don't duplicate: if a value can be computed from existing state/props, compute it (memoize when expensive) instead of storing a copy that can drift.
- Lift state only as high as it needs to be; prefer local state over global stores for locally-owned concerns.

## Typing

- **No `any`** — same rule as everywhere. If a third-party library has broken types, isolate a safe cast with an `eslint-disable` comment and a technical justification, in one place only.
