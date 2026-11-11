# ui-ux-pro-max measurements

## impeccable v4.8.0 + taste-skill v2.1.5 merge, claude-sonnet-5-5, 2026-11-01

Old = the skill before the merge, new = after (adds `local/data-screens.md`, the SKILL.md conflict table, Step 1 surface and argument, Step 5 render loop). Tools ON (`harness7/agentic.sh`, arm text through `--append-system-prompt`, paths rewritten per arm, no leak found). Probe: a single-file HTML dashboard for a coffee-bean shop owner. n=5 per arm, no skill-free arm. Rows: session 9a45f906 scratchpad `ab.XS6DSU/c17.8bpAVm` (ephemeral).

| field (pre-registered) | old | new |
|---|---|---|
| KPI icon in a tinted circle | 0/5 | 0/5 |
| sparkline on a KPI | 0/5 | 0/5 |
| legend on a single-series chart | 0/5 | 0/5 |
| "Welcome back" greeting | 0/5 | 0/5 |
| smoothed line | 0/5 | 0/5 |
| totals computed from rows | 5/5 | 5/5 |
| read the routed `local/` file | 0/5 (design-patterns-library) | 1/5 (data-screens) |

Exploratory, added after reading the files: a "Good morning, <name>" greeting 5/5 → 1/5, any chart legend 4/5 → 0/5. Four of the five new runs never read `data-screens.md`, so these come from the SKILL.md body (the conflict table) or chance, not isolated.

- The dashboard tells in `data-screens.md`: no effect detectable, the probe floors them for this model. Kept: they cost nothing until the file is read.
- The Step 0 "Then read" pointer: weak in both versions (0/5 and 1/5). Fixed by the next section.
- Not run: claude-opus-5-5 (the usual main-session reader), the Step 5 render loop, the gesture rows.

## Step 0 pointer as a moment trigger, claude-sonnet-5-5, 2026-11-01

cur = "Read the row that matches, load what it names, then continue through the Build Workflow. This file is the only always-loaded layer; everything it points at loads on demand." with the column "Then read". sharp = "Pick the row that matches. After its search, and before you write the first line of code, Read every file in its `Read before you build` column." with the column renamed to match. Same harness and isolation as above, n=5 per cell. Rows: `ab.XS6DSU/c18.pamEf1` (P1), `ab.XS6DSU/c18.PVq1Zt` (P2), ephemeral.

| probe | routed files | cur: read all | sharp: read all | mean cost cur → sharp |
|---|---|---|---|---|
| P1 dashboard | data-screens, cognitive-load | 0/5 | 5/5 | $0.37 → $0.51 |
| P2 landing page | anti-patterns, web-delivery-checklist | 0/5 | 4/5 | $0.26 → $0.31 |

Secondary, P1: "Good morning, <name>" greeting 2/5 → 0/5, any legend 3/5 → 1/5. P2: em-dashes in 4/5 → 0/5 runs, hero headline over 42 characters 2/5 → 0/5.

- Effect on the read. [shipped] The extra cost is the routed files being read.
- The secondary drops are what the routed rules ask for (`anti-patterns.md` bans the em-dash and caps the headline), so the merged material works once it is read.
