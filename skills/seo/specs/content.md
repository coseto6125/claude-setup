# Content spec

Evaluate content quality: E-E-A-T signals, readability, content depth, AI citation readiness, and thin content, per Google's September 2025 Quality Rater Guidelines.

## Steps

1. Assess E-E-A-T signals (Experience, Expertise, Authoritativeness, Trustworthiness).
2. Check word count against page-type minimums.
3. Calculate readability metrics.
4. Evaluate keyword optimization (natural, not stuffed).
5. Assess AI citation readiness (quotable facts, structured data, clear hierarchy).
6. Check content freshness and update signals.
7. Flag potential AI-generated content quality issues per the Sept 2025 QRG criteria.

E-E-A-T scoring should run against `extracted_text` rather than `content`: trafilatura strips navigation chrome, footers, and cookie banners, so author bios and main-content trust signals score correctly without dilution.

## Reference

### E-E-A-T scoring

| Factor | Weight | What to look for |
|---|---|---|
| Experience | 20% | First-hand signals, original content, case studies |
| Expertise | 25% | Author credentials, technical accuracy |
| Authoritativeness | 25% | External recognition, citations, reputation |
| Trustworthiness | 30% | Contact info, transparency, security |

These percentages are this skill's internal scoring model, not Google's. Google publishes no numeric E-E-A-T weights; it states only that "trust is most important."

### Content minimums

| Page type | Min words |
|---|---|
| Homepage | 500 |
| Service page | 800 |
| Blog post | 1,500 |
| Product page | 300+ (400+ for complex products) |
| Location page | 500-600 |

These are topical coverage floors, not targets. Google confirms word count is NOT a direct ranking factor. The goal is comprehensive topical coverage.

### AI content assessment (Sept 2025 QRG)

AI content is acceptable if it demonstrates genuine E-E-A-T. Flag these markers of low-quality AI content:

- Generic phrasing, lack of specificity.
- No original insight or unique perspective.
- No first-hand experience signals.
- Factual inaccuracies.
- Repetitive structure across pages.

The Helpful Content System (March 2024) was merged into Google's core ranking algorithm during the March 2024 core update. It no longer operates as a standalone classifier; helpfulness signals are now evaluated within every core update.

### Cross-skill delegation

- Programmatically generated pages: defer to the `seo-programmatic` sub-skill.
- Comparison page content standards: see `seo-competitor-pages`.

## Output

- findings file: `findings/content.md` — E-E-A-T, readability, thin content, duplication, topical coverage, and AI citation findings
- `audit-data.json` category: Content Quality

Report: content quality score (0-100), E-E-A-T breakdown with scores per factor, AI citation readiness score, and specific improvement recommendations.
