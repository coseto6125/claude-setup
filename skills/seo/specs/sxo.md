# SXO spec

Search Experience Optimization: SERP backwards analysis to detect page-type mismatches, derive user stories from intent signals, and score pages from multiple persona perspectives. Determine why well-optimized content fails to rank.

<!-- Original concept: Florian Schmitz, SXO Skill (Pro Hub Challenge) -->

## Steps

### 1. Fetch and parse target page

- Fetch the target URL with `render_page.py "<url>" --mode auto --json`. Search experience scoring needs the rendered DOM because users see what JS produces; prefer `--mode always` so above-the-fold analysis matches what the persona actually encounters.
- Parse with `parse_html.py --url "<url>"` to extract SEO elements.
- Identify: page type, title, H1, meta description, headings, word count, schema, CTAs, media.
- If no keyword was provided, derive the primary keyword from title + H1 overlap.

### 2. SERP analysis

- Search Google for the target keyword using WebSearch.
- Analyze the top 10 organic results: classify each result's page type using `skills/seo-sxo/references/page-type-taxonomy.md`, and record content format, estimated depth, schema signals, media presence.
- Record SERP features: featured snippets, PAA questions, ads, related searches, AI Overview.
- Calculate SERP consensus: dominant page type and confidence percentage.

### 3. Page-type mismatch detection

- Classify the target page using the same taxonomy.
- Compare against the SERP dominant type.
- Rate mismatch severity: CRITICAL / HIGH / MEDIUM / ALIGNED.
- If a mismatch is detected, this is the primary finding; lead with it.

### 4. User story derivation

- Read `skills/seo-sxo/references/user-story-framework.md`.
- Derive 3-5 user stories from observed SERP signals.
- Every story must cite the specific signal that generated it.
- Cover at least 2 journey stages (awareness, consideration, decision).

### 5. Gap analysis

Score the target page across 7 dimensions, 100 points total: Page Type (0-15), Content Depth (0-15), UX Signals (0-15), Schema (0-15), Media (0-15), Authority (0-15), Freshness (0-10). Provide specific evidence for each score.

### 6. Persona scoring

- Read `skills/seo-sxo/references/persona-scoring.md`.
- Derive 4-7 personas from SERP signals.
- Score each persona on Relevance, Clarity, Trust, Action (25 pts each).
- Sort recommendations by weakest persona first.

### 7. Wireframe (only if requested)

- Read `skills/seo-sxo/references/wireframe-templates.md`.
- Generate an IST (current) wireframe from the parsed page.
- Generate a SOLL (recommended) wireframe matching SERP expectations.
- Use ultra-concrete placeholders with actual section names, CTA text, and link targets.

## Reference

### Cross-skill references

| Signal | Recommend |
|---|---|
| E-E-A-T gaps detected | `/seo content` for deep analysis |
| Missing schema types | `/seo schema` for generation |
| Local intent in SERP | `/seo local` for GBP analysis |
| Thin content | `/seo page` for page-level audit |

### Output rules

- The SXO score is separate from the SEO Health Score; always label it "SXO Gap Score".
- Lead with the mismatch finding if one exists; this is the key insight.
- Include a limitations section (what could not be assessed).
- Offer: "Generate a PDF report? Use `/seo google report`".

### Pre-delivery checklist

Before presenting results, verify:

- [ ] The URL was fetched via `render_page.py --mode auto` (not raw curl).
- [ ] At least 5 SERP results were analyzed.
- [ ] Page type classification uses the taxonomy reference.
- [ ] User stories cite specific SERP signals.
- [ ] Persona scores include concrete improvement suggestions.
- [ ] Mismatch severity is clearly rated.
- [ ] Limitations section is present.

## Output

- findings file: `findings/sxo.md` — SERP intent, page-type mismatch, user-story, persona, and UX gap findings
- `audit-data.json` category: Search Experience
