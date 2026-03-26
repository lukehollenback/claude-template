---
inject:
  - event: PreToolUse
    matcher: "Edit|Write|NotebookEdit"
---

# Design Standards

Glassmorphism design system. Translucent surfaces, layered blur, soft shadows, luminous focus
states. All visual values must trace back to a token → never hardcode colors, sizes, or shadows.

---

## 1. Tokens

### 1.1 Colors

**Semantic:**

| Token | Light | Purpose |
|---|---|---|
| `--color-primary` | `#0F172A` | Primary actions, headings |
| `--color-primary-ring` | `rgba(15, 23, 42, 0.08)` | Focus ring |
| `--color-surface` | `rgba(255, 255, 255, 0.72)` | Glass surface fill |
| `--color-surface-solid` | `#FFFFFF` | Opaque surface fallback |
| `--color-background` | `#F1F3F5` | Page background |
| `--color-text` | `#1E293B` | Body text |
| `--color-text-secondary` | `#64748B` | Supporting text |
| `--color-text-muted` | `#94A3B8` | Labels, placeholders |
| `--color-text-faint` | `#CBD5E1` | Disabled, decorative |
| `--color-border` | `rgba(226, 232, 240, 0.8)` | Borders |
| `--color-divider` | `rgba(226, 232, 240, 0.6)` | Divider lines |

**Status:** `--color-success` (`#10B981`), `--color-warning` (`#D97706`),
`--color-error` (`#DC2626`). Each has `-bg` and `-border` companions.

**AI accent:** `--color-ai` (`#7C3AED`) with `-bg`, `-border`, `-ring`, `-glow` variants.

**Mesh gradients:** `--bg-mesh-1` and `--bg-mesh-2` → subtle background blobs (3–8% opacity)
that give `backdrop-filter` something to blur through. Without them, glass is invisible.

### 1.2 Typography

| Token | Fonts | Usage |
|---|---|---|
| `--font-sans` | DM Sans, system sans | Body text |
| `--font-display` | Playfair Display, Georgia | Display headings |
| `--font-mono` | JetBrains Mono, Fira Code | Code |

**Sizes:** `--text-xs` (0.6875rem), `--text-sm` (0.8125rem), `--text-base` (0.875rem),
`--text-lg` (1rem), `--text-xl` (1.25rem), `--text-2xl` (1.375rem).

**Weights:** 400 (body), 500 (labels, active nav), 600 (badges, buttons), 700 (headings).

**Line height:** body 1.5, headings 1.2–1.3, single-line elements 1.

### 1.3 Spacing

4px baseline grid. Never use arbitrary pixel values.

| Token | Value | Usage |
|---|---|---|
| `--space-1` | 4px | Tight gaps, icon padding |
| `--space-2` | 8px | Inline gaps, small padding |
| `--space-3` | 12px | Standard gaps, nav padding |
| `--space-4` | 16px | Card padding, section gaps |
| `--space-5` | 20px | Generous padding |
| `--space-6` | 24px | Section spacing |
| `--space-8` | 32px | Large spacing, page padding |

### 1.4 Border Radius

| Token | Value | Usage |
|---|---|---|
| `--radius-sm` | 6px | Small elements |
| `--radius-md` | 10px | Inputs, buttons, dropdowns |
| `--radius-lg` | 16px | Cards, panels |
| `--radius-xl` | 20px | Modals, floating nav |
| `--radius-full` | 9999px | Badges, pills, toggles |

Floating/elevated surfaces → `--radius-xl`. Inline controls → `--radius-md`.

### 1.5 Shadows

Two-layer shadows (soft atmosphere + defined structure). No harsh single-layer drops.

| Token | Usage |
|---|---|
| `--shadow-sm` | Subtle lift (cards) |
| `--shadow-md` | Dropdowns, popovers |
| `--shadow-lg` | Modals, overlays |
| `--shadow-hover` | Hover lift effect |

### 1.6 Glass System

Four tokens, always used together. Partial application breaks consistency.

| Token | Default (Frosted) | Purpose |
|---|---|---|
| `--glass-blur` | 20px | Backdrop blur radius |
| `--glass-bg` | `rgba(255, 255, 255, 0.65)` | Surface background |
| `--glass-border` | `rgba(255, 255, 255, 0.35)` | Border |
| `--glass-shadow` | `0 8px 32px rgba(0,0,0,0.06)` | Shadow |

Use the `.glass-surface` CSS class to apply all four.

### 1.7 Transitions

| Token | Value | Usage |
|---|---|---|
| `--transition-fast` | 0.15s ease | Hover, focus feedback |
| `--transition-normal` | 0.2s ease | Standard transitions |

All interactive state changes must be animated. No instant visual jumps.

---

## 2. Theming

### Light (default)

All token values above are light theme. Cool gray background, white surfaces, slate text.

### Dark (`data-theme="dark"`)

Warm neutral grays (no blue tint). Key overrides:

| Token | Dark Value |
|---|---|
| `--color-primary` | `#FCFCFA` |
| `--color-surface` | `rgba(45, 42, 46, 0.72)` |
| `--color-surface-solid` | `#2D2A2E` |
| `--color-background` | `#191919` |
| `--color-text` | `#FCFCFA` |
| `--color-text-secondary` | `#939293` |
| `--color-text-muted` | `#727072` |
| `--color-border` | `rgba(255, 255, 255, 0.10)` |

Shadows deepen (higher opacity). Mesh gradients intensify slightly. Borders shift to
white-alpha.

### System Preference

Three modes → `light`, `dark`, `system`. Persist to localStorage. Prevent flash with a
blocking inline script that sets `data-theme` before hydration.

### Glass Intensity (`data-glass`)

| Level | `--glass-bg` alpha | `--glass-blur` | Character |
|---|---|---|---|
| `solid` | 0.88 | 28px | Opaque, readable |
| `frosted` | 0.65 | 20px | Balanced (default) |
| `glass` | 0.35 | 10px | Maximum transparency |

Each level has dark-mode overrides. Set via `data-glass` attribute on root.

---

## 3. Surfaces & Layers

**Background layer** → `--color-background` + fixed radial-gradient mesh blobs. Essential
infrastructure for `backdrop-filter` to produce visible effects.

**Glass surfaces** → any elevated container. Apply `.glass-surface` class (bg + blur +
border + shadow). Fallback for no `backdrop-filter` support: near-opaque bg, no mesh.

**Elevation model:**

| Layer | z-index | Shadow | Examples |
|---|---|---|---|
| Base | 0 | none | Background |
| Surface | 1 | `--shadow-sm` | Cards |
| Elevated | 10 | `--shadow-md` | Dropdowns |
| Floating | 50 | `--glass-shadow` | Nav bars |
| Overlay | 100 | `--shadow-lg` | Modals |
| Toast | 200 | `--glass-shadow` | Notifications |

Never assign arbitrary z-index values.

---

## 4. Components

### Buttons

| Variant | Background | Text |
|---|---|---|
| `primary` | `--color-primary` | white |
| `secondary` | glass surface | `--color-text` |
| `ghost` | transparent | `--color-text` |
| `danger` | `--color-error` | white |

Sizes: `sm` (`--space-1 --space-3`, `--text-sm`), `md` (`--space-2 --space-4`, `--text-base`).
Radius → `--radius-md`. Weight → 600. Disabled → 50% opacity, `not-allowed`.
Hover → `translateY(-1px)` + `--shadow-hover`. Active → `translateY(0)` + `scale(0.98)`.

### Inputs

Background → `--glass-bg` + blur. Border → `1px solid --color-border`. Radius → `--radius-md`.
Padding → `--space-2 --space-3`. Font → `--font-sans` at `--text-base`.
Focus → `border-color: --color-primary`, `box-shadow: 0 0 0 3px --color-primary-ring`,
`background: --color-surface`. Placeholder color → `--color-text-muted`.

### Cards

Glass surface. Radius → `--radius-lg`. Padding → `--space-4`. Hover → `--shadow-hover`.
Interactive cards → `cursor: pointer` + hover lift.

### Modals

Overlay → `rgba(0, 0, 0, 0.4)` + `blur(4px)`. Surface → glass + `--radius-xl` + `--shadow-lg`.
Animation → slide up + fade in (200ms). Mobile → full-screen, no radius.
Close on overlay click, Escape key. Focus trap. `role="dialog"`, `aria-modal="true"`.

### Toasts

Glass surface, fixed bottom-center. Radius → `--radius-xl`. Slide up + fade in. Auto-dismiss
(default 4s). Status variants via border-left accent or icon color.

### Badges

`inline-flex`, `2px --space-2` padding, `--text-xs`, weight 600, `--radius-full`.

### Navigation

Nav items → `--text-sm`, weight 500. Default → `--color-text-secondary`.
Active → `--color-accent` on icon and text only (no background highlight). This keeps
the active state clean in both expanded and collapsed layouts, and avoids inner-button
sizing issues when pills resize.

When nav items live inside glass pills, they should have no background, no border-radius,
and minimal padding (vertical only → `var(--space-2) 0`). The pill provides the visual
boundary. This prevents double-padding problems and ensures icons stay in the same position
regardless of the pill's expanded/collapsed state.

### Glass Pills

Independent glass controls. Each pill is its own `.glass-surface` element with
`--radius-xl`. Used for nav bars, sidebars, toolbars → the pattern replaces monolithic
headers/panels with discrete floating controls that can be rearranged or hidden
independently.

**Standard dimensions:**
- Interactive pill height → 44px (meets 44x44 touch target minimum).
- Collapsed/icon-only pill → 44x44 square with `--radius-xl` (produces a squircle).
- Content within a pill provides its own padding → the pill supplies only the glass
  boundary.

**Expanded pills** → `border-radius: var(--radius-xl)`, `padding: var(--space-2)`.

**Collapse animation** → when a pill container transitions between expanded and collapsed
states (e.g., a sidebar narrowing), the key constraint is **zero layout shift on icons**.
Rules:

1. **Same padding in both states.** Any padding change causes icons to jump during the
   width transition. Use a single padding value (e.g., `var(--space-1) var(--space-3)`)
   that centers icons when collapsed and provides reasonable inset when expanded.
2. **Fade text, don't swap DOM.** Conditional rendering (`{collapsed ? A : B}`) causes
   instant layout jumps. Instead, always render the same elements and fade text with
   `opacity` transitions. Use `overflow: hidden` on the pill to clip faded content.
3. **Never change `justifyContent` between states.** It doesn't transition in CSS and
   causes visible snapping. Keep icons left-aligned in both states — in a narrow collapsed
   pill with proper horizontal padding, left-aligned icons appear nearly centered.
4. **Content-only pills** (e.g., recent items, calendars) that have no meaningful collapsed
   representation should simply hide when collapsed rather than swapping to an icon button.

**Grouped pills** → When pills are stacked in a column or row, set `box-shadow: none`
on each pill to avoid shadow stacking artifacts. The glass border provides sufficient
visual separation. This also prevents hard-line rendering issues with `backdrop-filter`
on some platforms (notably macOS browsers).

**Pill spacing rhythm** → Use the same token for the gap between pills as the viewport
edge inset (typically `--space-3`). This produces a consistent visual grid where
dropdown menus that use the same gap perfectly align with adjacent pills.

### Dropdowns & Popovers

Glass-surface menus anchored to a trigger pill or button.

**Container:**
- `.glass-surface` class (gets backdrop blur + translucent background).
- `border-radius: var(--radius-lg)`.
- `border: 1px solid var(--glass-border)`.
- `box-shadow: var(--shadow-lg)`.
- `padding: var(--space-1)` (inner gutter around options).
- `z-index` per the elevation model (Elevated or Overlay tier).

**Options:**
- `padding: var(--space-2) var(--space-3)`.
- `border-radius: var(--radius-md)` (rounded hover targets inside the container).
- `border: none`, `background: transparent`.
- Active option → `--color-accent-light` background + `--color-accent` text.
- `transition: background var(--transition-fast), color var(--transition-fast)`.

**Gap** → match the pill spacing rhythm (typically `--space-3`) between the trigger and
the dropdown. This aligns dropdown edges with adjacent layout elements.

**Positioning:**
- Prefer `position: absolute` anchored to a `position: relative` wrapper.
- When the trigger lives inside an `overflow: hidden` container (e.g., scrollable
  sidebar), render the dropdown via a **React portal** to `document.body` with
  `position: fixed`. Measure the trigger's bounding rect on open.
- Close on outside click (`mousedown` listener) and Escape key.

---

## 5. Interaction

**Focus** → glowing ring via `box-shadow: 0 0 0 3px var(--color-primary-ring)` +
`border-color: var(--color-primary)`. Never `outline: none` without a ring replacement.

**Hover** → buttons lift (`translateY(-1px)`), cards get `--shadow-hover`, links shift to
`--color-primary`, nav items get background tint. All use `--transition-fast`.

**Active** → cancel hover lift, `scale(0.98)`, reduce shadow.

**AI loading** → pulsing glow ring (3px → 5px → 3px, 2s infinite). Remove immediately on
completion.

**General loading** → skeleton placeholders with shimmer. No spinners for content areas.

---

## 6. Layout

### 6.1 Floating Navigation

`position: sticky` with `--space-2` to `--space-3` edge margins, `--radius-xl`. Mobile top
bar → flush (`margin: 0`, `radius: 0`). Mobile tab bar → fixed bottom with edge inset
matching the pill spacing rhythm (`--space-3`).

**Concentric radius** → inner interactive elements use a smaller radius than their container.
Container at `--radius-xl` → inner buttons at `--radius-lg`. This produces visually harmonious
nested curves.

### 6.2 Breakpoints

Mobile-first CSS. `< 768px` (single column, bottom tabs), `768–1024px` (flexible columns,
top nav), `> 1024px` (full layout). Grids collapse to single column below 768px.

### 6.3 Content

`max-width: 1200px` standard, `640px` for forms. `margin: 0 auto`. Grid gap → `--space-4`.
Bottom padding must clear any fixed elements.

### 6.4 CSS Grid on Mobile

Use `minmax(0, 1fr)` instead of bare `1fr` for grid columns. `1fr` is shorthand for
`minmax(auto, 1fr)` → columns won't shrink below their content's intrinsic width, causing
horizontal overflow on narrow viewports. `minmax(0, 1fr)` allows columns to shrink to zero.

### 6.5 Mobile Viewport

Disable pinch-to-zoom → `maximumScale: 1`, `userScalable: false` in the viewport config,
plus `viewportFit: "cover"` to activate `env(safe-area-inset-*)`. CSS `touch-action: pan-x
pan-y` on `html` disables zoom on iOS Safari (which ignores `user-scalable=no` since iOS 10).
`html, body { overflow-x: hidden }` prevents horizontal scroll. App shell root needs
`width: 100%; overflow-x: hidden`. Main content needs `max-width: 100%; box-sizing:
border-box; min-width: 0`.

### 6.6 Safe Area Insets

Use `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)` for notched/home-indicator
devices. These require `viewport-fit: cover` to return non-zero values. Use the `env()`
fallback syntax (e.g., `env(safe-area-inset-top, 0px)`) so layouts work in both browser and
PWA standalone modes.

**Top** → offset content and sticky elements below the safe area inset. A glass strip behind
the notch area (see Section 6.8) provides visual continuity.

**Bottom** → offset fixed bottom elements (tab bars) by
`calc(var(--space-3) + env(safe-area-inset-bottom))`. Content area needs bottom padding to
clear fixed bottom elements: `calc(<element-height> + env(safe-area-inset-bottom))`.

### 6.7 Fixed Background on iOS

iOS Safari ignores `background-attachment: fixed`. Workaround → render the mesh gradient via
a `html::before` pseudo-element with `position: fixed; inset: 0; z-index: -1`. This stays
in place during rubber-band over-scroll, preventing harsh edges where content ends. `html`
gets `background-color: var(--color-background)` as a solid base layer underneath.

When `backdrop-filter` is unsupported, hide the pseudo-element (`display: none`) and fall
back to the solid background color with near-opaque glass surfaces.

### 6.8 Status Bar Glass Strip

A fixed glass strip behind the device notch/Dynamic Island on mobile. Content scrolls
underneath with frosted glass blur visible through it.

**Implementation:**
- `.glass-surface` class with no inline overrides of glass properties (inline styles break
  the glass system → use a CSS class for cosmetic overrides instead).
- `position: fixed; top: 0; left: 0; right: 0; z-index: 50`.
- `height: calc(env(safe-area-inset-top, 0px) + var(--space-2))` → always visible (minimum
  `var(--space-2)` in browser mode; ~47px+ in PWA standalone mode on notched devices).
- CSS class removes top/left/right borders, border-radius, and box-shadow while preserving
  the glass background, backdrop-filter, and bottom border.
- Hidden on desktop (`md:hidden`).

**Content offset** → the main content column gets
`padding-top: calc(env(safe-area-inset-top) + var(--space-2))` on mobile so content starts
below the strip. Sticky top bars get the same value for their `top` property so they stick
below the strip rather than behind it.

### 6.9 PWA Configuration

`appleWebApp: { capable: true, statusBarStyle: "black-translucent" }` in metadata. The
`black-translucent` style extends the app behind the status bar and home indicator, activating
the safe area inset environment variables. Without this, `env(safe-area-inset-*)` returns 0
even on notched devices.

### 6.10 Mobile Tab Bar

Fixed bottom navigation pill for mobile (< 768px).

**Layout:**
- `position: fixed` with bottom offset including safe area inset (Section 6.6).
- Left/right inset → pill spacing rhythm token (typically `--space-3`).
- `.glass-surface` with `border-radius: var(--radius-xl)`.
- Uniform inner padding → `var(--space-1)`.
- Equal-width tabs → `flex: 1` on each tab.

**Active state** → accent color on icon and text only (no background highlight, no shadow).
This matches the sidebar nav pattern and keeps the tab bar visually clean against the
glass surface.

---

## 7. Accessibility

- Focus always visible (glow ring with sufficient contrast).
- Text contrast → WCAG AA: 4.5:1 normal, 3:1 large (≥18px or ≥14px bold).
- Respect `prefers-reduced-motion` → disable animations.
- Touch targets → minimum 44×44px on mobile.
- ARIA → modals (`role="dialog"`, `aria-modal`), toasts (`role="status"`).
- Keyboard → Tab reaches all interactive elements. Escape closes overlays. Focus trap in
  modals.

---

## 8. Icons

Lucide React. Default `size={16}`, `strokeWidth={1.5}`, `currentColor`. Stroke-based only
(no fills unless indicating selected state). Consistent stroke width across the app.

---

## 9. Anti-Patterns

Avoid: hardcoded colors/sizes, `outline: none` without replacement, harsh single-layer
shadows, instant state changes, gradient borders, heavy blur (>28px), neon/saturated glow
(keep <20% opacity), corners > `--radius-xl`, fixed pixel font sizes, arbitrary z-index,
decorative-only animation, edge margins > `--space-3` on floating elements, glass without
mesh background, `!important` in component styles.
