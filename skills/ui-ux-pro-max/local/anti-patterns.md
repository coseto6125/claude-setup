# Anti-Patterns & Technical Standards

Condensed from Impeccable (pbakaus/impeccable v4.1.2 `reference/craft-floor.md`). Updated 2026-08-28. Use this as a checklist to catch common mistakes after building.

## AI Slop Tells

These patterns signal AI-generated design. Avoid all of them:

A style borrowed to signal a category the page did not earn is wrong. These borrowed styles are the densest tell, so hunt them first.

- **Fonts**: Skip system defaults (Inter, Roboto, Arial, Open Sans, Lato, Montserrat). Skip the second-reflex faces too: Fraunces, Newsreader, Lora, Crimson Pro, Playfair Display, Cormorant, Syne, IBM Plex, Space Mono, Space Grotesk, DM Sans, DM Serif, Outfit, Plus Jakarta Sans, Instrument Sans. These are good faces. They appear so often in generated output that they give a project no voice. Browse Pangram Pangram, Velvetyne, ABC Dinamo, Future Fonts, Klim Type Foundry. Source and self-host the display face. The closest installed font is a failure, not a fallback.
- **Color**: Purple gradients on white, cyan/neon on dark, gradient text on headings and metrics, glowing accents, generic glassmorphism. Pick light or dark from the use scene: who reads this, where, under what ambient light. Picking it from the category is a reflex.
- **Layout**: Three equal feature cards, hero metric template (big number + subtitle + icon), everything centered, cards wrapping everything, cards nested inside cards, rounded rectangles with generic drop shadows. A modal for a task that needs neither interruption nor protected focus. Section numbers (01 / 02 / 03) unless the sequence itself carries information the reader needs.
- **Eyebrow above a heading**: Never. The heading carries its own weight. Delete the label.
- **Motion**: Bounce/elastic easing (tacky since ~2015), overshoot effects. One authored moment beats one identical entrance on every section.
- **Content**: "Elevate your workflow," John Doe, 99.99%, emoji avatars, SVG-egg placeholders, repeating the same information (redundant headers, intros that restate the heading)
- **Decoration**: Large icons with rounded corners above every heading (templated look), a colored `border-left` or `border-right` above 1px on cards, list items, callouts, or alerts, sparklines and progress rings standing in for content. Monospace type is wrong unless the content is code, data, or measurement. A hard offset shadow (`box-shadow: 4px 4px 0`) is wrong unless the world is actually neobrutalist. Unicode glyphs and emoji standing in for an icon system are wrong. Draw icons from one real library at one stroke weight. When the resolved style is hand-drawn, `local/sources.md` names the four sets that fit it and the license each one carries.
- **Cut-outs**: A circle, polygon, or radial-gradient mask approximating a photo subject's edge reads worse than no cut-out at all. Derive an alpha matte from the actual image, or ship a real cut-out asset.
- **Browser surfaces**: The parts you did not draw still carry the design. Theme `::selection`, `caret-color`, custom scrollbars, `text-underline-offset`, and tabular numerals from the palette. This is the cheapest signal that a page was built rather than assembled, and the one models skip most reliably.
- **Hierarchy**: Making every button primary. Use ghost buttons, text links, and secondary styles.
- **Portfolio sites**:
  - Three-column card grid for portfolio items. Use timeline lists or logo grids
  - Gradient CTA buttons on personal sites. Use text-only CTAs
  - Stock hero image behind the name. Let typography be the hero
  - "Skills" section with progress bars
  - Animated statistics counters

## Production Tells

The tells above come from craft review. These came out of running real
LLM-generated landing pages and reading what the model reached for when it tried
to *look* designed. Condensed from Leonxlnx/taste-skill (MIT) §9.F-9.G,
2026-08-24. Treat each as a hard ban unless the brief asks for it by name.

**Hero and top of page**
- Version or status labels as the hero eyebrow: `V0.6`, `BETA`, `ALPHA`, `EARLY ACCESS`, `INVITE-ONLY PREVIEW`. Only when the brief is about launch status.
- A decoration text strip across the hero bottom: `BRAND. MOTION. SPATIAL.`, `TYPE / FORM / MOTION`, `ESTD. 2018 · LISBON`. Agency-portfolio cliché. Allowed only when the strip carries real links or real status.
- Scroll cues of any kind: `Scroll`, `↓ scroll`, `Scroll to explore`, animated mouse-wheel icons. The reader is looking at the hero. They know what scroll is.

**Fake product surfaces**
- A product UI built from styled `<div>`s to simulate a screenshot. This is the single densest tell. Ship a real screenshot, a generated image, a live component, or nothing.
- Fake version footers inside those fakes: `v0.6.2-rc.1`, `last sync 4s ago · main`.
- Version stamps in a marketing footer: `v1.4.2`, `Build 0048`. Those are devtool fixtures, not landing-page content.
- Live-stock counters as decoration: `Reservation 412 of 800`. Only with real data behind them.

**Separators and dots**
- The middle dot `·` as the default separator. Maximum one per metadata line. For a separator family, use line breaks, hairlines, or columns.
- A colored status dot before every nav link, list row, or badge. Allowed only when the dot carries real semantic state, and then once per section.
- Hairline or crosshair grid lines drawn to make a page "feel designed". Use them only when they organize real content.
- `border-t` and `border-b` on every row of a long list or spec table. Pick one, and use it sparsely.

**Typography flourishes**
- The em-dash `—` anywhere the user can see it: headline, eyebrow, pill, body, quote, attribution, caption, button, alt text. Use a period, a comma, a colon, parentheses, or two sentences. The en-dash `–` as a separator goes too; ranges take a hyphen.
- A headline split with `<br>` and half of it italicized, used as a default design move.
- Vertical rotated text. Only when the brief is explicitly experimental and the composition needs it.

**Labels and captions**
- Poetic section labels: `From the field`, `Field notes`, `On our desks`, `Currently on the bench`. Use the plain functional label or none.
- `Quietly trusted by` / `Quietly in use at` as a social-proof header. Say `Trusted by`, or let the logos speak.
- A micro-meta sentence under a section heading explaining the section's own intent. Eyebrow, headline, body is enough.
- Generic step labels: `Stage 1 / 2 / 3`, `Phase 01 / 02 / 03`, `Pass One / Two / Three`. The step content is the label: `Install`, `Configure`, `Ship`.
- Pills and tags overlaid on a photo. Caption below the image, or nothing.
- Fake photo credits: `Frame XII · 35mm`, `Plate 03 · House archive`. Credit a real photographer or write one functional caption.
- Locale, time, or weather strips: `LIS 14:23 · 18°C`, `Lisbon, working with founders`. Allowed for a real venue or a genuinely timezone-distributed team. A contact address in the footer is fine; an atmospheric strip is not.

**Data and comparison visuals**
- Scoring or progress bars with a filled background track on a marketing page. Use a number with a small icon, or a thin inline bar with no track.
- A floating explainer paragraph in the top-right corner of a section header, aligned to nothing. Put it under the headline, or build a real two-column header.

**Assets**
- Hand-rolled SVG icons. Use one real library at one stroke weight: Phosphor, HugeIcons, Radix, Tabler.
- Broken Unsplash URLs. Use `https://picsum.photos/seed/{descriptive-string}/{w}/{h}`, a generated image, or a real asset.
- shadcn/ui in its default state. Retheme radii, colors, shadows and type first; `local/sources.md` covers tweakcn for exactly this.

## Typography

- **Body text viewport edge**: Body text must never run to the absolute viewport edge without padding. At minimum, apply `1rem` inline padding on mobile. Flush text against the viewport edge reads as broken, not intentional.
- **Vertical rhythm**: Line-height is the base unit for ALL vertical spacing. If body is `line-height: 1.5` on 16px (=24px), spacing should be multiples of 24px
- **Modular scale**: Use 5 sizes with clear contrast, not 14/15/16/18 muddy steps. Ratios: 1.25 (major third), 1.333 (perfect fourth), 1.5 (perfect fifth)
- **Measure**: `max-width: 65ch` for body text. Increase line-height (+0.05-0.1) for light-on-dark
- **Font loading**: Use `font-display: swap` + size-adjust fallback metrics to prevent layout shift
- **OpenType**: `tabular-nums` for data tables, `diagonal-fractions` for recipes, `all-small-caps` for abbreviations
- **Accessibility**: Never `user-scalable=no`. Use rem/em not px for body. Minimum 16px body. 44px+ tap targets on text links

## Color & Contrast

- **Use OKLCH, not HSL**. OKLCH is perceptually uniform—equal lightness steps look equal. Reduce chroma as you approach white/black (high chroma at extreme lightness looks garish). Note: when auditing existing codebases, OKLCH values resolved through CSS custom properties or Tailwind theme tokens may appear as raw numbers without the `oklch()` wrapper—verify the full resolution chain before flagging.
- **Tinted neutrals**: Pure gray is dead. Add chroma 0.01 of your brand hue to all neutrals: `oklch(95% 0.01 250)` for cool, `oklch(95% 0.01 60)` for warm
- **Pure black (#000)**: Never for backgrounds or text. Use rich off-blacks with subtle hue tint
- **Gray text on color**: Always fails readability. Use a darker shade of the background color instead
- **60-30-10 rule**: 60% neutral, 30% secondary, 10% accent. Overusing accent kills its power
- **Alpha transparency**: Heavy use = incomplete palette. Define explicit overlay colors instead
- **WCAG**: Body text 4.5:1, large text 3:1, UI components 3:1. Placeholders need 4.5:1 too
- **Dark mode**: Not inverted light mode. Use lighter surfaces for depth (no shadows), desaturate accents, reduce font weight, never pure black backgrounds (use oklch 12-18%)

## Spacing & Layout

- **4pt base, not 8pt**: 8pt is too coarse—you frequently need 12px. Scale: 4, 8, 12, 16, 24, 32, 48, 64, 96px
- **Semantic token names**: `--space-sm` not `--spacing-8`. Use `gap` over margins for sibling spacing
- **Self-adjusting grid**: `repeat(auto-fit, minmax(280px, 1fr))` for responsive grids without breakpoints
- **The squint test**: Blur your eyes—can you identify the #1 element, #2, and clear groupings? If everything looks same-weight, hierarchy problem
- **Cards are not required**: Spacing and alignment create grouping naturally. Use cards only for distinct actionable items or visual comparison grids. Never nest cards
- **Container queries**: Use for components (`container-type: inline-size`), viewport queries for page layout
- **Optical alignment**: Text at `margin-left: 0` looks indented—use `-0.05em` negative margin. Play icons shift right
- **Z-index**: Semantic scale (dropdown < sticky < modal-backdrop < modal < toast < tooltip), not arbitrary numbers

## Motion

- **100/300/500 rule**: 100-150ms for instant feedback (button, toggle). 200-300ms for state changes (menu, tooltip). 300-500ms for layout (accordion, modal). 500-800ms for entrances (page load, hero). Exits = 75% of entrance duration
- **Easing**: Never use `ease` (it's a compromise). Use `ease-out` (entering), `ease-in` (leaving), `ease-in-out` (toggles). Recommended default: `cubic-bezier(0.25, 1, 0.5, 1)` (quart-out)
- **Bounce/elastic**: Avoid. Real objects decelerate smoothly. Overshoot draws attention to animation, not content
- **Only animate `transform` and `opacity`**—everything else causes layout recalculation. For height: `grid-template-rows: 0fr` to `1fr`
- **Stagger cap**: `animation-delay: calc(var(--i) * 50ms)`. Cap total stagger at ~500ms
- **Reduced motion**: Not optional. `@media (prefers-reduced-motion: reduce)` — crossfade instead of spatial movement. Preserve functional animations (progress, spinners)
- **Perceived performance**: 80ms threshold feels instant. Optimistic UI for low-stakes actions. Ease-in toward completion compresses perceived time

## Interaction

- **Anchor inheritance**: Link text must not inherit its color from a styled parent and blend invisibly into body text. Links need their own distinct color or underline treatment—an anchor that looks identical to surrounding text is a discoverability failure.
- **Eight states**: Default, hover, focus, active, disabled, loading, error, success. Every interactive element needs all eight designed
- **Focus rings**: Never `outline: none` without replacement. Use `:focus-visible` for keyboard-only rings. 2-3px, offset, 3:1 contrast minimum
- **Placeholders are not labels**: They disappear on input. Always use visible `<label>` elements
- **Validate on blur**, not every keystroke (exception: password strength)
- **Errors below fields** with `aria-describedby` connecting them
- **Modals**: Use `<dialog>` element or `inert` attribute for focus trapping. `dialog.showModal()` handles Escape, backdrop, focus trap
- **Popovers**: Use native `popover` attribute for tooltips/dropdowns—light-dismiss, proper stacking, no z-index wars
- **Destructive actions**: Undo > confirmation dialogs (users click through confirmations mindlessly)
- **Roving tabindex**: For component groups (tabs, menus), one item tabbable, arrow keys move within

## Responsive

- **Mobile-first**: Base styles for mobile, `min-width` queries to layer up. Desktop-first means mobile loads unnecessary styles
- **Content-driven breakpoints**: Don't chase device sizes. Stretch until design breaks, add breakpoint there. Three usually suffice (640, 768, 1024px)
- **Pointer/hover queries**: `@media (pointer: coarse)` for larger touch targets, `@media (hover: none)` to skip hover states. Screen size doesn't tell you input method
- **Safe areas**: `padding: env(safe-area-inset-*)` with `viewport-fit=cover` for notches and home indicators
- **Images**: `srcset` with width descriptors + `sizes` attribute. `<picture>` for art direction (different crops, not just resolution)
- **Test on real devices**: DevTools misses touch interactions, CPU constraints, font rendering, keyboard appearances

## UX Writing

- **Button labels**: Never "OK," "Submit," "Yes/No," "Click here." Use verb + object: "Save changes," "Create account," "Delete message"
- **Destructive buttons**: "Delete" not "Remove" (delete = permanent, remove = recoverable). Show count: "Delete 5 items"
- **Error formula**: What happened + why + how to fix. "Email needs an @ symbol" not "Invalid input"
- **Don't blame users**: "Please enter a date in MM/DD/YYYY format" not "You entered an invalid date"
- **Empty states**: Acknowledge briefly, explain value, provide action. "No projects yet. Create your first one to get started."
- **Terminology consistency**: Pick one and enforce it. Delete/Remove/Trash = just Delete. Settings/Preferences/Options = just Settings
- **Translation**: German +30%, French +20%, Finnish +30-40%. Keep numbers separate, use full sentences, avoid abbreviations
- **Link text**: Standalone meaning—"View pricing plans" not "Click here." Alt text describes information, not the image

## Brand Register Guards

### The Inverse Test

Describe your page the way a competitor would describe theirs. If that sentence fits the modal landing page in the category, restart. The interface should be so fitted to its context that the aesthetic can't be transplanted.

### Reflex-Reject Aesthetic Lanes

The editorial-typographic lane is now saturated: Klim-influenced, magazine-cover affectation, three rule-separated columns, italic Fraunces/Recoleta/Newsreader headline. If you find yourself reaching for this shape, you've fallen into the second-order reflex—avoiding the obvious defaults but landing on the same non-obvious default everyone else did.

The hand-drawn lane is filling the same way through 2026: doodle icon sets, wobbly borders, marker headline, paper ground. It stays a real answer for a build whose subject is handmade, taught, or drafted. It becomes the third-order reflex the moment it is reached for because the default set felt generic. `data/styles.csv` row 84's `Do Not Use For` column decides which case this is.

### Cultural-Symbol Palette Guardrail

Reach past the obvious cultural color association. Green for sustainability, blue for finance, red for food—these are first-order reflexes. Let cultural reading come from typography and imagery, not color alone. The hue should be a brand decision, not a category reflex.

### Category-Reflex Check

Apply at two altitudes:
1. **First-order**: Given the category (fintech, health, e-commerce), guess the theme and palette. If your design matches that guess, restart.
2. **Second-order**: Given the category PLUS anti-references (avoid the obvious), guess the aesthetic family. If your design matches that refined guess, push further.
