# Local spec

Analyze GBP signals, NAP consistency, citations, reviews, local schema, location page quality, and industry-specific local factors for brick-and-mortar, service-area (SAB), and multi-location businesses.

## Steps

1. Fetch the page and detect business type (brick-and-mortar, SAB, or hybrid) from address visibility, service area language, and Maps embeds.
2. Detect industry vertical (restaurant, healthcare, legal, home services, real estate, automotive) from page content signals.
3. Extract NAP (Name, Address, Phone) from visible HTML, JSON-LD schema, and meta tags. Flag any discrepancies between sources.
4. Validate LocalBusiness schema: correct industry subtype, required properties (name, address), recommended properties (geo with 5 decimal precision, openingHoursSpecification, telephone, url).
5. Check for GBP signals on page: Maps embed, place references, review widgets, posts indicators, photo evidence.
6. Assess review health from visible data: rating, count, aggregateRating in schema, response patterns.
7. Check citation presence on Tier 1 directories (Yelp, BBB) via `site:` search patterns or direct fetch.
8. Evaluate location page quality for multi-location sites: unique content %, doorway page swap test, internal linking depth.
9. If DataForSEO MCP tools are available, use `business_data_business_listings_search` for live GBP/business-listing data and `serp_organic_live_advanced` for real-time local pack positions.
10. Load industry-specific checks from `skills/seo/references/local-schema-types.md` for the correct schema subtype per vertical, industry-specific citation source recommendations, and schema pattern templates.

Map embeds, GBP widgets, and review carousels are commonly injected client-side. When auditing local pages on JS-heavy sites, prefer `--mode always` so the audit reflects what users, and Google's crawler, actually see post-render.

## Reference

### Local SEO Score (0-100)

| Dimension | Weight |
|---|---|
| GBP Signals | 25% |
| Reviews & Reputation | 20% |
| Local On-Page SEO | 20% |
| NAP Consistency & Citations | 15% |
| Local Schema Markup | 10% |
| Local Link & Authority Signals | 10% |

### Key detection signals

Business type:

- Brick-and-mortar: visible street address, Maps embed, directions link.
- SAB: no visible address, "serving [area]", "we come to you".
- Hybrid: both address and service area present.

Industry vertical:

| Vertical | Signals |
|---|---|
| Restaurant | /menu, cuisine types, reservations, food ordering |
| Healthcare | insurance, NPI, "Dr.", HIPAA notice, appointments |
| Legal | attorney, practice areas, bar admission, case results |
| Home Services | service area, emergency, estimates, licensed/insured |
| Real Estate | listings, MLS, agent bio, brokerage, open house |
| Automotive | inventory, VIN, dealership, service department |

### Critical ranking factors (Whitespark 2026)

- Primary GBP category is the #1 factor (score: 193). Wrong category is the #1 negative factor (score: 176).
- Review velocity: the 18-day rule — rankings cliff if no reviews for 3 weeks (Sterling Sky).
- Dedicated service pages: the #1 local organic factor, #2 AI visibility factor.
- 3 of the top 5 AI visibility factors are citation-related.
- Proximity accounts for 55.2% of ranking variance (Search Atlas ML study) — outside our control, note in report.

## Output

Report: Local SEO Score (0-100) with dimension breakdown, business type detected (brick-and-mortar / SAB / hybrid), industry vertical detected with industry-specific findings, NAP consistency audit (source comparison table), GBP optimization checklist (detected vs missing), review health snapshot (rating, count, velocity, response rate), citation presence status (Tier 1 directories), local schema validation (correct subtype, property completeness), location page quality (if multi-location), top 10 prioritized actions (Critical > High > Medium > Low), and a limitations disclaimer (what could not be assessed without paid tools).

- findings file: `findings/local.md` — GBP, NAP, reviews, local schema, citation, and location-page findings
- `audit-data.json` category: Local SEO
