# Schema markup spec

Detect, validate, and generate Schema.org structured data in JSON-LD.

## Steps

1. Fetch the page. On an SPA prefer `--mode always`: many sites inject JSON-LD client-side via
   React Helmet, Next/Head or vue-meta, so raw HTML looks empty while the rendered DOM carries
   the full graph. Compare `raw_content` against `content` to tell whether schema is
   server-rendered.
2. Detect every existing block: JSON-LD, Microdata (`itemscope`, `itemprop`), RDFa (`typeof`,
   `property`). Use the render JSON's `structured_data` summary for routine detection; when full
   blocks are needed for validation, pass `--json-ld-output <path>` and read that artifact.
3. Validate against Google's supported rich result types.
4. Check required and recommended properties.
5. Identify missing schema opportunities.
6. Generate correct JSON-LD for what you recommend adding.

## Reference

### Never recommend, deprecated

- **HowTo**: rich results removed September 2023.
- **SpecialAnnouncement**: deprecated 31 July 2025.
- **CourseInfo, EstimatedSalary, LearningVideo**: retired June 2025.

### FAQPage, no rich results

Google retired FAQ rich results for all sites on 7 May 2026, superseding the August 2023
gov/health restriction. There is no SERP feature any more.

- Existing FAQPage: report at Info severity, not Critical. No Google SERP benefit, and any
  AI/GEO benefit is unconfirmed.
- Adding new FAQPage: no Google SERP benefit; only worth it if the user accepts that the AI/GEO
  benefit is unconfirmed.
- Genuine user Q&A pages: use **QAPage**, not FAQPage.

### Always prefer

- JSON-LD over Microdata or RDFa.
- `https://schema.org` as `@context`, not `http`.
- Absolute URLs.
- ISO 8601 dates.

### Recommend freely

Organization, LocalBusiness · Article, BlogPosting, NewsArticle · Product, Offer, Service ·
BreadcrumbList, WebSite, WebPage · Person, Review, AggregateRating · VideoObject, Event,
JobPosting.

For video types (VideoObject, BroadcastEvent, Clip, SeekToAction), read `schema/templates.json`
in the skill root.

### Validation checklist

Per block: `@context` is `https://schema.org`; `@type` is valid and not deprecated; required
properties present; property values match expected types; no placeholder text such as
`[Business Name]`; URLs absolute; dates ISO 8601.

## Output

- findings file: `findings/schema.md`
- `audit-data.json` category: Schema / Structured Data

Report: detection results (what exists), validation results (pass/fail per block), missing
opportunities, and generated JSON-LD ready to paste.
