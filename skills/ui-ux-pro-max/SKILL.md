---
name: ui-ux-pro-max
description: "UI/UX design intelligence: a searchable local database of styles, palettes, font pairings, product types, UX guidelines, icons, GSAP motion presets and chart types for 22 stacks, plus a registry of external component sources (beUI, 21st, Watermelon, HeroUI Pro, ReUI, ThreeUI, Fluid Functionalism, tweakcn, GSAP, GlideCN, lucide-animated, DESIGN.md). Use when building UI — pages, components, landing pages, dashboards, color/typography/layout/animation systems — or when critiquing an existing design, mockup, or deployed interface for usability, accessibility (WCAG 2.1/2.2), visual hierarchy, and design-system consistency."
---

# UI/UX Pro Max - Design Intelligence

A searchable database of UI/UX design rules with priority-based recommendations. The row counts live in `data/`; query it rather than recalling it.

## When to apply

Pick one branch before you do anything else:

- **Build**: the task creates or changes how something looks, feels, moves or responds: a new page, a new or refactored component, a color, typography, spacing or layout system, animation, responsive behavior. Continue at Step 0.
- **Critique**: the task judges an existing design, mockup or deployed interface. Go to **Design Critique** below.

## Step 0: Route by what you are making

Pick the row that matches. After its search, and before you write the first line
of code, Read every file in its `Read before you build` column.

| Making | Search | Read before you build | Reference source |
|---|---|---|---|
| One control: button, input, select, modal, tabs, toast, agent progress state | `--domain ux` + `--stack <stack>` | `local/design-patterns-library.md`, `local/motion-craft.md` | Fluid Functionalism, beUI, lucide-animated for an icon that moves |
| One page section: hero, pricing, feature block, footer | `--domain landing` | `local/anti-patterns.md` | 21st, Watermelon blocks |
| A whole landing or marketing page | `--design-system` | `local/anti-patterns.md`, `local/web-delivery-checklist.md` | Watermelon showcases, 21st templates |
| A dashboard or data-dense app screen | `--design-system --density 8`, then `--domain chart` | `local/data-screens.md`, `local/cognitive-load.md` | HeroUI Pro, ReUI, Watermelon dashboards |
| Motion: scroll choreography, page transition, 3D or shader hero | `--domain gsap`, plus `--stack threejs` for 3D | `local/motion-craft.md` | GSAP, ThreeUI, GlideCN for a route change |
| A theme or token system: colors, radius, type scale | `--domain color`, then `--domain typography` | `local/wcag-checklist.md` | tweakcn |
| Chinese text that wraps to two or more lines: a heading, a lead, a paragraph, a phone layout | `--domain typography "chinese"` | `local/cjk-line-breaking.md` | clreq, BudouX |
| A hand-drawn or doodle surface | `--domain style "hand-drawn sketch"` | `local/sources.md`, `local/anti-patterns.md` | Oreo Doodle, Sketchy, khushmeen, dddoodle |
| A design system meant to outlive this session | `--design-system --persist` | `local/design-md.md` | DESIGN.md spec |
| A poster, flyer, or any print piece | this skill covers screens. For artboards, tell the user to run `/design` | | |

Rows compose: a landing page with a 3D hero reads both rows.

**Three depths.** L0 is this file. L1 is a `local/` file a row names. L2 is a
reference source's own docs, fetched when a proven implementation settles a
question faster than reasoning does. `local/sources.md` holds every endpoint and
its license terms.

## Rule Categories by Priority

Work priority 1→10 when deciding what to fix first. Query full rule text with `--domain <domain>`. The complete checklist lives in `references/quick-reference.md`; read it on demand.

| Priority | Category | Impact | Domain | Key Checks | Anti-Patterns |
|----------|----------|--------|--------|------------|---------------|
| 1 | Accessibility | CRITICAL | `ux` | Contrast 4.5:1, alt text, keyboard nav, aria-label on icon-only buttons | Removed focus rings, tab order ≠ visual order |
| 2 | Touch & Interaction | CRITICAL | `ux` | 44×44px targets, 8px+ spacing, loading feedback | Hover-only affordances, instant (0ms) state changes |
| 3 | Performance | HIGH | `ux` | WebP/AVIF, lazy loading, reserved space (CLS < 0.1) | Layout thrashing, cumulative layout shift |
| 4 | Style Selection | HIGH | `style`, `product` | Style matches product type, one style across all pages, SVG icons | Emoji as icons, mixing flat and skeuomorphic |
| 5 | Layout & Responsive | HIGH | `ux` | Mobile-first breakpoints, `width=device-width`, z-index scale | Horizontal scroll, fixed px containers, disabled zoom |
| 6 | Typography & Color | MEDIUM | `typography`, `color` | 16px body minimum, line-height 1.5, semantic color tokens | Body text < 12px, gray-on-gray, raw hex in components |
| 7 | Animation | MEDIUM | `ux`, `gsap` | 150–300ms, motion conveys meaning, spatial continuity | Decorative-only motion, animating width/height, no reduced-motion |
| 8 | Forms & Feedback | MEDIUM | `ux` | Visible labels, error beside the field, progressive disclosure | Placeholder-as-label, errors only at page top |
| 9 | Navigation | HIGH | `ux` | Predictable back behavior, bottom nav ≤ 5, deep linking | Overloaded nav, broken back button |
| 10 | Charts & Data | LOW | `chart` | Legends, tooltips, accessible colors | Color as the only encoding |

## Running the search tool

The script lives in the skill's own directory, not the project directory. Invoke it by absolute path from any working directory:

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --domain <domain>
```

If `python3` is missing, try `python`, then `py -3`. Requires Python 3.x, no external dependencies.

When a search result conflicts with a `local/` file, the `local/` file wins. Known conflicts:

| Search output | Use instead |
|---|---|
| `back.out(...)` easing in a `--domain gsap` snippet | an ease-out curve (`local/anti-patterns.md` § Motion) |
| "Feature grid/cards (4-6)" in a `--domain landing` section order | sections chosen from the page's argument (Step 1) |
| `legend-visible` ("Always show legend") | no legend for a single series (`local/data-screens.md` § Charts) |
| "Smooth Area" in `--domain chart` | a straight line (`local/data-screens.md` § Charts) |

`--design-system` prints `-f ascii` by default. Pass `-f markdown` for a document, or `--json` for the raw design-system dict plus persistence status.

## Build Workflow

### Step 1: Analyze requirements

Extract from the request:
- **Product type** — SaaS, e-commerce, portfolio, dashboard, entertainment, tool, productivity, or a hybrid
- **Audience & context** — age group, usage setting (commute, leisure, work)
- **Surface** — Persuade (landing, marketing), Read (docs, articles) or Operate (dashboards, tools). Persuade gets full commitment: bold, distinct work. On Read and Operate, ambition shows as precision and restraint, and patterns the visitor already knows earn their place
- **Style keywords** — playful, vibrant, minimal, dark mode, content-first, immersive
- **Stack** — read it off the project: `package.json` deps (`react`/`next`/`vue`/`svelte`/`nuxt`/`astro`/`@angular`), `pubspec.yaml` (Flutter), `*.xcodeproj` or `Package.swift` (SwiftUI), `composer.json` (Laravel), React Native markers (`app.json` + `react-native`). When nothing is detectable, ask the user which stack to target — every recommendation downstream is routed by this answer.

For a page, write its argument before any layout: one claim per section, in the order the page shows them. Delete a section with no claim.

### Step 2: Generate the design system (required for any new page or project)

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

Searches product/style/color/landing/typography in parallel, applies the reasoning rules in `ui-reasoning.csv`, and returns pattern, style, colors, typography, effects, and anti-patterns to avoid.

### Step 2b: Persist it (Master + Overrides)

Before you run `--persist`, read `local/design-md.md` § Persisting the design system. When building a page in a project that has one, read `design-system/<project-slug>/pages/<page>.md` if it exists (its rules override Master), otherwise `MASTER.md`.

### Step 2c: Design dials (optional)

Three 1–10 sliders that tune `--design-system` output without changing the query. An unset dial leaves that part of the output unchanged.

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --variance 8 --motion 7 --density 8
```

| Dial | Low (1-3) | Mid (4-7) | High (8-10) |
|------|-----------|-----------|-------------|
| `--variance` | Centered / minimal (biases toward Minimalism) | Balanced / modern | Bold / asymmetric (biases toward Brutalism, Bento) |
| `--motion` | Subtle micro-interactions | Standard scroll/stagger | Complex choreography (pin, Flip, SplitText) |
| `--density` | Spacious (24-96px scale) | Standard (16-64px, default) | Dense/dashboard (8-32px scale) |

`--motion` attaches a ready-to-use GSAP snippet matched to the resolved tier. `--density` rewrites the `--space-*` variable table in the output — use it for dashboards (high) vs marketing pages (low) instead of hand-editing tokens.

### Step 3: Deep-dive individual domains

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> [-n <max_results>] [--full]
```

| Domain | Use for | Example query |
|--------|---------|---------------|
| `product` | Product-type patterns | `"entertainment social"` |
| `style` | UI styles and effects | `"glassmorphism dark"` |
| `color` | Palettes by product type | `"fintech trustworthy"` |
| `typography` | Font pairings | `"playful modern"` |
| `google-fonts` | Individual Google Fonts | `"sans serif variable"` |
| `landing` | Page structure, CTA strategy | `"hero social-proof"` |
| `icons` | Icon set recommendations | `"navigation outline"` |
| `gsap` | GSAP animation presets | `"scroll reveal stagger"` |
| `chart` | Chart types and libraries | `"real-time dashboard"` |
| `ux` | Guidelines and anti-patterns | `"animation accessibility"` |
| `react` | React/Next.js performance | `"rerender memo list"` |
| `web` | App/native interface guidelines | `"accessibilityLabel safe-areas"` |

Domain is auto-detected when `--domain` is omitted, and overlapping terms misroute (e.g. "font" matches both `typography` and `google-fonts`) — pass `--domain` explicitly whenever results look off-topic.

### Step 4: Stack guidelines

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --stack <stack>
```

Available: `html-tailwind`, `react`, `nextjs`, `vue`, `nuxtjs`, `nuxt-ui`, `svelte`, `astro`, `angular`, `laravel`, `shadcn`, `threejs`, `swiftui`, `react-native`, `flutter`, `jetpack-compose`, `javafx`, `wpf`, `winui`, `avalonia`, `uno`, `uwp`. Use the stack detected in Step 1.

### Step 5: Before delivering

Read the checklist matching the target and run through every item:
- **Web / desktop** → `local/web-delivery-checklist.md` (hover feedback, custom-control gestures, light-mode contrast, margins and first screen, 375/768/1024/1440px)
- **Native / mobile app** (iOS, Android, React Native, Flutter) → `references/pro-rules.md` (touch feedback, safe areas, Dynamic Type, scrim legibility)

Then look at the render:

1. Render the build and take screenshots at the checklist widths. Judge the screenshots, not the code.
2. Drive every reachable state: open, closed, hover, focus, error, empty, overlong content. Check each for overlap and clipping.
3. Fix the top three findings, then look again. Stop after three rounds, and report what is left.
4. Run the last round on the production build.

### Step 6: Measure it (web only)

Priority 1 and 3 in the table above — accessibility and performance — are the two
categories a tool checks better than you do. Read `local/lighthouse-verify.md` and
run the measurement whenever the work touched page speed, fonts, CSS delivery, or
above-the-fold markup, and whenever the user brings a PageSpeed Insights report.

```bash
python3 ~/.claude/skills/ui-ux-pro-max/local/lighthouse_ab.py before=<dir-or-url> after=<dir-or-url>
```

Report the medians it prints. Never estimate a score, and never claim an
improvement you did not measure — a single Lighthouse run has a ~30 point spread,
so one before-run against one after-run proves nothing.

## When a search returns 0 results

1. Retry once with broader or differently-worded keywords (query product and style separately rather than combined).
2. Still empty → fall back to the priority table above, and tell the user this recommendation came from built-in defaults rather than a database match (e.g. "no palette match for X, using general SaaS defaults").
3. Present a 0-result search as a 0-result search. Never fill the gap with invented data.

## Troubleshooting

When a result looks wrong (style, dark-mode contrast, motion, forms, navigation, small screens, performance, a PageSpeed score), read `local/troubleshooting.md`.

## Design Critique

Read `local/critique-framework.md` and follow it. It runs a design-director review producing a **scored, prioritized report**: AI-slop detection, Nielsen 0–40 scorecard, cognitive-load and emotional-journey checks, persona red flags, P0–P3 issues, and optional cross-run trend tracking.

Deep references it loads on demand (all under `local/`): `heuristics-scoring.md` (scoring rubric), `personas.md`, `anti-patterns.md` (slop tells + technical standards), `cognitive-load.md`, `wcag-checklist.md`, `testing-resources.md`, `design-patterns-library.md`, `data-screens.md` (dashboards and app screens).

When the artifact under review is a live URL or a buildable web project, measure it before writing the report — `local/lighthouse-verify.md`. Measured accessibility and performance findings outrank anything you infer by reading the page.

## Upgrading from upstream

`data/`, `scripts/` and `references/` come unedited from `.claude/skills/ui-ux-pro-max/` in [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill). Replace them as a unit, then run `scripts/validate_data.py` and check that every `search.py` flag this file uses still exists. `local/` and this file are local work with no upstream equivalent. Paths are absolute because this installs as a user skill, where `${CLAUDE_PLUGIN_ROOT}` is unset. Last synced: upstream `dcc40ff`, 2026-09-23.
