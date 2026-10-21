---
name: seo-content
description: >
  Content quality and E-E-A-T analysis with AI citation readiness assessment,
  plus last-mile draft cleanup (AI-typical phrasing and invisible Unicode
  watermark characters). Use when user says "content quality", "E-E-A-T",
  "content analysis", "readability check", "thin content", "content audit",
  "humanize", "AI phrasing", "remove watermarks", or "invisible characters".
user-invocable: true
disable-model-invocation: true
argument-hint: "[url]"
license: MIT
metadata:
  author: AgriciDaniel
  version: "2.3.1"
  category: seo
---

# Content Quality & E-E-A-T Analysis

## Google's "Who / How / Why" Test (canonical heuristic)

Before scoring E-E-A-T sub-factors, every page audit should pass Google's
own three-question heuristic from the helpful-content guide:

| Question | What to look for |
|---|---|
| **Who** created it? | Visible byline, author bio page, professional credentials. Required where readers expect it; non-negotiable for YMYL. |
| **How** was it created? | Process disclosure where readers would reasonably ask, especially for AI-assisted content. Original research / first-hand evidence / lived experience. |
| **Why** does it exist? | "To help people" rather than "to attract search clicks." Watch for niche entry without expertise, content churn for freshness signals, content written to a word-count target. |

Primary source:
https://developers.google.com/search/docs/fundamentals/creating-helpful-content

When all three answers are weak, the page is at risk under the core ranking
system's helpfulness signals (formerly the standalone Helpful Content System,
merged into core during the March 2024 update).

## E-E-A-T Framework (updated Sept 2025 QRG)

Read `../seo/references/eeat-framework.md` for full criteria.

### Experience (first-hand signals)
- Original research, case studies, before/after results
- Personal anecdotes, process documentation
- Unique data, proprietary insights
- Photos/videos from direct experience

### Expertise
- Author credentials, certifications, bio
- Professional background relevant to topic
- Technical depth appropriate for audience
- Accurate, well-sourced claims

### Authoritativeness
- External citations, backlinks from authoritative sources
- Brand mentions, industry recognition
- Published in recognized outlets
- Cited by other experts

### Trustworthiness
- Contact information, physical address
- Privacy policy, terms of service
- Customer testimonials, reviews
- Date stamps, transparent corrections
- Secure site (HTTPS)

Before you score word count, readability, keywords, structure, media or links, read `references/content-metrics.md`.

## AI Content Assessment (Sept 2025 QRG addition)

Google's raters assess low-quality, scaled, copied, or AI-generated main content patterns rather than AI authorship as a standalone issue.

### Acceptable AI Content
- Demonstrates genuine E-E-A-T
- Provides unique value
- Has human oversight and editing
- Contains original insights

### Low-Quality AI Content Markers
- Generic phrasing, lack of specificity
- No original insight
- Repetitive structure across pages
- No author attribution
- Factual inaccuracies

> **Helpful Content System (March 2024):** The Helpful Content System was merged into Google's core ranking algorithm during the March 2024 core update. Helpfulness signals are weighted within every core update. The same principles apply (people-first content, demonstrating E-E-A-T, satisfying user intent), but enforcement is continuous rather than through separate HCU updates. Google now also documents **continuous, smaller unannounced core updates** between major ones (changelog 2025-12-09).

> **Gen-AI optimization is SEO (Google docs, 2026-06-29):** the official "optimizing for generative AI features" guide states you do **not** need new AI files, markup, Markdown, content chunking, or AI-specific rewrites; chasing inauthentic "mentions" is unhelpful. AEO/GEO is rebranded SEO rooted in core ranking/quality.

> **Honest scoping (Google docs, 2026-06-05):** per "Using third-party SEO tools, services, and advice," no tool guarantees rankings and third-party tools have no access to Google's internal ranking data. claude-seo's scores are **heuristics**, not Google-internal signals, so say so in reports, and validate GEO/AEO findings against Google's official guidance (Search Console is the first-party source).

## Draft Cleanup: AI Phrasing & Invisible Watermarks

For "humanize this", "remove watermarks", or "clean up this draft", run the
bundled cleanup script on the user's own content:

```bash
"$HOME/.claude/skills/seo/scripts/claude-seo" run content_humanize.py draft.md -o cleaned.md
cat draft.md | "$HOME/.claude/skills/seo/scripts/claude-seo" run content_humanize.py --json
```

Two deterministic passes, both logged in the JSON output:

1. **Invisible characters** (`invisible_removed`): strips zero-width
   codepoints, directional marks/overrides, Unicode tag characters (hidden
   text smuggling), and normalizes exotic spaces. Emoji sequences (ZWJ,
   variation selectors next to emoji) are preserved.
2. **AI-typical phrasing** (`changes`): conservative 1:1 swaps from the
   replacement table ("delve into" → "explore", etc.). Nothing is
   paraphrased or added.

Scope honesty: statistical watermarks (SynthID-style token-probability
schemes) live in word choice, not codepoints. No tool reliably detects or
removes them; do not claim otherwise in reports. This cleanup is for
editing the user's own drafts, not for laundering third-party content —
decline requests to strip provenance from content the user doesn't own.

Before you assess AI citation readiness or GEO signals, read `references/ai-citation-geo.md`.

## Content Freshness

- Publication date visible
- Last updated date if content has been revised
- Flag content older than 12 months without update for fast-changing topics

## Output

### Content Quality Score: XX/100

### E-E-A-T Breakdown
| Factor | Score | Key Signals |
|--------|-------|-------------|
| Experience | XX/20 | ... |
| Expertise | XX/25 | ... |
| Authoritativeness | XX/25 | ... |
| Trustworthiness | XX/30 | ... |

> Weights are **this skill's own scoring model**, ordered to reflect Google's
> stated hierarchy: **Trust is most important** (30), then Expertise/
> Authoritativeness (25 each), then Experience (20); maxima sum to 100. Google
> publishes no numeric E-E-A-T weights (only that trust is most important), so
> treat the split as our internal model. Do not use an equal 25/25/25/25 split
> (it contradicts Google's "trust is most important").

### AI Citation Readiness: XX/100

### Issues Found
### Recommendations

## DataForSEO Integration (Optional)

If DataForSEO MCP tools are available, use `kw_data_google_ads_search_volume` for real keyword volume data, `dataforseo_labs_bulk_keyword_difficulty` for difficulty scores, `dataforseo_labs_search_intent` for intent classification, and `content_analysis_summary` for content quality analysis.

## Error Handling

| Scenario | Action |
|----------|--------|
| URL unreachable (DNS failure, connection refused) | Report the error clearly. Do not guess page content. Suggest the user verify the URL and try again. |
| Content behind paywall (402/403, login wall) | Report that the content is not publicly accessible. Analyze only the visible portion (meta tags, headers) and note the limitation. |
| Thin content (fewer than 100 words retrievable) | Report the findings as-is rather than guessing. Flag the page as potentially JavaScript-rendered or gated, and suggest the user provide the full text directly. |

## FLOW Framework Integration

For prompt-guided content optimization, use `/seo flow optimize <url>` and `/seo flow win <url>`: FLOW's optimize and win prompts provide structured E-E-A-T improvement and BOFU conversion workflows.
