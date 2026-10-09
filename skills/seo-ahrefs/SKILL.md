---
name: seo-ahrefs
description: Ahrefs API analyst (extension). Reads referring domains, backlinks, organic keywords, and content explorer data via the tested @ahrefs/mcp@0.0.11 server. Pairs with seo-backlinks for multi-source confidence weighting.
metadata:
  version: "2.3.1"
compatibility: "Tested with @ahrefs/mcp@0.0.11 (the user adds the Ahrefs MCP server to their Claude Code config)."
disable-model-invocation: true
---

# seo-ahrefs

Live Ahrefs data via the tested `@ahrefs/mcp@0.0.11` server.

## Prerequisites

- The Ahrefs MCP tools must be present in this session. If they are absent, ask the user to add the Ahrefs MCP server to their Claude Code config.
- An Ahrefs API token (https://ahrefs.com/api).
- Node 18+ on `$PATH` for the MCP server.

Before your first Ahrefs tool call, confirm that the first prerequisite above holds.

## Routing

| Command | Action |
|---|---|
| `/seo ahrefs metrics <url>` | Domain / URL rating, referring domain count, organic traffic estimate |
| `/seo ahrefs backlinks <url>` | Top referring domains, anchor distribution, follow/nofollow ratio |
| `/seo ahrefs organic <url>` | Organic keywords, ranking distribution, traffic by country |
| `/seo ahrefs content <topic>` | Content Explorer top results, social shares, referring domains |

## Output conventions

- Cite the data source on every metric: "Ahrefs (live, confidence 1.00)".
- When Ahrefs and Moz disagree on the same metric, trust Ahrefs and note the discrepancy in the report.
- Toxic link assessment: combine Ahrefs backlink quality signals with the existing seo-backlinks Common Crawl + verify crawler signals.

## Cross-skill delegation

- For multi-source confidence weighting across Moz + Bing + Common Crawl, hand back to `seo-backlinks`. It has no Ahrefs source, so report Ahrefs figures beside its weighted score, not inside it.
- For SERP-feature analysis where Ahrefs and DataForSEO overlap, prefer DataForSEO for live SERP data.

## Cost guardrails

Ahrefs API usage is metered per unit. Before running a batch (>= 50 URLs):

1. Estimate units from the Ahrefs plan's published per-row pricing. No script in `seo/scripts` covers Ahrefs.
2. Surface the estimate to the orchestrator.
3. Log actual cost after each call.

This is the same workflow the seo-dataforseo skill uses.
