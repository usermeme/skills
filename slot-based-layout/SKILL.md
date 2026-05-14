---
name: slot-based-layout
description: Architectural pattern for frontend UI composition using Layout components and Slots. Decouples UI placement from business logic in React and Vue.
---

# Slot-Based UI Composition

## Conflict Resolution

- If this skill's instructions conflict with project-specific instructions or existing project patterns, the **Project-Specific standards always take priority**.

## Core Principle: Component Independence
**"If a component can be independent, it should be independent."**
Do not couple business logic with layout structures. Split complex UIs into independent widgets. The layout should only control placement and have no knowledge of the logic inside the slots.

## When to Use
- When building reusable dashboards, grids, or page layouts.
- When you want to avoid "Prop Drilling" business logic through structural components.
- To maintain extreme reusability of your CSS/Grid structures.

---

## React Implementation

### 1. The Layout Component (`WidgetGrid`)
Controls only position and placement. It takes `ReactNode`s as props.

```tsx
// WidgetGrid.tsx
import { FC, ReactNode } from 'react';
import styles from './WidgetGrid.module.css';

interface WidgetGridProps {
  title: ReactNode;
  content: ReactNode;
  footer?: ReactNode;
}

export const WidgetGrid: FC<WidgetGridProps> = ({ title, content, footer }) => {
  return (
    <div className={styles.grid}>
      <div className={styles.titleArea}>{title}</div>
      <div className={styles.contentArea}>{content}</div>
      {footer && <div className={styles.footerArea}>{footer}</div>}
    </div>
  );
};
```

### 2. The Composition
Compose independent logic components into the grid.

```tsx
// DashboardWidget.tsx
export const DashboardWidget = () => (
  <WidgetGrid 
    title={<WidgetTitle />} 
    content={<WidgetContent />} 
  />
);
```

---

## Vue / Nuxt Implementation

### 1. The Layout Component (`WidgetGrid.vue`)
Uses named `<slot>` tags for placement.

```vue
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

<style scoped>
/* Grid styles here */
</style>
```

### 2. The Composition
Inject content components into the named slots.

```vue
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
