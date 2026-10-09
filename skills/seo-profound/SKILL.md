---
name: seo-profound
description: Profound LLM citation tracker (extension). Time-series brand citation rates across ChatGPT, Perplexity, and other LLMs. Pairs with seo-seranking for triangulated AI visibility coverage.
metadata:
  version: "2.3.1"
compatibility: "Requires a Profound API key (PROFOUND_API_KEY in the env block of ~/.claude/settings.json)."
disable-model-invocation: true
---

# seo-profound

Profound is purpose-built for LLM brand-mention tracking. While
SE Ranking samples prompts on demand, Profound continuously polls and
publishes time-series so trend deltas (week-over-week, month-over-month)
are first-class.

## Prerequisites

- `PROFOUND_API_KEY` must be set in the environment. Before any tool call, check that the variable is set, without printing its value. If it is not set, ask the user to add it to the `env` block of `~/.claude/settings.json`.

## Routing

| Command | Purpose |
|---|---|
| `/seo profound citations <brand>` | Current citation rate per LLM + 30-day trend |
| `/seo profound prompts <brand>` | Top prompts that surface (or fail to surface) the brand |
| `/seo profound competitors <brand>` | Brands cited alongside `brand` for the same prompts |
| `/seo profound alerts <brand>` | Spike/drop alerts vs. 7-day baseline |

## Output conventions

- Cite Profound on every metric: "Profound (live, confidence 0.90)".
- Profound covers ChatGPT + Perplexity natively; for Gemini / AI
  Overviews / AI Mode coverage, defer to `seo-seranking`.
- For Google AI Overviews citation rate, also cross-reference
  `seo-dataforseo` AI visibility tools when available.

## Cross-skill delegation

- For end-to-end AI search audit (passage citability + brand mentions + platform-specific tuning), hand back to `seo-geo`.
- For prompt-set design + AI Cleanup pattern detection in cited content, fall back to `seo-content`.
