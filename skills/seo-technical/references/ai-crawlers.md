#### AI Crawler Management

As of 2025-2026, AI companies actively crawl the web to train models and power AI search. Managing these crawlers via robots.txt is a critical technical SEO consideration.

**Known AI crawlers:**

| Crawler | Company | robots.txt token | Purpose |
|---------|---------|-----------------|---------|
| GPTBot | OpenAI | `GPTBot` | Model training (NOT ChatGPT Search) |
| OAI-SearchBot | OpenAI | `OAI-SearchBot` | ChatGPT Search citability |
| ChatGPT-User | OpenAI | `ChatGPT-User` | Real-time browsing (user-triggered) |
| ClaudeBot | Anthropic | `ClaudeBot` | Model training (NOT Claude search citability) |
| Claude-SearchBot | Anthropic | `Claude-SearchBot` | Claude search-result citability |
| PerplexityBot | Perplexity | `PerplexityBot` | Search index + training |
| Bytespider | ByteDance | `Bytespider` | Model training |
| Google-Extended | Google | `Google-Extended` | Gemini training (NOT search) |
| Applebot-Extended | Apple | `Applebot-Extended` | Apple Intelligence training opt-out (NOT Siri/Spotlight/Safari) |
| CCBot | Common Crawl | `CCBot` | Open dataset |

**Key distinctions:**
- Blocking `Google-Extended` prevents Gemini training use but does NOT affect Google Search indexing or AI Overviews (those use `Googlebot`)
- Blocking `GPTBot` prevents OpenAI training but does NOT affect ChatGPT Search
  citability, which is governed by `OAI-SearchBot`, nor user-triggered browsing
  (`ChatGPT-User`). Check `OAI-SearchBot` for any citability claim; `GPTBot`
  status is evidence about training use only
- Blocking `ClaudeBot` prevents Anthropic model training but does NOT affect
  citability in Claude's own search features, which is governed by
  `Claude-SearchBot` (per Anthropic's crawler support article). Check
  `Claude-SearchBot` for any Claude-search citability claim; `ClaudeBot` status
  is evidence about training use only
- Blocking `Applebot-Extended` opts out of Apple Intelligence / generative-model
  training use but does NOT affect discoverability via Siri, Spotlight, or Safari,
  which follows `Applebot` (per Apple's support article); `Applebot-Extended` does
  not itself crawl
- ~3-5% of websites now use AI-specific robots.txt rules

**Example, selective AI crawler blocking:**
```
# Allow search indexing, block AI training crawlers
User-agent: GPTBot
Disallow: /

User-agent: Google-Extended
Disallow: /

User-agent: Bytespider
Disallow: /

# Allow all other crawlers (including Googlebot for search)
User-agent: *
Allow: /
```

**Recommendation:** Consider your AI visibility strategy before blocking. Being cited by AI systems drives brand awareness and referral traffic. Read `~/.claude/skills/seo-geo/SKILL.md` for the full AI crawler/fetcher taxonomy.

> **User-triggered fetchers ignore robots.txt by design.** Google now documents **Google-Agent** (Project Mariner, agentic browsing) plus **Google-NotebookLM** and **Google Messages** as *user-triggered* fetchers that **cannot be blocked via robots.txt**. Use server-side access controls instead. By contrast, `Google-Extended` and `Google-CloudVertexBot` obey robots.txt. Emerging: **Web Bot Auth** (RFC 9421) lets bots authenticate cryptographically via a `Signature-Agent` header + key directory at `agent.bot.goog` (used by Google-Agent); reverse-DNS verification remains the fallback.
