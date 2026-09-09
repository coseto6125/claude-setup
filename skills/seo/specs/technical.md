# Technical SEO spec

Crawlability, indexability, security, URL structure, mobile, rendering.

## Steps

1. Fetch the page or pages and analyse the HTML source.
2. Check sitemap availability with
   `"$HOME/.claude/skills/seo/bin/claude-seo" run sitemap_discovery.py <URL> --json`.
   A robots.txt declaration is not a passing result unless the helper validates it; continue
   through the common fallbacks when a declaration is stale.
3. Analyse meta tags, canonical tags, and security headers.
4. Evaluate URL structure and redirect chains.
5. Assess mobile-friendliness from the HTML and CSS.
6. Flag potential Core Web Vitals issues from source inspection.
7. Check JavaScript rendering requirements (CSR vs SSR).

## Reference

### Core Web Vitals thresholds, 2026

| Metric | Good | Needs improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | ≤2.5s | 2.5s to 4s | >4s |
| INP (Interaction to Next Paint) | ≤200ms | 200ms to 500ms | >500ms |
| CLS (Cumulative Layout Shift) | ≤0.1 | 0.1 to 0.25 | >0.25 |

INP replaced FID on 12 March 2024. FID left Chrome's field-data tools (CrUX API, PageSpeed
Insights) on 9 September 2024; Lighthouse is a lab tool and never reported FID. INP is the sole
interactivity metric. Never mention FID in any output.

### Categories to cover

1. Crawlability: robots.txt, sitemaps, noindex
2. Indexability: canonicals, duplicates, thin content
3. Security: HTTPS, headers
4. URL structure: clean URLs, redirects
5. Mobile: viewport, touch targets
6. Core Web Vitals: potential LCP, INP, CLS issues
7. Structured data: detection and validation
8. JavaScript rendering: CSR vs SSR
9. IndexNow protocol: Bing, Yandex, Naver

### Cross-spec handoffs

- Detailed hreflang validation belongs to the `seo-hreflang` sub-skill; hand it off rather than
  improvising.
- AI crawler tokens and robots.txt guidance live in the `seo-technical` skill's AI Crawler
  Management section.

## Output

- findings file: `findings/technical.md`
- `audit-data.json` category: Technical SEO

Report: pass/fail per category, a technical score out of 100, prioritised issues, and specific
recommendations with implementation detail.
