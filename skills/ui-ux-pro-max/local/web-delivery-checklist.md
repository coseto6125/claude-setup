# Pre-Delivery Checklist

Run this before handing over UI code. Each line is one check; the Do/Don't columns are the pass condition, not extra reading.

## Icons & visual elements

| Check | Do | Instead of |
|-------|----|-----------|
| Icon source | SVG from one set (Heroicons, Lucide, Simple Icons) | Emoji as icons (🎨 🚀 ⚙️) |
| Icon sizing | Fixed 24×24 viewBox rendered at `w-6 h-6` | Mixed sizes across the page |
| Brand logos | Official path copied from Simple Icons | A guessed or approximated path |
| Hover geometry | Color/opacity/shadow transitions | Scale transforms that shift surrounding layout |
| Theme colors | `bg-primary` directly | `bg-[var(--primary)]` wrappers |

## Interaction

| Check | Do | Instead of |
|-------|----|-----------|
| Cursor | `cursor-pointer` on every clickable element, cards included | The default arrow on interactive surfaces |
| Hover feedback | A visible change — color, shadow, or border | No signal that the element is interactive |
| Transition timing | `transition-colors duration-200` (150–300ms) | Instant changes, or anything over 500ms |
| Focus | A visible focus ring reachable by Tab | Focus styles removed for looks |

## Light/dark contrast

| Check | Do | Instead of |
|-------|----|-----------|
| Glass surfaces in light mode | `bg-white/80` or denser | `bg-white/10` — invisible on light backgrounds |
| Body text, light mode | `#0F172A` (slate-900) | `#94A3B8` (slate-400) |
| Muted text, light mode | `#475569` (slate-600) as the floor | gray-400 or lighter |
| Borders | `border-gray-200` in light mode | `border-white/10` — invisible in light mode |
| Verification | Both modes opened and looked at | Shipping one mode and assuming the other |

## Layout

| Check | Do | Instead of |
|-------|----|-----------|
| Floating navbar | `top-4 left-4 right-4` | `top-0 left-0 right-0` |
| Fixed-element clearance | Content padded past the navbar height | Content sliding under fixed elements |
| Container width | One `max-w-6xl` (or `max-w-7xl`) throughout | A different width per section |
| Responsive | Verified at 375 / 768 / 1024 / 1440px, no horizontal scroll at any of them | Desktop-only verification |

## Accessibility

| Check | Do | Instead of |
|-------|----|-----------|
| Images | Descriptive `alt` on every meaningful image | Missing or decorative-only alt text |
| Form fields | A `<label for=>` per input | Placeholder text carrying the label |
| Contrast | 4.5:1 minimum for body text in both modes | Anything that only passes in dark mode |
| Status encoding | Color plus an icon or text label | Color as the sole carrier of meaning |
| Motion | `prefers-reduced-motion` honored | Animation that plays regardless |
