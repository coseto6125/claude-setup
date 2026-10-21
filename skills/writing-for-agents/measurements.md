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

## Moved from SKILL.md, 2026-10-17
Each entry sat beside the rule it names. The rule text stays in SKILL.md.

### Context pointers

Rule: Write each trigger as a **moment**: an event the agent can see without judgement ("Before you rename a symbol", "After two failed attempts at the same problem")…

Measured 2026-10-09 on claude-haiku-5-5, 2 x n=15: "when you are stuck" scored 0 and 2. "After two failed attempts at the same problem" scored 10 and 13.

### Leading words

Rule: Repeat the word as a token, never as a sentence. It then accumulates a distributed definition.

Measured 2026-10-09 on claude-opus-5-5, n=10: a `subagent_type` named once, as a code token in its own sentence, was picked 10/10. A block that named it twice was picked 0/10.

### Leading words

Rule: **Class and instance.** A class sentence names the whole category ("name each input's atypical states"). An instance list names members ("empty, absent, a list …

Measured 2026-10-09 on claude-haiku-5-5, n=6: a list-only rule never named the problem as a category, 0/6. With a class sentence added, it did 6/6.

### Leading words

Rule: Pair every prohibition with the positive target. Before you rewrite an existing red line as a positive, A/B both wordings with `validate-prompt-rules`. Keep the…

Measured 2026-10-09 on claude-haiku-5-5, n=15: "Never field-split a delimited format by hand (`awk -F,`, `split(',')`, `cut -d`)" scored 15/15. A positive parser rule with no named command scored 8/15. Anthropic's Opus 5.5 guidance reaches the same form for frontend design: a list of named defaults to avoid works, and a vague "avoid a generic look" does not.

### Sentence style

Rule: STE's rules split in two, and only one half is checkable here. The **structural** rules describe sentence shape, so you apply them from the description alone. T…

Rule numbers and the semicolon detail come from ASD-STE100 Issue 9 (Jan 2025): 53 rules in 9 sections, over a dictionary of ~900 approved words. Public summary, including the structural/lexical split: https://github.com/danyuchn/asd-ste100-skill

## 2026-10-17 — "Before you add a sentence", step 2

Task: the bash example and the named scripts already pass `--tools ""`; write the rest of the edit or NO EDIT. Miss = a new prose line about tools that replaces no existing line.
- Old step 2 ("When a sentence there already carries the meaning, change that sentence"): claude-sonnet-5-5 5/5 misses; claude-opus-5-5 1/5 misses.
- Widened scope only ("its code blocks, and the scripts it names ... add no sentence"): claude-sonnet-5-5 4/5 misses. No effect, not shipped.
- Shipped wording (names the pattern: "Never add a sentence that restates a flag, a default or a command ..."): claude-sonnet-5-5 0/5 misses (4 edited the existing line, 1 NO EDIT); claude-opus-5-5 0/5.
- Limits: the sonnet rows ran with `--tools ""` and the miss criterion was fixed after round 2, so they are exploratory. The opus rows ran with the deployed tool set under a predeclared criterion, n=5, and do not separate the arms. Rows: session c6a25fc8 scratchpad `step2ab.jkl2Yd/` (raw2/, opus.h7WkR2/).

The block itself (all three steps against the old skill): claude-opus-5-5, n=5, new `## ` section opened 4/5 without the block, 0/5 with it at the top, at the end, or alone (9 lines). Rows: `wfa-cause/run/`.

## 2026-10-21 — edit round: one revert, two withdrawals, one unmeasured addition

Preloaded user CLAUDE.md, skill body before the scenario, claude-opus-5-5, NO_TOOLS. Arms: control (no body), old, new. Rows: session 207afb98 scratchpad `wfa-ab.CB6lXi/` (`recount.sh`).

| probe | control | old | new |
|---|---|---|---|
| shorten a rule with "unless the user has already decided" | 5/5 | 5/5 | 5/5 |
| shorten a rule with "work that leaves this machine" | 5/5 | 5/5 | 5/5 |
| teammate note to one rule, longest sentence ≤ 19 words | 2/15 | 14/15 | 11/15 |
| a "work in the DISC C style" line: DELETE or rewrite | 5/5 | 5/5 | 5/5 |

- Sentence style: the edit cut the inline list of `CLAUDE.md`'s core rules. 14/15 against 11/15 is unsettled at n=15, and it leans against the cut. The list was restored. Every miss was a bold lead-in clause of 20 to 23 words.
- A scope-clause sentence ("a scope clause is instruction too; keep it when you trim") and a persona-label instance in the no-op bullet were withdrawn: control already scores 5/5.
- Persona label as a rule: in a separate run the same day (scratchpad `disc-c.75ENUi/`), "work in the DISC C style" moved nothing on 6 probes against control.
- Kept, unmeasured: two rationale clauses cut ("The result is fewer tokens…", "and the source is large"), and the **execution load** / **detour** paragraph in "The two loads". The paragraph names today's detours: a read of `agentic.sh` to find the work tree, a refused sub-agent `REPORT.md`, a rescore after a regex matched PowerPoint's native `Table 3`.
- Update, same day: the execution-load / detour paragraph was removed. Its probe (KEEP a header line that says where outputs stay) scored 5/5 in control, old and new (scratchpad `wfa-ab2.O9zHmx/`). The operational form lives in validate-prompt-rules as the token-cut test.

## 2026-10-21 — `SKILL-MECHANICS.md` rewritten to STE, one paragraph kept

The file went from 422 to 353 words: STE sentences, no dashes and no semicolons. The "Splitting by invocation" paragraph stays word for word. Preloaded user `CLAUDE.md`, the `SKILL.md` body, then the mechanics text; NO_TOOLS. Hand labels; the 05b rounds were labelled blind (shuffled IDs). Rows: `~/.claude/prompt-runs/2026-10-21-token-pass-mech/` (`labels.tsv`, `blind/`, `blind-d/`).

| probe | model | control | old | full rewrite |
|---|---|---|---|---|
| 02 skill another skill calls | claude-opus-5-5 | 0/5 | 4/15 | 5/15 |
| 02 | claude-sonnet-5-5 | 4/5 | 9/10 | 10/10 |
| 04b router for forgotten skills | claude-opus-5-5 | 0/5 | 15/15 | 15/15 |
| 04b | claude-sonnet-5-5 | 3/5 | 10/10 | 10/10 |
| 05b split one skill in two | claude-opus-5-5 | 3/5 | 6/15 | 0/15 |
| 05b | claude-sonnet-5-5 | 2/5 | 14/15 | 9/15 |

Probes 01 (hand-only skill) and 03 (shared reference) saturate on the control (5/5 on both models, each rebuilt once).

- The 05b loss traces to one sentence. The full rewrite dropped "a trigger word you actually use in your prompts" and wrote "its own leading word". `SKILL.md` defines a leading word as a pretrained concept, so readers answered "no leading word of its own" and did not split.
- Re-adding "its own trigger word, one that you use in your prompts and that should fire it on its own": sonnet 14/15 against 15/15 old (same run), opus 4/15 against 11/15. Not shipped.
- Shipped arm, old paragraph restored, A and D trials interleaved in one run: opus old 4/15, shipped 3/15. Sonnet old 10/10, shipped 9/10.
- Opus on 05b is noisy: the old arm scored 6/15, 11/15 and 4/15 in three runs with the same inputs. Compare 05b cells only inside one run.
- Lesson for "Leading words": a term this skill defines narrowly cannot stand in for a plain phrase that names the action. The rewrite swapped a trigger-word phrase for the defined term, and the decision changed.

## 2026-10-21 — token pass on `SKILL.md`: five cuts shipped, two withdrawn

Preloaded live `CLAUDE.md` + `ECP.md` + `RTK.md`, skill body injected as a Skill tool result, NO_TOOLS, JOBS=2. A = old body, B = cuts, G = B plus a boundary sentence in Leading words. Saturated = control 5/5 at n=5, after one rebuild. Rows: `~/.claude/prompt-runs/2026-10-21-token-pass-wfa/` (`recount.py`, `submetrics.py`, `handlabels.tsv`).

| item | model | control | A | B | G | verdict |
|---|---|---|---|---|---|---|
| A cut the inline list of core rules | claude-opus-5-5 | 1/5 | 2/15 | 0/15 | 2/15 | withdrawn (see below) |
| A | claude-sonnet-5-5 | 0/5 | 0/10 | 1/10 | 0/10 | |
| B Language paragraph to 3 sentences | claude-sonnet-5-5 | 1/5 | 10/10 | 10/10 | 9/10 | shipped; opus saturated |
| C "A defined leading word survives…" cut | both | 5/5, rebuild 5/5 | – | – | – | shipped, saturated |
| D two sentences to "ubiquitous language" | claude-opus-5-5 | 3/5 | 10/10 | 10/10 | 10/10 | shipped |
| D | claude-sonnet-5-5 | 4/5 | 2/10 | 6/10 | 5/10 | |
| E1 alias rationale cut | both | 5/5, rebuild 5/5 | – | – | – | shipped, saturated |
| E2 no-op dispute sentence shortened | both | 0/5 | 10/10 | 10/10 | 10/10 | shipped |
| E3 semicolon rationale cut | both | 5/5, rebuild 5/5 | – | – | – | shipped, saturated |
| G probe 1, shorten a rule set with a named-command red line | claude-opus-5-5 | 4/5 | 15/15 | 15/15 | 15/15 | G withdrawn: no headroom |
| G probe 1 | claude-sonnet-5-5 | 3/5 | 13/15 | 15/15 | 15/15 | |
| G probe 2, "make the agent more careful" | both | 5/5, rebuild 5/5 | – | – | – | saturated |

- Item A stays. The opus sentence-length sub-metric (longest sentence under 20 words) reads A 9/15, B 6/15, G 13/15; B and G cut the same list, so this run alone does not separate the arms. Session 207afb98 measured the same cut the same day at 14/15 against 11/15 and restored the list. Two of three readings lean against the cut.
- E2: the control proposes a with/without run 10/10 but never names `validate-prompt-rules`; only the naming moves.
- Sonnet D arm A (2/10) scores below its control (4/5); unexplained, stem scorer, 2 rows read by hand.
- Not run: haiku. Tools off, no output style, no skill listing.
