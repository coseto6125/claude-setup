# Image-gen spec

Audit existing OG/social preview images, identify missing or low-quality images, and produce an image generation plan with prompts for key pages. Never auto-generate images (cost control).

## Steps

1. Check that nanobanana-mcp tools are available before including generation recommendations.
2. Analyze the site's existing image strategy for SEO impact.
3. Output a structured generation plan only.

## Reference

### Analysis scope

For each audited page, evaluate:

- OG image presence: does `og:image` meta tag exist, and is it valid?
- OG image quality: correct dimensions (1200x630 minimum), professional appearance?
- Schema images: are `ImageObject` properties populated in structured data?
- Alt text quality: descriptive, keyword-rich, not stuffed?
- Image format: modern formats (WebP, AVIF) vs legacy (PNG, JPEG)?
- Image file size: under 200KB for hero images, under 100KB for thumbnails?

### Recommendations

- Prioritize pages by traffic volume (highest traffic fixed first).
- Note estimated cost for the full generation plan.
- Suggest batch generation for efficiency.
- Recommend a WebP conversion pipeline for all generated assets.

### Error handling

- nanobanana-mcp not available: still audit existing images, but note that generation requires the banana extension.
- Report errors clearly with actionable next steps.
- Note the data source as "Image Audit (static analysis)" to distinguish from live checks.

## Output

Format, matching existing claude-seo patterns:

### Image Audit Summary

| Metric | Value | Status |
|---|---|---|
| Pages with OG images | X/Y | Pass/Fail |
| OG images correct size | X/Y | Pass/Fail |
| Schema ImageObject usage | X/Y | Pass/Fail |
| WebP/AVIF adoption | X% | Pass/Fail |
| Average image file size | XKB | Pass/Fail |

### Image Generation Plan

| Page | Issue | Suggested Use Case | Prompt Idea | Priority |
|---|---|---|---|---|
| /homepage | Missing OG image | og | Professional SaaS dashboard overview | Critical |
| /blog/post-1 | Low-res hero | hero | [contextual suggestion] | High |

Priority levels: Critical > High > Medium > Low.

- findings file: `findings/image-gen.md`
- audit-data.json category: not specified in the source agent
