# DataForSEO spec

Fetch live SERP, keyword, backlink, on-page, business-listing and AI-visibility data through the
DataForSEO MCP tools.

## Steps

1. Check that the DataForSEO MCP tools are available before attempting any call.
2. Pick the most efficient tool combination for the data requested.
3. Apply the default parameters `location_code=2840` (US) and `language_code=en` unless the
   caller specifies otherwise.
4. Format output to match claude-seo conventions: tables, priority levels, scores.
5. If the MCP tools are unavailable, **fail closed**. Never inspect credential or configuration
   stores, and never bypass MCP with curl, raw HTTP, or another client.

## Reference

### Credit discipline

- Prefer bulk endpoints over repeated single calls.
- Do not re-fetch data already retrieved in the same session.
- Warn before an expensive operation: a full backlink crawl, a large keyword list.
- Default to `limit=100` on list endpoints unless the user needs more.

### Error handling

- A tool error is reported to the user as-is, not swallowed.
- Invalid credentials: suggest running the extension installer again.
- A module that is not enabled: name which module is needed.

### Output conventions

Tables for comparative data · scores as `XX/100` · priority Critical > High > Medium > Low ·
label the source `DataForSEO (live)` so it is distinguishable from static HTML analysis ·
include timestamps for time-sensitive data such as SERP positions and backlink counts.

## Output

- findings file: `findings/dataforseo.md`
- `audit-data.json` category: not specified in the source agent

This dimension enriches other dimensions rather than standing alone; when a caller asks for
enrichment only, return the data and skip the findings file.
