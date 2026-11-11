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
| Custom control (slider, drag surface, scrollable strip) | Tapped, then dragged to completion with the target input. A swipe along the page's scroll axis across it scrolls the page | Mouse-only handlers, no `touch-action` on a pointer-event drag surface |
| Interrupted gesture | A second pointer, `pointercancel`, `lostpointercapture`, release outside, and window `blur` each clear the drag state and release capture. The next drag works without a reload | Drag state that nothing clears on cancel |
| Gesture evidence | The report names the engine or device that produced it (Chromium is not Safari) and what stayed untested | A screenshot or a resized viewport offered as proof of a gesture |

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
| Navbar | On the same side margins as the content, at most a tenth of the first screen tall | A floating pill on its own inset, a header on one margin and the page on another |
| Fixed-element clearance | Content padded past the navbar height | Content sliding under fixed elements |
| Container width | One `max-w-6xl` (or `max-w-7xl`) throughout | A different width per section |
| Side margins | Equal left and right margins at every width, never under 16px | A page pushed to one side |
| First screen | One `h1` that says what this is, painted on the first frame, two lines at most | A bare name or slogan, a loader, an empty block over a quarter of the screen |
| Sections | A heading on every section. When text takes one half, the other half holds the picture, a column, a list or a figure | A small caps or mono label standing in for a heading, half the width left as plain ground |
| Responsive | Verified at 375 / 768 / 1024 / 1440px, no horizontal scroll at any of them | Desktop-only verification |
| First viewport, desktop | At every width from 1280 to 1600px, the first-viewport content stays above the fold and no fixed-pixel grid wraps | Checking only the fixed breakpoints |
| Shipped notes | No design notes, prompts or direction text in HTML comments, `data-*` attributes or the bundle | Working notes delivered to the browser |

## Accessibility

| Check | Do | Instead of |
|-------|----|-----------|
| Images | Descriptive `alt` on every meaningful image | Missing or decorative-only alt text |
| Form fields | A `<label for=>` per input | Placeholder text carrying the label |
| Contrast | 4.5:1 minimum for body text in both modes | Anything that only passes in dark mode |
| Status encoding | Color plus an icon or text label | Color as the sole carrier of meaning |
| Motion | `prefers-reduced-motion` honored | Animation that plays regardless |
