# Drift spec

Detect regressions in on-page SEO elements by comparing current page state against stored baselines. Only run when a drift baseline exists for the URL.

<!-- Original concept: Dan Colta, SEO Drift Monitor (Pro Hub Challenge) -->

## Steps

1. **Baseline**: capture current SEO state (title, meta, canonical, robots, headings, schema, OG tags, CWV, status code) with `"$HOME/.claude/skills/seo/bin/claude-seo" run drift_baseline.py <url>`. Store with SHA-256 content hashes in SQLite.
2. **Compare**: fetch current state with `drift_compare.py <url>`, run 17 comparison rules across 3 severity levels (CRITICAL, WARNING, INFO). Report all triggered rules with old/new values.
3. **History**: query SQLite for all baselines and comparisons for a URL with `drift_history.py <url>`. Show a timeline.
4. Generate an HTML report on request with `drift_report.py <file> --output report.html`.

All page fetching goes through these scripts, which use the bundled `fetch_page.py` module internally to validate URLs against private/loopback IP ranges. Never use curl, wget, or raw HTTP requests.

## Reference

### Severity classification

- **CRITICAL**: supported rich-result or merchant/entity-critical schema removed, canonical changed/removed, noindex added, H1/title removed, H1 changed >50%, status code became 4xx/5xx.
- **WARNING**: title/description changed, CWV regressed >20%, performance score dropped 10+ points, OG tags removed, schema modified.
- **INFO**: new schema added, H2 structure changed, content hash changed.

### Cross-skill delegation

When drift is detected, recommend the appropriate skill:

| Drift type | Recommend |
|---|---|
| Schema issues | `/seo schema <url>` |
| Performance regression | `/seo technical <url>` or `/seo google psi <url>` |
| Content/title changes | `/seo page <url>` or `/seo content <url>` |
| Canonical/indexability | `/seo technical <url>` |

## Output

For comparisons, present:

1. Summary line: number of CRITICAL / WARNING / INFO findings.
2. Table of all triggered rules with severity, old value, new value, and action.
3. Cross-skill recommendations for any CRITICAL or WARNING findings.
4. Offer HTML report generation for sharing with stakeholders.

- findings file: `findings/drift.md` — baseline availability, triggered rules, old/new values, and regression findings
- `audit-data.json` category: SEO Drift
