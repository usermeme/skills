# Slot-Based UI Composition

Architectural pattern for composing UIs from a **layout component** (owns placement/CSS only) and **independent widgets** (own their logic) injected into named slots.

## Core Principle

**"If a component can be independent, it should be independent."**

The layout controls *where* things render and knows nothing about *what* they do. Business logic never enters structural components — so the grid is reusable across features, widgets are testable in isolation, and no props are drilled through layers that don't use them.

## When to Use

- Reusable dashboards, grids, or page layouts.
- Any time business-logic props would otherwise be drilled through purely structural components.
- When the same CSS/grid structure should host different content in different features.

## React Implementation

The layout takes `ReactNode` props — those are its slots:

```tsx
// WidgetGrid/WidgetGrid.tsx
import { FC, ReactNode } from 'react';
import styles from './WidgetGrid.module.css';

interface WidgetGridProps {
  title: ReactNode;
  content: ReactNode;
  footer?: ReactNode;
}

export const WidgetGrid: FC<WidgetGridProps> = ({ title, content, footer }) => (
  <div className={styles.grid}>
    <div className={styles.titleArea}>{title}</div>
    <div className={styles.contentArea}>{content}</div>
    {footer && <div className={styles.footerArea}>{footer}</div>}
  </div>
);
```

Composition — each widget is self-contained and fetches/computes its own data:

```tsx
// DashboardWidget/DashboardWidget.tsx
export const DashboardWidget = () => (
  <WidgetGrid title={<WidgetTitle />} content={<WidgetContent />} />
);
```

## Vue / Nuxt Implementation

Named `<slot>` tags play the same role:

```vue
<!-- WidgetGrid.vue -->
<template>
  <div class="widget-grid">
    <div class="title-area">
      <slot name="title" />
    </div>
    <div class="content-area">
      <slot name="content" />
    </div>
    <div v-if="$slots.footer" class="footer-area">
      <slot name="footer" />
    </div>
  </div>
</template>
```

```vue
<!-- DashboardWidget.vue -->
<template>
  <WidgetGrid>
    <template #title>
      <WidgetTitle />
    </template>
    <template #content>
      <WidgetContent />
    </template>
  </WidgetGrid>
</template>
```

## Smell Test

You've broken the pattern if the layout component:
- imports a store, API client, or translation hook,
- receives business data (IDs, entities) instead of `ReactNode`s/slots,
- contains conditionals based on business state rather than slot presence.
