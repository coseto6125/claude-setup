---
name: ui-ux-pro-max
description: "UI/UX design intelligence backed by a searchable local database (84 styles, 192 palettes, 74 font pairings, 192 product types, 99 UX guidelines, 105 icon entries, 16 GSAP motion presets, 25 chart types, 22 stacks). Use when building UI — pages, components, landing pages, dashboards, color/typography/layout/animation systems — or when critiquing an existing design, mockup, or deployed interface for usability, accessibility (WCAG 2.1/2.2), visual hierarchy, and design-system consistency."
---

# UI/UX Pro Max - Design Intelligence

Searchable database of UI/UX design rules with priority-based recommendations: 84 styles, 192 color palettes, 74 font pairings, 192 product types with reasoning rules, 99 UX guidelines, 105 icon entries, 16 GSAP motion presets, 25 chart types, and 22 technology stacks.

## When to Apply

This skill has two branches. Pick one before doing anything else:

- **Build** — the task creates or changes how something looks, feels, moves, or is interacted with: new pages, new/refactored components, color–typography–spacing–layout systems, animation, responsive behavior. Continue to `## Running the search tool`.
- **Critique** — the task judges an existing artifact: design review, wireframe/mockup/prototype/deployed-UI audit, accessibility compliance check, design-system consistency assessment. Jump straight to `## Design Critique` and skip the build workflow.

Skip this skill for backend logic, API/database design, infrastructure, and non-visual scripts.

## Rule Categories by Priority

Work priority 1→10 when deciding what to fix first. Query full rule text with `--domain <domain>`; the complete text of all 99 guidelines lives in `references/quick-reference.md`, read on demand.

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

---

## Running the search tool

The script lives in the skill's own directory, not the project directory. Invoke it by absolute path from any working directory:

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --domain <domain>
```

If `python3` is missing, try `python`, then `py -3`. Requires Python 3.x, no external dependencies.

## Build Workflow

### Step 1: Analyze requirements

Extract from the request:
- **Product type** — SaaS, e-commerce, portfolio, dashboard, entertainment, tool, productivity, or a hybrid
- **Audience & context** — age group, usage setting (commute, leisure, work)
- **Style keywords** — playful, vibrant, minimal, dark mode, content-first, immersive
- **Stack** — read it off the project: `package.json` deps (`react`/`next`/`vue`/`svelte`/`nuxt`/`astro`/`@angular`), `pubspec.yaml` (Flutter), `*.xcodeproj` or `Package.swift` (SwiftUI), `composer.json` (Laravel), React Native markers (`app.json` + `react-native`). When nothing is detectable, ask the user which stack to target — every recommendation downstream is routed by this answer.

### Step 2: Generate the design system (required for any new page or project)

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

Searches product/style/color/landing/typography in parallel, applies the reasoning rules in `ui-reasoning.csv`, and returns pattern, style, colors, typography, effects, and anti-patterns to avoid.

### Step 2b: Persist it (Master + Overrides)

Add `--persist` together with `--output-dir` pointed at the project root — without `--output-dir` the files land in whatever directory the tool happened to run from:

```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "Project Name" --output-dir "<project-root>" [--page "dashboard"]
```

Writes `design-system/<project-slug>/MASTER.md` (global source of truth) and `design-system/<project-slug>/pages/`; `--page` adds `pages/<page>.md`.

When `MASTER.md` already exists, `--persist` silently leaves it untouched unless you pass `--force` — so a run that looks successful may have written nothing.

**Retrieval when building a page:** read `design-system/<project-slug>/pages/<page>.md` if it exists (its rules override Master), otherwise use `MASTER.md`.

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
- **Web / desktop** → `local/web-delivery-checklist.md` (cursor and hover feedback, light-mode glass and border visibility, floating-element spacing, container width, 375/768/1024/1440px)
- **Native / mobile app** (iOS, Android, React Native, Flutter) → `references/pro-rules.md` (touch feedback, safe areas, Dynamic Type, scrim legibility)

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

## Output formats

`--design-system` accepts `-f ascii` (default, terminal), `-f markdown` (documentation), and `--json` (machine-readable, includes the raw design-system dict plus persistence status).

## Troubleshooting

| Problem | Where to look |
|---------|---------------|
| Can't decide on style/color | Re-run `--design-system` with different keywords, or add `--variance` |
| Dark mode contrast issues | `references/quick-reference.md` §6 |
| Animations feel unnatural | `references/quick-reference.md` §7, or `--domain gsap` |
| Form UX is poor | `references/quick-reference.md` §8 |
| Navigation feels confusing | `references/quick-reference.md` §9 |
| Layout breaks on small screens | `references/quick-reference.md` §5 |
| Performance / jank | `references/quick-reference.md` §3 |
| Bad PageSpeed score, don't know why | `local/lighthouse-verify.md` (measure first; the audit titles mislead) |

---

## Design Critique

Read `local/critique-framework.md` and follow it. It runs a design-director review producing a **scored, prioritized report**: AI-slop detection, Nielsen 0–40 scorecard, cognitive-load and emotional-journey checks, persona red flags, P0–P3 issues, and optional cross-run trend tracking.

Deep references it loads on demand (all under `local/`): `heuristics-scoring.md` (scoring rubric), `personas.md`, `anti-patterns.md` (slop tells + technical standards), `cognitive-load.md`, `wcag-checklist.md`, `testing-resources.md`, `design-patterns-library.md`.

When the artifact under review is a live URL or a buildable web project, measure it before writing the report — `local/lighthouse-verify.md`. Measured accessibility and performance findings outrank anything you infer by reading the page.

---

## Upgrading from upstream

`data/`, `scripts/`, and `references/` are pulled wholesale from [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) and carry no local edits — replace them as a unit. `local/` and this file are local work: the critique branch, the web delivery checklist, and the Lighthouse verification (`lighthouse-verify.md` + `lighthouse_ab.py`) have no upstream equivalent, and the invocation paths here are absolute because this is installed as a user skill, not a plugin (`${CLAUDE_PLUGIN_ROOT}` is unset).
