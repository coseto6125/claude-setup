# Sitemap spec

Discover, validate, and generate XML sitemaps, and gate programmatic page sprawl.

## Steps

1. Discover candidates with
   `"$HOME/.claude/skills/seo/bin/claude-seo" run sitemap_discovery.py <url> --json`.
   Use only validated `found` entries, and keep declared failures as findings.
2. Validate XML format and URL status codes.
3. Check for deprecated tags: `priority` and `changefreq`, both ignored by Google.
4. Verify `lastmod` accuracy: valid W3C Datetime, and it reflects the last significant change,
   not a boilerplate edit.
5. Compare crawled pages against sitemap coverage.
6. Enforce the per-file limit: ≤50,000 URLs and ≤50MB uncompressed, whichever comes first. For
   `news:` sitemaps the cap is 1,000 URLs.
7. Apply the location page quality gates below.

## Reference

### Validation checks

| Check | Severity | Action |
|---|---|---|
| Invalid XML | Critical | Fix syntax |
| >50k URLs | Critical | Split with an index |
| Non-200 URLs | High | Remove or fix |
| Noindexed URLs | High | Remove from sitemap |
| Redirected URLs | Medium | Update to the final URL |
| All identical `lastmod` | Low | Use real dates |
| `priority` / `changefreq` | Info | Can remove |

### Location page quality gates

- **Warning** at 30 or more location pages: require 60% or more unique content per page.
- **Hard stop** at 50 or more location pages: require explicit user justification.

Google's doorway page algorithm penalises programmatic location pages that carry thin or
duplicate content.

### Safe at scale

Integration pages with real setup docs · glossary pages with 200+ word definitions · product
pages with unique specs and reviews.

### Penalty risk

Location pages with only the city swapped · "Best [tool] for [industry]" pages with no real
value · AI-generated mass content.

### Sitemap format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/page</loc>
    <lastmod>2026-02-07</lastmod>
  </url>
</urlset>
```

## Output

- findings file: `findings/sitemap.md`
- `audit-data.json` category: Sitemap

Report: pass/fail per validation check, missing pages (crawled but absent from the sitemap),
extra pages (in the sitemap but 404 or redirected), quality gate warnings where they apply, and
generated sitemap XML when creating a new one.
