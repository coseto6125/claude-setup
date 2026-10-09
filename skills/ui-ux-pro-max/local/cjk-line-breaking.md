# Chinese line breaking

Rules for where Chinese text wraps on a web page, by layout. They follow W3C *Requirements for Chinese Text Layout*
(clreq). Write the user-facing copy in the page's language; the rules stay here.

## The principle per layout

| Layout | How it breaks | CSS and markup |
|---|---|---|
| Heading, 1 to 3 lines, large type | At a phrase boundary only. Lines close to equal. No lone 1 or 2 characters on the last line. No 4/4/4 block of equal short lines | `word-break: keep-all; text-wrap: balance;` and a `<wbr>` between phrases in the copy. Give a heading the width its longest phrase needs, even into the column gap |
| Short lead or caption, 1 to 3 lines | At a clause boundary (after a comma) when the copy has two clauses. Inside a clause, normal Chinese wrapping with full lines | Wrap the second clause in a `display: block` span. Bind units only (below). On a phone, where the lead runs past 3 lines, set the span to `display: inline`: the lead then wraps as prose |
| Prose paragraph | Normal Chinese wrapping: any character may end a line. Every line runs full. A new line starts only where the copy says so (for example after each 。 when the client asks) | `text-align: justify; text-justify: inter-character; line-break: strict; text-wrap: pretty;` one `display: block` span per sentence when sentences start new lines |
| Narrow column or phone | The same rules as above at the narrow width. A quoted name or a date range moves whole to the next line | `display: inline-block` on the name, or a forced break before it. Shrink one name line to the line width with `font-size: min(1em, calc((100vw - pad) / name-width-in-em))` |
| Mixed Chinese and Latin | A space between Chinese and Latin text. A product name, number + unit, or Latin phrase never splits | `U+00A0` between Latin and Chinese inside a unit (`外接 SSD`, `500 美元`). `U+2060` between Chinese characters of a unit (`禮⁠物⁠卡`). `U+2060` before `——` so the dash never starts a line |

## Rules from clreq

- Justify prose to both edges. The last line of a paragraph stays ragged (6.2.1).
- Absorb extra space in punctuation first, then between characters (6.2.2).
- Keep ，。、」） off the line start and 「（ off the line end (6.1.1). `line-break: strict` does this.
- Leave at least two characters on the last line of a paragraph (7.1.2).
- Use a line height of 1.6 to 1.75 for body text.

## Failed approaches

Each of these shipped and was rejected as ugly. Use the method in the table instead.

| Approach | What went wrong |
|---|---|
| `<wbr>` between phrases, or between words, in a prose paragraph with `keep-all` | Lines of 9 to 19 characters side by side. The paragraph reads like a poem |
| `white-space: nowrap` on a sentence's last word (4 or more characters) in a justified paragraph | The line before loses that many characters, and justification spreads its characters visibly |
| `text-wrap: pretty` with `text-align: start` | Pretty ends a line early at a comma, and the ragged edge shows it |
| `text-align: justify` with long unbreakable runs | The short lines spread their characters apart |
| A heading's `<wbr>` points that let every phrase take its own line | A 4/4/4 square block |

## Verification

Print every line of each Chinese block at 375, 390, 1024, 1366 and 1920 px, in Chinese and English:

```js
// returns the text of each rendered line of the element
(sel) => { const el = document.querySelector(sel), r = document.createRange(), out = []; let cur = '', top = null;
  const walk = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
  for (let n; (n = walk.nextNode());) for (let i = 0; i < n.length; i++) { r.setStart(n, i); r.setEnd(n, i + 1);
    const b = r.getClientRects()[0]; if (!b) continue;
    if (top !== null && b.top - top > 5) { out.push(cur); cur = ''; } if (top === null || b.top - top > 5) top = b.top; cur += n.data[i]; }
  out.push(cur); return out; }
```

The check passes when every line list shows: no split unit, no punctuation at a line start, no last line of one character,
no line in a justified block that is three or more characters shorter than its neighbours. Then look at a screenshot,
because character spacing only shows there.

## Fonts

- Before you call a Chinese face missing, read the page's `<link>` tags and `@font-face` rules, and the font requests in a network log. A Google Fonts `family=Noto+Sans+TC` link already serves the face in unicode-range slices, so the page needs no self-hosted copy.
- With no web font, a system fallback renders 微軟正黑體 on Windows and 蘋方 on a Mac, so the client sees a different page. Load one then.
- Subset a self-hosted face to the page's Chinese copy. Subset it again after every copy change, or one line mixes two faces.
- Use Noto Sans TC 400 or 500 as the default body face (the `--domain typography` "Chinese Traditional" pairing). Match its weight to the Latin body weight.
- A local catalog of Traditional Chinese OFL faces lives at `~/enor_agi/misc-site-generator-docs/site-generator-v2/generator/fonts/catalog.json`, with `subset.mjs` beside it.

Sources: [clreq](https://www.w3.org/TR/clreq/), [justfont 避頭尾](https://blog.justfont.com/2023/10/punctuationrules/),
[MDN text-autospace](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/text-autospace),
[BudouX](https://github.com/google/budoux) (phrase segmentation for headings).
