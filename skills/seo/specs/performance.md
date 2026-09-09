# Performance spec

Measure and evaluate Core Web Vitals and page load performance.

## Steps

1. Use PageSpeed Insights API if available: `pagespeed_check.py URL --json`.
2. If Google API credentials are configured, prefer CrUX field data over Lighthouse lab data for CWV assessment: run `pagespeed_check.py URL --json` and `crux_history.py URL --json`. Field data (28-day Chrome user average) is more representative than lab data (a single Lighthouse run). Use lab data as a fallback when CrUX returns 404 (insufficient traffic).
3. Run `render_page.py <URL> --mode auto --json` before HTML/source inspection so SPA content is visible when needed.
4. Optionally run `npx lighthouse URL --output json` for a lab diagnostic; always validate its result against CrUX field data.
5. Provide specific, actionable optimization recommendations, prioritized by expected impact.

Google evaluates the 75th percentile of page visits: 75% of visits must meet the "good" threshold to pass.

## Reference

### Current metrics (as of 2026)

| Metric | Good | Needs improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | ≤2.5s | 2.5s-4.0s | >4.0s |
| INP (Interaction to Next Paint) | ≤200ms | 200ms-500ms | >500ms |
| CLS (Cumulative Layout Shift) | ≤0.1 | 0.1-0.25 | >0.25 |

INP replaced FID on March 12, 2024. FID was removed from Chrome's field-data tools (CrUX API, PageSpeed Insights) on September 9, 2024 (Lighthouse is a lab tool that never reported FID). INP is the sole interactivity metric. Never reference FID.

### Common LCP issues

- Unoptimized hero images (compress, WebP/AVIF, preload).
- Render-blocking CSS/JS (defer, async, critical CSS).
- Slow server response, TTFB >200ms (edge CDN, caching).
- Third-party scripts blocking render.
- Web font loading delay.

### Common INP issues

- Long JavaScript tasks on the main thread (break into <50ms chunks).
- Heavy event handlers (debounce, requestAnimationFrame).
- Excessive DOM size (>1,500 elements).
- Third-party scripts hijacking the main thread.
- Synchronous operations blocking.

### Common CLS issues

- Images without width/height dimensions.
- Dynamically injected content.
- Web fonts causing FOIT/FOUT.
- Ads/embeds without reserved space.
- Late-loading elements.

### Performance tooling (2025-2026)

Lighthouse 13.4.1 (July 2026, latest stable): Lighthouse 13.0 (Oct 2025) migrated performance audits to insight-based audits aligned with the DevTools Performance panel and removed legacy audits (first-meaningful-paint, font-size, third-party-facades); the performance score is metric-based and was NOT re-weighted. 13.2.0-13.3.0 added and default-enabled a new Agentic Browsing category (Chrome 150+; fractional pass-ratio, not 0-100 — see `skills/seo-technical/references/agent-friendly-pages.md`). Version 13.4.1 enabled that category through the PSI API and requires Node.js 22.19 or newer for the CLI.

PageSpeed Insights / PSI API v5 run Lighthouse 13.x. The PWA category was removed in Lighthouse 12; do not expect or parse a `pwa` category. Lighthouse 13.4.1 enabled the agentic-browsing category through the PSI API.

CrUX Vis replaced the CrUX Dashboard (Looker Studio), shut down at the end of November 2025 (October 2025 was its final dataset). Use CrUX Vis (https://cruxvis.withgoogle.com) or the CrUX API directly.

LCP subparts (TTFB, resource load delay, resource load time, element render delay) are available in CrUX data since January 2025. See `skills/seo/references/cwv-thresholds.md` for details.

## Output

Report: performance score (0-100), Core Web Vitals status (pass/fail per metric), specific bottlenecks identified, and prioritized recommendations with expected impact.

- findings file: `findings/performance.md` — evidence, scores, bottlenecks, and recommendations
- `audit-data.json` category: Performance
