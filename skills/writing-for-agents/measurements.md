# Measurements behind the SKILL.md rules

Evidence for SKILL.md sections, one dated section each. Read when you doubt a rule. SKILL.md carries the rule and the shortest evidence.

## 2026-10-09 — re-run on the current models (CLI 2.1.295)

Every older blockquote was re-run on claude-haiku-5-5 and claude-opus-5-5 from its recovered original probe. Raw rows: session c7da8904 scratchpad `rv-wfa1.KV13IS/` (triggers, class and instance; `recount.py` recounts them read-only) and `rv-wfa2.iD0B5Y/` (leading word, negation).

### Context pointers: moment against category trigger

Five rules from 2026-08-13, 2 x n=15, claude-haiku-5-5. A = category trigger, B = moment trigger.

| rule | control | A | B |
|---|---|---|---|
| codex | 0, 0 | 0, 2 | 10, 13 |
| match | 4, 1 | 15, 15 | 15, 15 |
| delegate | 12, 14 | 15, 14 | 15, 15 |
| regression test | 0, 0 | 15, 15 | 14, 15 |
| worktree | 0, 0 | 15, 15 | 15, 15 |

Only the codex rule still separates. On claude-haiku-4-5 (2026-08-13) all five category triggers scored 0 to 7 of 15. The delegate control and one B miss are classifier misses.

### Leading words: one mention against two

`lite-scan` pick, n=10 per arm, the 2026-08-14 Dispatch-section arms.

| arm | mentions | claude-opus-5 (08-14) | claude-opus-5-5 | claude-haiku-5-5 |
|---|---|---|---|---|
| standalone sentence, code token | 1 | 0/10 | 10/10 | 0/10 |
| standalone sentence, plain | 1 | 0/10 | 5/10 | 0/10 |
| two parentheticals | 2 | 10/10 | 4/10 | 0/10 |
| shipped version | 2 | 9/10 | 9/10 | 0/10 |
| original full block | 2 | 8/10 | 0/10 | 0/10 |
| control | 0 | 0/10 | 0/10 | 0/10 |

The arms carry 08-14 model names (Haiku 4.5, Sonnet 5, Opus 5), which opus repeated. "One mention is not enough" was removed from SKILL.md on this result.

### Class and instance

- Edge-list plant, n=5, 2026-09-11 preload: claude-opus-5-5 control 0/5, class-only 5/5, class+list 5/5. claude-haiku-5-5 control 0/5, class-only 4/5, class+list 4/5 (claude-haiku-4-5 had class-only 0/5).
- List-only probe, claude-haiku-5-5, n=6: no arm refused (the original control and list-only arm refused 6/6). Only the class sentence named the problem as a borrowed category, 6/6 against 0/6.
- eli5 audience tables, claude-haiku-5-5, n=15: control 0/15, four tables 10/15, class sentence alone 7/15. The gap of 3 is unsettled (claude-haiku-4-5 had 15/15 against 2/15).
- claude-sonnet-5-5, edge-list plant, n=10: control 0/10, class-only 10/10, class+list 8/10 (10/10 read by hand). The class sentence carries the effect; the list adds nothing.
- Open: the SKILL.md advice to add the instance list for a haiku or sonnet reader has no measured support on the current models. Kept pending an n=15 run.

### Negation: the named-command red line

CSV probe, today's `CLAUDE.md` as the document, leave-one-out. claude-opus-5-5 n=12, claude-haiku-5-5 n=15 for the in-file arms.

| arm | claude-opus-5-5 | claude-haiku-5-5 |
|---|---|---|
| control, no `CLAUDE.md` | 0/12 | 0/12 |
| file without either rule | 12/12 | 1/15 |
| file as shipped (named commands) | 12/12 | 15/15 |
| file with the positive rule instead | 12/12 | 8/15 |
| named-command sentence alone | 12/12 | 12/12 |
| positive sentence alone | 12/12 | 10/12 |

claude-sonnet-5-5, n=15: control 0/15, file without either rule 1/15, shipped 15/15, positive rule 15/15. The rule is needed on sonnet, and the positive form holds there. It leaks on claude-haiku-5-5, so the named-command form stays. On claude-opus-5 (2026-08-21) the positive rule scored 0/12. Three rows that negate `awk` count as hits. Rows that offer `awk` as an alternative count as misses.

## 2026-10-09 — `audit.py` rule 6 and `spans` (unmeasured)

Rule 6 flags a `> Measured` blockquote that names a model family without a full ID. It found 0 lines in the tree on its first run, because the day's re-run had already relabelled them. `spans` lists code spans an old copy has and the new file lacks. Origin: a trim of peer-agent dropped the only `check --ack <delivery_id>`, and claude-opus-5-5 then invented a command 7/7 (memory `evidence-sentence-can-carry-the-only-anchor`). The "Finishing a change" bullet that calls `spans` is a report-format rule and shipped unmeasured. Tests: `test_audit.py`, 45 cases after the review round.
