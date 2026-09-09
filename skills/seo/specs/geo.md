# GEO spec

Generative Engine Optimization: AI crawler accessibility, llms.txt, passage-level citability, brand mention signals, and platform-specific optimization for Google AI Overviews, ChatGPT, Perplexity, and Bing Copilot.

## Steps

1. Fetch the page and check robots.txt for AI crawler rules.
2. Check for `/llms.txt` and RSL 1.0 licensing. `/llms.txt` is optional and is ignored by Google Search.
3. Analyze content citability (passage length, structure, directness). Run passage-level scoring against `extracted_text`, trafilatura's boilerplate-stripped output, not the full HTML, so navigation chrome and footers don't dilute the signal.
4. Evaluate authority signals (authorship, dates, citations, entity presence).
5. Assess technical accessibility for AI crawlers (SSR vs CSR).
6. Score across the 5 GEO Health Score dimensions and generate prioritized recommendations.
7. If DataForSEO MCP tools are available, use `ai_optimization_chat_gpt_scraper` for live ChatGPT visibility and `ai_opt_llm_ment_search` for LLM mention tracking.

## Reference

### GEO Health Score (0-100)

| Dimension | Weight |
|---|---|
| Citability | 25% |
| Structural Readability | 20% |
| Multi-Modal Content | 15% |
| Authority & Brand Signals | 20% |
| Technical Accessibility | 20% |

### AI crawlers to check in robots.txt

- Allow for AI search visibility: GPTBot, OAI-SearchBot, ClaudeBot, PerplexityBot.
- Optional block (training only): CCBot, anthropic-ai, cohere-ai.

### Key citability signals

- Optimal passage length: 134-167 words for AI citation.
- Direct answers in the first 40-60 words of each section.
- Question-based H2/H3 headings.
- Specific statistics with source attribution.
- Self-contained answer blocks (extractable without context).

### Brand mention correlation with AI citations

| Signal | Correlation |
|---|---|
| YouTube mentions | ~0.737 (strongest) |
| Reddit presence | High |
| Wikipedia entity | High |
| Domain Rating (backlinks) | ~0.266 (weak) |

Only 11% of domains are cited by both ChatGPT and Google AI Overviews, so platform optimization matters.

## Output

Report: GEO Readiness Score (0-100) with dimension breakdown, AI Crawler Access Status (allowed/blocked per crawler), llms.txt status (present/missing/malformed), brand mention analysis (Wikipedia, Reddit, YouTube, LinkedIn), top 5 highest-impact changes with effort estimates, and platform-specific scores (Google AIO, ChatGPT, Perplexity, Bing Copilot).

- findings file: `findings/geo.md` — AI crawler access, llms.txt, citability, entity, and platform visibility findings
- `audit-data.json` category: AI Search Readiness
