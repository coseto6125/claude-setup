# Design Critique Framework

Review an existing design **as a design director** — turn subjective "I don't like it" into a scored, prioritized, actionable report. **Report-only**: document issues, don't fix them unless the user asks.

Adapted from tdimino's `design-critique` + `minoan-frontend-design`. Deep references (all in this folder, read on demand):
- `heuristics-scoring.md` — Nielsen 0-4 scoring rubric + score bands + P0-P3 + 5-dim technical audit
- `personas.md` — 5 user archetypes + selection table + red flags
- `anti-patterns.md` — AI slop tells + typography/color/spacing/motion/interaction standards + brand-register guards
- `cognitive-load.md` — 8-item checklist + working-memory rule
- `wcag-checklist.md` — full WCAG 2.1/2.2 A/AA/AAA criteria
- `testing-resources.md` — testing tools & methodology · `design-patterns-library.md` — accessible pattern implementations

## Preparation

1. **Resolve the target** to a concrete file path ("the homepage" → `src/pages/index.tsx`); paths are stable, dev ports drift.
2. **Context determines right vs wrong.** If no `.design-context.md` / `DESIGN.md` in project root, ask about audience + intended feel before judging. Don't block on it — flag assumptions.
3. **Ignore list:** if `.design-critique/ignore.md` exists, each non-comment line is "do not re-raise" (deferred tradeoffs, intended deviations, accepted false positives). When a finding matches a line (case-insensitive substring), **drop it silently**.

## Step 1 — Holistic Review (as design director)

Read the source (HTML/CSS/JS/TS); if browser automation is available, inspect visually in a **fresh tab** (never reuse — prevents state interference). Evaluate:

- **AI slop detection** — does this look like every other AI interface? Check `anti-patterns.md` "AI Slop Tells". Tells: AI palette (purple-on-white, neon-on-dark), gradient text, glassmorphism, hero-metric template, identical card grids, generic/second-tier fonts (Inter, *and* over-used Fraunces/Outfit/Space Grotesk), side-tab accent borders. **The test:** if someone said "AI made this," would you believe it instantly?
- **Visual hierarchy** (eye flow, primary-action clarity), **composition** (balance, whitespace, rhythm), **typography**, **color** (purposeful, cohesive, accessible), **states & edge cases** (empty/loading/error/success).
- **Cognitive load** — run the 8-item checklist in `cognitive-load.md`. Report failure count: 0-1 low (good), 2-3 moderate, 4+ critical. At any decision point, count visible options; >4 → flag.
- **Emotional journey** — what emotion does it evoke, is that intentional? **Peak-end rule**: is the most intense moment positive, does it end well? Check anxiety spikes at high-stakes moments (payment/delete/commit) — are there interventions (progress, reassurance copy, undo)?

## Step 2 — Systematic Anti-Pattern Check

Walk `anti-patterns.md` item by item against the code (typography, color/OKLCH, spacing, motion, interaction states, responsive, UX writing, brand-register guards). Note where systematic checks catch what the holistic pass missed, and vice versa.

## Step 3 — Combined Report

### Design Health Score (Nielsen heuristics)

Score each of the 10 heuristics 0-4 per the rubric in `heuristics-scoring.md`. Be honest — a 4 is genuinely excellent; most real interfaces score 20-32.

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | ? | |
| 2 | Match System / Real World | ? | |
| 3 | User Control & Freedom | ? | |
| 4 | Consistency & Standards | ? | |
| 5 | Error Prevention | ? | |
| 6 | Recognition over Recall | ? | |
| 7 | Flexibility & Efficiency | ? | |
| 8 | Aesthetic & Minimalist | ? | |
| 9 | Error Recovery | ? | |
| 10 | Help & Documentation | ? | |
| **Total** | | **??/40** | |

Bands: 36-40 excellent · 28-35 good · 20-27 acceptable · 12-19 poor · 0-11 critical.

### Anti-Patterns Verdict
Does this look AI-generated? List specific tells found. (For full technical-dimension scores — a11y/perf/responsive/theming — use the 5-dim audit table in `heuristics-scoring.md`.)

### What's Working
2-3 things done well, specifically why.

### Priority Issues
3-5 most impactful, ordered. For each: **[P0-P3] What** · **Why it matters** (user impact) · **Fix** (concrete).
P0 = blocks task completion · P1 = significant difficulty or WCAG AA violation · P2 = annoyance w/ workaround · P3 = nice-to-fix.

### Persona Red Flags
Pick 2-3 personas most relevant (see selection table in `personas.md`). For each, walk the primary user action and name **specific** failing elements:
> **Alex (power user):** no keyboard shortcuts, 8 clicks to submit → high abandonment.
> **Jordan (first-timer):** icon-only nav, jargon in errors → abandons at step 2.

## Critique Persistence (optional)

To track trends across runs, write the report to `.design-critique/<YYYYMMDD-HHmmss>__<slug>.md` (slug = kebab of resolved path). Frontmatter: `target`, `resolved`, `total_score`, `p0_count`, `p1_count`, `date`. Append a trend line reading prior snapshots' `total_score`: *"Trend for `<slug>` (last 5): 24 → 28 → 32 → 29 → 32"*. Fire-and-forget — never block the report; `.design-critique/ignore.md` is user-maintained, never auto-generated.

---
Be constructive: lead with what works, tie every finding to user impact, give concrete fixes.
