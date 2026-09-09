---
name: seo-lite
description: SEO pass over a site's pages, covering on-page elements and Schema.org JSON-LD.
disable-model-invocation: true
license: MIT
---

# SEO pass

Read the pages from disk. Fetch a URL only for a page with no source in this repo.

The page list is the work, and the repo is the source of truth for it. A static site: `find . -name '*.html'`, minus assets and stylesheets. A generated site: find the build output directory or the route table, and check the built HTML, never the template. Say which list you used before you report against it.

## Route

| You want | Load |
|---|---|
| On-page elements: title, meta, headings, links, images, Open Graph | `references/page.md` |
| Schema.org JSON-LD: detect, validate, generate | `references/schema.md` |
| Which schema types Google still supports | `references/schema-types.md` and `references/deprecated-types.md` |
| A JSON-LD block to start from | `references/schema-templates.json` |
| A full pass | Page first, then schema |

## Steps

1. List the pages. Read each one.
2. Check each page against the loaded reference. Record one finding per defect.
3. Report the findings. Change nothing until the user picks what to fix.

Every page in the list is accounted for before you report. A page with no findings is reported as clean, never omitted.

## What a finding needs

A finding names the file, the line, the defect, and the fix. A finding without a line number is an impression. Verify it against the file, or drop it.

Rank findings by what a search engine acts on. A missing or duplicate `<title>` outranks a phrasing preference.

## Facts come from the site

Business name, contact details, prices, dates and credentials come from the site's own files, or from the user. A tag with no source stays a marked placeholder for the user to fill.

A confident wrong fact in structured data is worse than an absent tag, because Google acts on it.
