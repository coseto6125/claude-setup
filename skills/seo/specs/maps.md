# Maps spec

Maps intelligence: geo-grid rank tracking, GBP profile auditing, review intelligence, cross-platform NAP verification, and competitor radius mapping via DataForSEO and free APIs.

## Steps

1. Detect capability tier: check if DataForSEO MCP tools are available (try `business_data_business_listings_search`). Available = Tier 1; not available = Tier 0 (free APIs only).
2. Identify the target business: extract name, location, and category from the URL or provided context.
3. Geocode the business address using Nominatim (free) or DataForSEO (Tier 1).
4. Run the analyses available at the detected tier (see below).
5. Score the business on the Maps Health Score rubric.
6. Generate a structured report with prioritized recommendations.

## Tier capabilities

### Tier 0 (free)

- Competitor discovery via Overpass API (radius query by business category).
- Structured POI search via Geoapify (if an API key is available).
- Address geocoding via Nominatim: 1 req/sec, include a User-Agent header.
- Static GBP completeness checklist (manual assessment from visible data).
- LocalBusiness schema generation from collected data.
- Cross-platform NAP guidance (recommend claiming Google, Bing, Apple).

### Tier 1 (+ DataForSEO)

- Geo-grid rank tracking via Maps SERP API with `location_coordinate`.
- Live GBP profile audit via My Business Info API.
- Review intelligence via Reviews API (velocity, sentiment, distribution).
- GBP post activity audit via My Business Updates API.
- Q&A gap analysis via Questions and Answers API.
- Cross-platform reviews (Tripadvisor, Trustpilot).
- Business listings search for competitor discovery.

## Reference

### Maps Health Score (0-100)

| Dimension | Weight | Data source |
|---|---|---|
| Geo-Grid Visibility / SoLV | 25% | DataForSEO Maps SERP (Tier 1 only; skip and redistribute if Tier 0) |
| GBP Profile Completeness | 20% | DataForSEO My Business Info (Tier 1) or manual checklist (Tier 0) |
| Review Health | 20% | DataForSEO Reviews (Tier 1) or visible review signals (Tier 0) |
| Cross-Platform Presence | 15% | WebFetch checks for Bing, Apple, OSM listings |
| Competitor Position | 10% | Overpass/DataForSEO competitor count and relative rating |
| Schema & AI Readiness | 10% | Schema detection + AI citation signal check |

Tier 0 weight redistribution: when geo-grid is unavailable, redistribute its 25% across GBP (+10%), Review Health (+10%), Cross-Platform (+5%).

### Reference files

Load on demand:

| File | Content |
|---|---|
| `skills/seo/references/maps-api-endpoints.md` | DataForSEO endpoint details and costs |
| `skills/seo/references/maps-free-apis.md` | Overpass, Geoapify, Nominatim query templates |
| `skills/seo/references/maps-geo-grid.md` | Grid algorithm, SoLV calculation, heatmap rendering |
| `skills/seo/references/maps-gbp-checklist.md` | 25-field GBP audit checklist with industry weights |
| `skills/seo/references/local-seo-signals.md` | Ranking factors, review benchmarks (shared with `local`) |
| `skills/seo/references/local-schema-types.md` | LocalBusiness subtypes by industry (shared with `local`) |

### Cross-skill delegation

- Do not duplicate `local`'s on-page analysis; recommend `/seo local <url>` for website-level checks.
- Do not duplicate `geo`'s AI visibility analysis; recommend `/seo geo <url>` for full GEO audit.
- Do not duplicate `schema`'s validation; recommend `/seo schema <url>` for schema fixes.

## Output

Report: Maps Health Score (0-100) with dimension breakdown, capability tier detected (Tier 0 or Tier 1), geo-grid heatmap with SoLV percentage (if Tier 1), GBP profile completeness score with field-by-field breakdown, review health snapshot (rating, count, velocity, response rate, cross-platform), competitor landscape (count in radius, top competitors by rating/reviews), cross-platform presence status (Google, Bing, Apple, OSM), generated LocalBusiness JSON-LD (if schema missing), top 10 prioritized actions (Critical > High > Medium > Low), cost report (DataForSEO credits consumed, if applicable), and a limitations disclaimer (what could not be assessed at current tier).

- findings file: `findings/maps.md` — Maps visibility, GBP completeness, review, competitor, and cross-platform NAP findings
- `audit-data.json` category: Maps Visibility
