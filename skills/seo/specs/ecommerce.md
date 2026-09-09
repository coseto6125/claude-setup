# E-commerce spec

Validate product schema, analyze marketplace visibility, identify pricing gaps, and recommend product page optimizations. Run when an e-commerce site is detected during an audit.

<!-- Original concept: Matej Marjanovic -- E-commerce DataForSEO Expansion (Pro Hub Challenge) -->

## Steps

1. Detect e-commerce signals: product schema, price elements, add-to-cart buttons, shopping cart, product grids, Shopify/WooCommerce/Magento markers.
2. Analyze product pages with `render_page.py <URL> --mode auto` and `parse_html.py <URL>`. E-commerce sites overwhelmingly inject product schema client-side (Shopify, Magento PWA, headless commerce on Next.js): prefer `--mode always` for product page audits and compare `raw_content` vs `content` to confirm whether the JSON-LD is server-rendered.
3. Validate Product schema against Google's required and recommended fields.
4. If DataForSEO credentials are available, fetch marketplace data via `dataforseo_merchant.py`, subject to the cost guardrails below.

## Cost guardrails

Before any DataForSEO Merchant API call, run `dataforseo_costs.py check <endpoint>`. Proceed only if `"status": "approved"`. If `"needs_approval"`, surface the cost to the parent orchestrator. If `"blocked"`, skip marketplace analysis and note the limitation.

After each API call, log the cost: `dataforseo_costs.py log <endpoint> <actual_cost>`.

## Reference

### Analysis priorities

1. Schema completeness — missing Product fields mean missing rich results.
2. Image optimization — product images need alt text, WebP, >= 800px.
3. Pricing competitiveness — compare against marketplace medians.
4. Content uniqueness — flag manufacturer copy-paste descriptions.
5. Internal linking — breadcrumbs, related products, category links.

### Reporting conventions

- Tables for comparative data (pricing, seller landscape).
- Scores as XX/100 (schema, images, content, overall).
- Priority: Critical > High > Medium > Low.
- Note the data source: "DataForSEO Merchant (live)" or "On-page analysis (static)".
- Include actionable recommendations with expected impact.

### Error handling

- DataForSEO unavailable: complete the on-page analysis without marketplace data.
- URL is not a product page: detect page type and adjust analysis scope.
- Schema parsing fails: analyze raw HTML for product signals.
- Report all errors clearly with suggested next steps.

## Output

- findings file: `findings/ecommerce.md` — product schema, marketplace, image, pricing, content, and internal-link findings
- `audit-data.json` category: E-commerce SEO
