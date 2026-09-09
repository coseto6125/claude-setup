# Backlinks spec

Analyse a domain's backlink profile using free and paid sources, merged with confidence-weighted scoring.

## Steps

1. Check credentials: `"$HOME/.claude/skills/seo/bin/claude-seo" run backlinks_auth.py --check --json`.
2. Determine tier: 0 = Common Crawl + verify, 1 = + Moz, 2 = + Bing, 3 = + DataForSEO.
3. Run every source available at the detected tier for the target domain.
4. Merge results with confidence weighting.
5. Run the automated validator, then the manual checks, before returning results.

## Tier workflow

### Tier 0 (always available, no config)

- Common Crawl domain metrics: `commoncrawl_graph.py <domain> --json` — PageRank, PageRank rank, harmonic centrality, harmonic centrality rank, crawl/ranking presence.
- If known backlinks are provided, verify them: `verify_backlinks.py --target <url> --links <file> --json`.
- Report domain-level metrics at **confidence: 0.50**.
- Fewer than 4 scoring factors have data at Tier 0: report **INSUFFICIENT DATA**, not a numeric score. Never produce a misleading numeric score when most factors lack a data source.

### Tier 1 (+ Moz API)

- All Tier 0 checks.
- Moz URL metrics: `moz_api.py metrics <url> --json` — DA, PA, Spam Score, link counts, referring domains.
- Moz referring domains: `moz_api.py domains <url> --json`.
- Moz anchor text: `moz_api.py anchors <url> --json`.
- Moz top pages: `moz_api.py pages <domain> --json`.
- Rate limit: 1 request per 10 seconds, built into the script. Plan calls carefully.
- Report metrics at **confidence: 0.85**.

### Tier 2 (+ Bing Webmaster)

- All Tier 1 checks.
- Bing inbound links: `bing_webmaster.py links <url> --json`.
- Comparison between two properties on the same Bing account: `bing_webmaster.py compare <url1> <url2> --json`.
- Report Bing data at **confidence: 0.70**.
- Never use Bing Webmaster data for an arbitrary competitor. Use Moz, DataForSEO, or Common Crawl when the second property is not registered.

### Tier 3 (+ DataForSEO, premium)

- If DataForSEO MCP tools are available, use them for highest-fidelity data, at **confidence: 1.00**.
- Combine with free-source data for cross-validation.
- When DataForSEO and Moz disagree, trust DataForSEO but note the discrepancy.

## Reference

### Confidence-weighted scoring

Apply source confidence when calculating the Backlink Health Score (0-100):

| Factor | Weight | Sources (by preference) |
|---|---|---|
| Referring domain count | 20% | DataForSEO > Moz (CC does not provide this directly) |
| Domain quality distribution | 20% | DataForSEO > Moz DA distribution |
| Anchor text naturalness | 15% | DataForSEO > Moz anchors > Bing anchors |
| Toxic link ratio | 20% | DataForSEO > Moz spam score > verify crawler |
| Link velocity trend | 10% | DataForSEO only (free sources lack this) |
| Follow/nofollow ratio | 5% | DataForSEO > Bing link details |
| Geographic relevance | 10% | DataForSEO > Bing country data |

If a factor has no data source, redistribute its weight proportionally across the remaining factors. Note which factors were scored and which were skipped.

### Cross-skill delegation

- Toxic link patterns beyond basic Moz Spam Score, and anchor text industry benchmarks: load `skills/seo/references/backlink-quality.md`.
- Do not duplicate content analysis; recommend `/seo content <url>` for E-E-A-T.
- Do not duplicate technical analysis; recommend `/seo technical <url>` for crawlability.

### Fetching pages

Backlink verification (`/seo backlinks verify`) primarily reads outbound `<a>` tags, reliably present in raw HTML. Use `--mode never` for speed on bulk verification jobs.

### Pre-delivery review (mandatory)

Step 1, automated: save all collected data to a JSON file and run
`validate_backlink_report.py --report report_data.json --json`. It checks schema claims, JS false negatives, H1 accuracy, reciprocal links, CC interpretation, and health-score sufficiency. Fix errors before proceeding if status is FAIL.

Step 2, manual:
1. Every claim has a source label, e.g. "Parsed (0.95)", "CC (0.50)", "Verify (0.95)".
2. No inference is presented as fact: if you did not directly observe it, do not state it as certain.
3. Confirm platform detection (wp-content, Shopify CDN, etc.) from actual HTML signals, not a guess.
4. Outbound vs inbound consistency: the homepage outbound count matches what you actually observed.

Fix the report before returning it if any check fails.

### Error handling

- Moz rate-limits mid-analysis: return partial data, note `rate_limited: true`.
- Common Crawl download times out: skip CC metrics, note the timeout.
- No source returns data: report "No backlink data available. Run `/seo backlinks setup`."
- All free sources fail: suggest the DataForSEO extension, `./extensions/dataforseo/install.sh`.
- Never fail silently; always report what succeeded and what failed.

### Reporting conventions

- Tables for metrics with pass/warn/fail ratings.
- Scores as XX/100 with source confidence noted.
- Note the data source for every metric, e.g. "Moz API (confidence: 0.85)" or "Common Crawl (domain-level, confidence: 0.50)".
- Include source freshness from API responses when available; otherwise label freshness as approximate (Common Crawl web graphs are quarterly; source: https://commoncrawl.org/web-graphs).

## Output

- findings file: `findings/backlinks.md` — backlink source coverage, authority, anchor text, toxicity, and verification findings
- `audit-data.json` category: Backlink Profile
