# Reference Sources

Component registries and design references. Read this file when `SKILL.md` Step 0
routes you here, which is when a proven implementation beats inventing one.

## The rule that governs every component source

A reference source answers "what does good look like here". It does not answer
"what do I paste". Fetch the reference, read its structure, its states and its
motion, then write the component against the project's own design system and
tokens.

Three sources sell their source code: HeroUI Pro, ThreeUI Pro, and 21st
membership. Read their public documentation. Never copy paid source into a
project that holds no license. Name the source that informed the work when you
deliver it.

Every endpoint below was reachable on 2026-09-01. A 404 means the site moved its
agent surface, so fall back to the human page and say so.

An asset source runs on the opposite rule. `## Asset sources` at the end of this
file carries it.

## Pick a source

| You need | Source | Cost |
|---|---|---|
| Micro-interaction feel: spring press, morph, shared layout | beUI | free, MIT |
| Interaction craft with accessibility built in; AI thinking states | Fluid Functionalism | free |
| Page sections and full compositions: hero, pricing, footer, showcase | 21st, Watermelon | free tier |
| Product UI: data grid, sidebar, calendar, command palette, KPI | HeroUI Pro | paid |
| Dashboards and templates as whole pages | Watermelon | free |
| 3D hero, shader background, WebGL motion | ThreeUI | free tier |
| A shadcn theme that is not the default one | tweakcn | free |
| Scroll choreography, SVG morph, timeline, page transition | GSAP | free |
| Hand-drawn icons, or doodle decoration for a sketch-style build | Asset sources, below | free, mixed |
| A design system an agent can reload next session | DESIGN.md, see `local/design-md.md` | free |

## How to fetch

Two mechanisms cover every source. Prefer the first.

1. **Markdown for agents.** Most sources publish `/llms.txt` as an index of
   `.md` pages. Read `llms.txt`, pick the one page you need, then fetch that page.
   Reading the whole catalog costs tokens and answers nothing.
2. **Registry JSON.** shadcn-format registries return one component or theme as
   JSON. Fetch by exact slug.

```bash
curl -sL https://beui.dev/llms.txt                 # index of component .md pages
curl -sL https://beui.dev/components/motion/dock.md # one component
curl -sL https://beui.dev/r/dock                    # registry JSON
```

## Sources in detail

### beUI - beui.dev

Animated React components. React 19, Tailwind 4, Framer Motion. MIT, with a
paid Pro tier. 112+ components across Motion Primitives (Morphing Modal, Dynamic
Island, Dock, Tilt Card, Bottom Sheet, Command Palette, Wheel Picker, Cylinder
Carousel, Text and Number animation) and Blocks (OTP input, file upload,
feedback widget, sign-up form, swipeable list).

| Surface | Endpoint |
|---|---|
| Agent index | `https://beui.dev/llms.txt` |
| Component markdown | `https://beui.dev/components/{category}/{slug}.md` |
| Registry index | `https://beui.dev/r` |
| Registry item | `https://beui.dev/r/{slug}` |
| Raw source | `https://beui.dev/r/{slug}/raw` |
| Motion guide | `https://beui.dev/docs/motion-patterns.md` |
| Install | `npx shadcn@latest add @beui/{slug}` |

Reach for it when the page works but feels static, and one named interaction
would fix it. Its motion guide is condensed into `local/motion-craft.md`, so
read that first and fetch beUI only for a specific component.

### Fluid Functionalism - fluidfunctionalism.com

24 components built on Radix or Base UI, shadcn-token compatible. The thesis:
motion is information, not decoration. Free.

Unique to this source: **Thinking Indicator** and **Thinking Steps**. An agent
that is searching, reading, thinking, then generating has four distinct states,
and one spinner reports none of them. Reach for these when building an AI
product surface.

| Surface | Endpoint |
|---|---|
| Registry index | `https://fluidfunctionalism.com/r/registry.json` |
| Registry item | `https://fluidfunctionalism.com/r/{slug}.json` |
| Install | `npx shadcn@latest registry add @fluid` |

It publishes no `llms.txt`. Fetch the registry JSON, or read the component page.

### 21st - 21st.dev

Community catalog, 12,000+ React and Tailwind components in shadcn registry
format. Free browsing plus 2 component copies per day; membership lifts the cap.

| Surface | Endpoint |
|---|---|
| Agent index | `https://21st.dev/llms.txt` |
| MCP server | `https://21st.dev/mcp` (key sent as `x-api-key`) |
| CLI | `npx @21st-dev/cli@latest init --client claude` |

"Magic MCP" is the former name of the same server. The `@21st-dev/magic` npm
package still proxies to it, and the old tool names (`21st_magic_component_builder`
and friends) still resolve. Keys from the old Magic console were reset.

Reach for it to find a structure before designing one. Its breadth is also its
risk. A catalog this size answers any query with something plausible. Judge the
result against the project's design system before you adopt it.

### HeroUI Pro - heroui.pro

Paid premium components and templates for React and React Native, from the
HeroUI (formerly NextUI) team. The categories are the ones a landing page never
needs: data grid, sidebar, calendar, forms, charts, KPI, command palette, prompt
input, message threads.

| Surface | Endpoint |
|---|---|
| Agent index | `https://heroui.pro/llms.txt` |

Public machine-readable docs omit the protected source; licensed examples need
authentication. Reach for it when the work is a SaaS or dashboard product
surface, and use it as a structural reference only.

### Watermelon UI - ui.watermelon.sh

Free and open source. Its distinction is scope: animated components, blocks,
whole dashboards, templates, and showcase compositions. Reach for it when the
open question is how a whole page composes, not how one control behaves.

| Surface | Endpoint |
|---|---|
| Agent index | `https://ui.watermelon.sh/llms.txt` |
| MCP server | `https://mcp.watermelon.sh/` |
| OpenAPI | `https://ui.watermelon.sh/openapi.json` |
| Catalogue listing | `https://ui.watermelon.sh/api/catalog/entries?kind=blocks` |
| Catalogue counts | `https://ui.watermelon.sh/api/catalog/summary` |

Public endpoints are read-only and need no key.

### ThreeUI - threeui.com

Procedural three.js and WebGL components from Design+Code: animated hero
sections, interactive shaders, backgrounds, motion pieces, and landing-page
templates. 50 Community parent components across 164 browse results, free and
open source. Pro adds 50+ components behind a yearly or lifetime plan.

| Surface | Endpoint |
|---|---|
| Agent index | `https://threeui.com/llms.txt` |
| Source | `https://github.com/MengTo/threeui` |
| Install | `npm install @designcodeio/threeui` |

```tsx
import { AtTheHorizon } from "@designcodeio/threeui/components/AtTheHorizon";
import "@designcodeio/threeui/style.css";
```

Pair it with `--stack threejs`. Before adding a WebGL hero, budget it: a shader
canvas competes with LCP and with battery, so gate it behind
`prefers-reduced-motion` and behind a pointer-capability check.

### tweakcn - tweakcn.com

Visual theme editor for shadcn/ui: colors, fonts, radius, shadows, letter
spacing, both Tailwind v3 and v4. Free. It exists to solve one problem, which is
that default shadcn is itself an AI tell.

| Surface | Endpoint |
|---|---|
| Theme registry index | `https://tweakcn.com/r/registry.json` |
| One theme | `https://tweakcn.com/r/themes/{slug}.json` |
| Install | `npx shadcn@latest add https://tweakcn.com/r/themes/{slug}.json` |

The JSON is a shadcn `registry:style` item carrying `cssVars` for `theme`,
`light` and `dark`. It publishes no `llms.txt`; fetch the registry index for the
theme list.

Use it as a starting palette, then verify contrast against
`local/wcag-checklist.md`. A generated theme is not an accessible theme.

### GSAP - gsap.com

v3.15. The plugin set: ScrollTrigger, ScrollSmoother, SplitText, Flip, DrawSVG,
MorphSVG, MotionPath, Draggable, Observer, Inertia. React use goes through the
`useGSAP()` hook in `@gsap/react`.

**Every plugin is free, commercial use included.** Webflow acquired GreenSock in
October 2024 and made the whole toolset free at v3.13 in May 2025. Club GSAP is
gone: no membership, no license key, no auth token, no private registry. One row
in `data/motion.csv` still calls SplitText "a GSAP Club/paid plugin" and asks for
a plain-fade fallback. That row is stale and stays stale because `data/` is
replaced wholesale from upstream. Ship SplitText without the fallback.

Query `--domain gsap` first; `local/motion-craft.md` sets the boundary between those
presets and this file. Fetch `https://gsap.com/docs/v3/` only for a plugin the presets
do not cover.

### Taste Skill - github.com/Leonxlnx/taste-skill

Not a component source. It is a competing frontend skill, MIT, and its three
dials map one to one onto this skill's `--variance`, `--motion` and `--density`.
Its production-test tells are merged into `local/anti-patterns.md`. Read them there.
Installing taste-skill alongside this one buys a second copy of the same rules in a
single 87KB file.

---

## Asset sources

The rule at the top of this file governs a component source, whose value is its
structure. An asset source is the opposite case: its files are the thing you
paste. Two gates open before you paste one.

**The style gate.** The resolved style must already be hand-drawn.
`data/styles.csv` row 59 (Anti-Polish / Raw Aesthetic) and row 84 (Sketch
Hand-Drawn) carry the tokens for it, and row 84's `Do Not Use For` column is the
gate itself. Read that column before you fetch. A doodle icon dropped into a
fintech, medical, or dense-dashboard surface is worse than the default set it
replaced. These sets answer "this build is hand-drawn and needs icons". They do
not answer "Lucide feels generic".

**The license gate.** Three of the four sets need no attribution. dddoodle needs
a visible credit, so it costs a line of page furniture.

| Set | Shipped | License | Fetch |
|---|---|---|---|
| Oreo Doodle Icons | 152 | MIT | `github.com/oreo-design/doodle-icons` |
| Sketchy Icon Library | 561 | MIT | `github.com/Downshift/sketchy-icons` |
| khushmeen Doodle Icons | 400+ | CC0 | `khushmeen.com/icons.html` |
| dddoodle | 120+ | CC-BY, credit required | `fffuel.co/dddoodle` |

None of the four publishes `llms.txt` or a shadcn registry. Fetch the two MIT
sets from GitHub raw. The other two need a human download.

Every row was checked on 2026-09-09.

### Oreo Doodle Icons - oreoui.com/doodle-icons

8 categories: interface, files, arrows, communication, media and devices,
weather and nature, home and objects, text and tools. Each icon draws its stroke
on, then keeps a "boiling" wiggle. Freemium: the site shows 158 with several
marked Pro, and the MIT repo carries 152. It pairs with the Schoolbell typeface.

Reach for it when the surface is small and the icon set must read as one hand.
It is the most active of the four (87 stars, updated 2026-09-08).

### Sketchy Icon Library - sketchie.ai/icons

Built for whiteboard-explainer video, so every SVG splits two layers. `.ink`
holds outline strokes, one continuous geometry per shape, so `getTotalLength()`
plus an animated `stroke-dashoffset` draws the icon on. `.fills` holds flat
color grouped by `data-region`, so the wash-in staggers region by region.
`index.json` is the catalogue.

Reach for it when the icon must animate itself being drawn. Static use is fine
and needs none of that structure.

**Count correction.** The landing page headline says 10,385 icons. The repo
ships 561. `taxonomy.json` holds a 10,049-concept roadmap the set fills in
batches, and the headline counts the roadmap. Quote 561. It is also not on npm;
`sketchy-icons` there is an unrelated package unpublished in 2022.

### khushmeen Doodle Icons - khushmeen.com/icons.html

The largest finished set of the four, 400+ across 15 categories, in SVG, PNG and
a Figma community file. It also ships animated Lottie icons as JSON. CC0, so
commercial use needs no credit.

Reach for it when the build needs breadth rather than motion. It has no repo and
no agent surface, so a human downloads the pack once and commits it.

### dddoodle - fffuel.co/dddoodle

Decoration, not an icon system: arrows, circles, stars, underlines, emphasis
marks, abstract scribbles. Reach for it for a hero, an empty state, or a
marketing page that needs one hand-drawn accent over an otherwise clean set.

`uwarp.design/dddoodle` wraps this pack and ranks above it in search. The pack
is fffuel's, and the CC-BY credit belongs to fffuel.
