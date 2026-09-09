# Google spec

Fetch Google API SEO data: CWV field data via CrUX, indexation status via GSC, and organic traffic via GA4.

## Steps

1. Check credentials: `"$HOME/.claude/skills/seo/bin/claude-seo" run google_auth.py --check --json`.
2. Determine tier: 0 = API key, 1 = + service account, 2 = + GA4.
3. Execute the tier-appropriate analysis below.
4. After completing data collection at any tier, offer to generate a PDF report (see Report generation).

## Tier workflow

### Tier 0 (API key only)

- PSI + CrUX on homepage: `pagespeed_check.py <url> --json`.
- CrUX History for origin: `crux_history.py <origin> --origin --json`.
- Report CWV field data with traffic-light ratings.

### Tier 1 (+ service account)

- All Tier 0 checks.
- GSC top queries/pages, 28 days: `gsc_query.py --property <prop> --json`. Use only totals with `totals_complete: true` as site-wide totals; query rows can omit anonymized low-volume traffic and are not safe to sum as totals.
- URL Inspection on homepage + key pages: `gsc_inspect.py <url> --json`.
- GSC sitemap status: `gsc_query.py sitemaps --property <prop> --json`.

### Tier 2 (full)

- All Tier 1 checks.
- GA4 organic traffic, 28 days: `ga4_report.py --property <id> --json`.
- Top organic landing pages: `ga4_report.py --property <id> --report top-pages --json`.

## Report generation (mandatory)

The report uses the enterprise template: white cover, navy accents, Times New Roman, charts at 85% width, Google logo on title page. No `page-break-inside: avoid` (it causes white gaps).

```bash
"$HOME/.claude/skills/seo/bin/claude-seo" run google_report.py --type full --data data.json --domain DOMAIN --format pdf --json
```

Report types: `cwv-audit`, `gsc-performance`, `indexation`, `full`. Before presenting, verify `"review": {"status": "PASS"}` in the JSON output.

## Reference

### Core Web Vitals thresholds

| Metric | Good | Needs improvement | Poor |
|---|---|---|---|
| LCP | ≤2,500ms | 2,500-4,000ms | >4,000ms |
| INP | ≤200ms | 200-500ms | >500ms |
| CLS | ≤0.1 | 0.1-0.25 | >0.25 |

INP replaced FID on March 12, 2024. Never reference FID.

### Reporting conventions

- Tables for metrics with traffic-light ratings.
- Scores as XX/100.
- Priority: Critical > High > Medium > Low.
- Note the data source as "Google API (field data)" to distinguish from static analysis.
- Include data freshness notes: CrUX is a 28-day rolling window, GSC has a 2-3 day lag, GA4 has a 1 day lag.

### Error handling

- Credentials missing: report which tier is available and what can still be checked.
- CrUX returns 404: note insufficient Chrome traffic, fall back to PSI lab data.
- GSC returns 403: report that the configured service identity lacks access, redact any identifier, and instruct the user on adding permissions.
- Never fail silently; always report what succeeded and what failed.

## Output

- findings file: `findings/google.md` — PSI, CrUX, GSC, URL Inspection, GA4, and credential-tier findings
- `audit-data.json` category: Google SEO Data
- Generated PDF/HTML/XLSX reports under `output_dir/`, produced with `google_report.py --output-dir "$output_dir"`
