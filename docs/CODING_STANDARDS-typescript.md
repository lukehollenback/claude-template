---
inject:
  - event: PreToolUse
    matcher: "Edit|Write|NotebookEdit"
---

# TypeScript Coding Standards

These conventions apply to all TypeScript and TSX files in the Grove project.
For general (language-agnostic) standards, see
[`CODING_STANDARDS.md`](./CODING_STANDARDS.md).

## Formatting

Prettier handles formatting via the ESLint integration that ships with
`create-next-app`. Do not add a standalone Prettier config unless the
ESLint-integrated one proves insufficient.

## Naming

| Construct               | Convention            | Example                   |
| ----------------------- | --------------------- | ------------------------- |
| Components              | PascalCase            | `QuickEntry`              |
| Types and interfaces    | PascalCase            | `Notebook`, `EntryKind`   |
| Functions and variables | camelCase             | `createEntry`, `isDirty`  |
| Constants               | SCREAMING_SNAKE_CASE  | `MAX_TITLE_LENGTH`        |

## File Naming

Use **kebab-case** for all files.

- Components → `quick-entry.tsx`
- Hooks → `use-notebooks.ts`
- Utilities → `date-helpers.ts`
- Types → `notebook-types.ts`

## Imports

Group imports in the following order, separated by blank lines:

1. React / Next.js (`react`, `next/*`)
2. External libraries (`lucide-react`, etc.)
3. Internal modules (`@/components/*`, `@/lib/*`, etc.)

```tsx
import { useState } from "react";
import Link from "next/link";

import { Plus } from "lucide-react";

import { QuickEntry } from "@/components/quick-entry";
```

## Types

- Prefer `interface` for object shapes.
- Use `type` for unions, intersections, and mapped types.
- Export types from the module that owns them. Import them where
  needed rather than re-declaring.

```tsx
// Owned by the notebook module.
export interface Notebook {
  id: string;
  title: string;
  color: string;
}

// Union type.
export type EntryKind = "note" | "journal" | "reminder";
```

## Components

- **One component per file.** The file name matches the component name
  in kebab-case (e.g., `QuickEntry` lives in `quick-entry.tsx`).
- Use **named exports** for all components.
- Exception → Next.js `page.tsx` and `layout.tsx` files require
  **default exports**.

```tsx
// src/components/quick-entry.tsx
export function QuickEntry() {
  /* ... */
}
```

## Async

- Use `async`/`await` exclusively.
- Never use raw `.then()` chains.

```tsx
// Good.
const data = await fetchNotebooks();

// Bad.
fetchNotebooks().then((data) => { /* ... */ });
```

## State Management

- **Global state** → React Context (`createContext` / `useContext`).
- **Local state** → `useState` or `useReducer`.
- No external state library during the mockup phase.
