# Data Screens

Rules for an Operate surface: a dashboard, an admin screen, an analytics view, any app screen the visitor uses to get a job done. Where a rule here conflicts with `references/quick-reference.md` or a CSV row, this file wins.

Sources: Leonxlnx/taste-skill v2.1.5 `references/app-screens.md` (MIT, a study of 23 production screens), pbakaus/impeccable v4.8.0 `reference/mode-operate.md`. Merged 2026-11-01.

## The product leads, the style serves

- The visitor should know where everything is before they notice the style.
- The style lends four things only: type, palette, density, and one signature move. It never supplies the layout, the navigation model or the controls.
- Use standard controls: buttons, tabs, inputs, selects, filters, tables with sortable headers.
- Never dress the screen as the subject's own interface: a terminal function-key bar, an instrument bezel, ledger paper standing in for a table.
- A grey screen with one accent colour is the category default, not restraint. Put colour on data, state and selection.

## Name the screen's one question

1. Write the screen's one question in one line: "Did today's sales come in?", "Which deploy broke?".
2. Make the largest block the one that answers it. The largest figure answers it too.
3. Name the one finding: the fact in today's data that most needs attention. Put it under the title or under the headline figure, next to the action it drives.
4. List every other block as the answer to a next question. Delete a block with no question.
5. Take the structure from the product's own things, not from the stock order (KPI row, big chart, two small charts, table).

Then check three things:

- At 1440×900, every block the brief names shows its header and its first rows or figure. Cap a long list at 4-6 rows with "View all".
- The most frequent job is one click away, with its control where the answer shows.
- The event that matters carries one line of evidence beside its number: "peaked at 3.9% after the 23:28 deploy, reverted".

## Data that adds up

Write the sample data as a JSON or JS file that the screen renders from. Use believable names, dates in order, and a unit on every figure.

- Compute every total from the rows. Never type a total in separately.
- Write the figures that must agree as assertions in the data file (`console.assert(sold - cancelled === rsvps)`), and read the console.
- A fact shown in two places is one variable in the data file.
- Sum the rounded values the screen displays. A delta is the difference of the two values on screen.
- Every relative figure names its baseline in the same phrase: "+5 on the usual Monday", not a bare "+5".
- Colour says good or bad, not up or down. A zero change is grey.
- Print a real zero as `0`. Print a missing value as a grey dash. An empty section keeps its frame.
- Small numbers stay small. A week-old account shows 1, 6 or 9 of something, not a round vanity total.

## Charts

- One series per chart, three at most. One hue per subject across the whole screen, four hues at most.
- No legend for a single series. Label the mark instead.
- 3-5 faint gridlines, no y-axis line, round ticks with the top tick above the maximum.
- Bars start at zero.
- Draw a 2px straight line with no markers. A smoothed curve invents values between the points.
- Never rotate an x-axis label. Thin the labels instead.
- Annotate a spike of about 3× or more with its cause. Draw a forecast dashed.
- An empty chart draws its zero line and one sentence in its frame.

## Tables

- Right-align numbers in tabular figures, with fixed decimals per metric and units in grey.
- Use rules and alignment: 12px grey headers, no zebra rows, no uppercase tracked header band.
- Truncate a description column, never the identity column.
- Give a chip `flex: none; white-space: nowrap`.
- Below about 640px, turn each row into a two-line item. Keep every field.
- Check that `font-variant-numeric: tabular-nums` changes the digit widths in the chosen face. Some faces ignore it.

## Tells of generated dashboards

| Tell | Replace it with |
|---|---|
| A dark or tinted sidebar with a coloured active pill and a left bar | The sidebar on the page ground, with a neutral grey active pill |
| "Welcome back, Alex" with a waving hand | A noun title at 24px, weight 600 |
| Four KPI cards, each with an icon in a tinted circle | One container split by hairlines, label over value, no icons |
| A green "+12.5%" pill on every KPI | A delta in words with its window, grey for zero |
| A sparkline on every KPI | None. The trend gets its own chart |
| KPI values at 36-48px, bold, in the brand colour | 24-30px at weight 400-600, in ink |
| A gradient area chart with a spline and a dot on every point | A 2px straight line, no fill, no markers |
| A fat donut with slice labels and a total in the hole | A thin ring, with the legend as a table of values |
| Cards with a large radius, a border and a soft shadow | A border or a tone step, no shadow |
| Every row with a checkbox, an avatar, a status chip and a kebab | One status mark, and one action where it is needed |
| Saturated status chips with white text | Pale tints with dark text of the same hue |
| The accent on every button, tab and link | Near-black for the one primary button, or none |
| Export, Share and a date picker clustered by the title | Real actions only, and a freshness stamp |
| An equal four-up grid whatever the data | A column count chosen by the item count |
| A coloured icon per list category | One grey icon set, with colour on the numbers |

Removing every tell and adding nothing leaves a tidy template. Fill the space with the product's own data at its real size.

## Settings and states

- One save model per settings view: save on change, or one Save button. Never both.
- Design the empty, zero, loading and error state of every block.
- Status green `#16a34a` is 3.3:1 on white. Use it for marks only. For green text, use `#247b50` (5.22:1).
- A disabled control keeps opacity 0.5 or higher (about 3.4:1 for slate-900 ink on white; 0.38 gives 2.4:1). A tooltip or a helper line next to it says why it is disabled.

## Density

High density moves row height, padding and type size together. `--density 8` in `search.py` rewrites the spacing scale only, so set the row height and type size yourself.
