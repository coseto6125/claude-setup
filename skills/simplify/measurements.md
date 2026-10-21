# Measurements behind `simplify/SKILL.md`

## Moved from SKILL.md, 2026-10-17
Each entry sat beside the rule it names. The rule text stays in SKILL.md.

### Phase 3: Tier the dispatch

Rule: Launch exactly one, and only at Tier 1 or Tier 2: its recall falls as the diff grows, and parallel calls hang. A `TRUNCATED` line at the end of its report means…

Measured 2026-09-11 on the earlier `nemotron-3-super-120b-a12b:free`, not yet on ultra: 4 of 5 planted defects located per trial, every failure_scenario invented, a lock held across a network call missed in every read; 4 of 4 on a 52-line diff, 2.3 of 4 on a 2034-line one.
