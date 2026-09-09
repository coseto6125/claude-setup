# DESIGN.md

`DESIGN.md` is Google Labs' open format for handing a visual identity to a
coding agent. Apache-2.0, spec at `github.com/google-labs-code/design.md`,
`docs/spec.md`. Cursor, Copilot, Claude Code and this skill can all read the
same file, which is the point of using it.

## When to write one

Write a `DESIGN.md` at the project root when the project outlives this session,
or when another tool or another agent will touch the same UI. Skip it for a
one-off page nobody returns to.

It does not replace `design-system/<slug>/MASTER.md`. Those two files answer
different questions:

| File | Answers | Read by |
|---|---|---|
| `MASTER.md` | Why this style, which patterns, what to avoid | This skill |
| `DESIGN.md` | What the exact token values are | Any agent or tool |

Generate `MASTER.md` first with `--design-system --persist`, then derive
`DESIGN.md` from it. Reversing that order loses the reasoning.

## File shape

YAML front matter carries the machine-readable tokens. The markdown body
carries the rationale. Tokens are normative; prose explains how to apply them.
Prose may name a color "Midnight Forest Green" as long as the token behind it
is `primary`.

```yaml
---
version: alpha
name: Daylight Prestige
colors:
  primary: "#1A1C1E"
  secondary: "#6C7278"
  tertiary: "#B8422E"
typography:
  h1:
    fontFamily: Public Sans
    fontSize: 48px
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: -0.02em
---
```

## Front-matter schema

```yaml
version: <string>       # optional, current: "alpha"
name: <string>
description: <string>   # optional
omitted: <string[] | {section, reason}[]>   # optional
colors:      { <token-name>: <Color> }
typography:  { <token-name>: <Typography> }
rounded:     { <scale-level>: <Dimension> }
spacing:     { <scale-level>: <Dimension | number> }
components:  { <component-name>: { <token-name>: <string | reference> } }
```

- **Color**: any valid CSS color string. Hex, named, `rgb()`, `hsl()`, `hwb()`,
  `oklch()`, `oklab()`, `lch()`, `lab()`, `color-mix()`. All values convert to
  sRGB for WCAG checking. Default to `#RRGGBB` for tooling breadth.
- **Typography**: `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`,
  `letterSpacing`, `fontFeature`, `fontVariation`. A unitless `lineHeight` is a
  multiplier and is the recommended form.
- **Dimension**: a string with a `px`, `em`, or `rem` suffix.
- **Scale level**: any descriptive key. Common: `xs`, `sm`, `md`, `lg`, `xl`,
  `full`.
- **Token reference**: `{colors.primary-60}`. It must resolve to a primitive,
  except inside `components`, where a composite such as `{typography.label-md}`
  is allowed.
- **omitted**: list the sections the project deliberately has none of, so a
  linter stops warning. Give a reason where one exists.

Recommended non-normative names: colors `primary`, `secondary`, `tertiary`,
`neutral`, `surface`, `on-surface`, `error`; typography `headline-display`,
`headline-lg`, `headline-md`, `body-lg`, `body-md`, `body-sm`, `label-lg`,
`label-md`, `label-sm`; rounded `none`, `sm`, `md`, `lg`, `xl`, `full`.

## Body sections

All sections are `##`. Present sections must appear in this order. An optional
`#` title is not parsed as a section.

1. Overview (also "Brand & Style")
2. Colors
3. Typography
4. Layout (also "Layout & Spacing")
5. Elevation & Depth (also "Elevation")
6. Shapes
7. Components
8. Do's and Don'ts

Component variants live under related keys, and the consumer reads all of them:

```yaml
components:
  button-primary:
    backgroundColor: "{colors.primary-60}"
    textColor: "{colors.primary-20}"
    rounded: "{rounded.md}"
    padding: 12px
  button-primary-hover:
    backgroundColor: "{colors.primary-70}"
```

Component property tokens: `backgroundColor`, `textColor`, `typography`,
`rounded`, `padding`, `size`, `height`, `width`.

"Do's and Don'ts" is a flat list of guardrails, one rule per line:

```markdown
## Do's and Don'ts

- Do use the primary color only for the single most important action per screen
- Don't mix rounded and sharp corners in the same view
- Do maintain WCAG AA contrast ratios (4.5:1 for normal text)
- Don't use more than two font weights on a single screen
```

## Reading a DESIGN.md someone else wrote

| Situation | What to do |
|---|---|
| Unknown section heading | Keep it, do not error |
| Unknown color token name | Accept if the value is a valid color |
| Unknown typography token name | Accept as typography |
| Unknown spacing value | Accept, store as a string if it is not a Dimension |
| Unknown component property | Accept, warn |
| Duplicate section heading | Reject the file, this is an error |

When a project already holds a `DESIGN.md`, its tokens outrank anything
`--design-system` proposes. Read it before running the search, and treat a
generated palette as a suggestion the file has already overruled.

## Mapping MASTER.md to DESIGN.md

| MASTER.md section | DESIGN.md target |
|---|---|
| Style, Pattern | `## Overview` prose |
| Colors | `colors:` front matter, `## Colors` prose |
| Typography | `typography:` front matter, `## Typography` prose |
| Key Effects | `## Elevation & Depth`, `## Shapes` |
| Motion | not in the spec; keep it in `MASTER.md` |
| Anti-patterns | `## Do's and Don'ts` |

The spec carries no motion section. Do not invent one; a consumer will ignore it.

Verify every color pair against `local/wcag-checklist.md` before writing the
file. A token committed to the repo gets reused by every later session, so an
inaccessible pair propagates.
