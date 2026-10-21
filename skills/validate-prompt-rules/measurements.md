# Measurements behind the SKILL.md rules

Evidence for SKILL.md sections, one dated section each. Read when you doubt a rule; SKILL.md carries the rule.

## 2026-08-15, from memory measured-rules-have-no-slack (harness part)

The delegate re-check rule rows are in `maintainer-notes.md`, `## Dispatch, "What a delegate returns"`. The harness findings from the same day:

- 隔離 probe 是空 cwd、無工具、單回合、極短 context。真正的失誤發生在跑了兩百多次工具呼叫之後的長 session。opus 在乾淨單回合 25/25 做對,不代表它在 context 很長時做得到,而當天的實例是它沒做到。量不到效果在這裡等於「這個工具測不到我要測的東西」,不等於「規則沒用」。這一類要靠機制(本機已有的 `guard-main-edit.sh` / `guard-push-simplify.sh`),不是靠加字。
- `ab.sh` now saves every reply (`AB_RAW_DIR`, one file per trial, `umask 077`). It paid for itself the same round: the first classifier version judged one deletion as a check, because the closing reason sentence repeated a noun from the situation and that noun was in the verify list. Reading the rows caught it; the count was recomputed offline with the fix and no extra call.

## 2026-08-13, from memory classifier-artifacts-outrank-data

Lessons the memory stated, with their status on 2026-10-22:

- Prefer a ratio of canonical term to drift variants over a distinct-form count. [not shipped: one run, a form metric]

About 1200 isolated probes while compressing `~/.claude/CLAUDE.md`. Three headline findings came from a clean-looking number and reversed on reading the rows; the user caught two before the wrong thing shipped.

1. A form metric decided a content question. Median longest-sentence length scored the merged rule "equivalent". Content scoring (does the output keep three distinct escalation targets, does it hold one term per concept) told a different story.
2. A regex missed a format, not a behaviour. `escalate to X` failed on `escalate to the lead **with** a summary` and on `[bracketed placeholder]`, and scored a perfect row as 0 targets. The fixed classifier cut the reported effect from "collapses 3 targets into 2" to 73% against 89%.
3. A coarse count invented a difference. Counting distinct term forms per row scored a form that appeared once the same as the dominant form, and produced a fake "compression degrades term discipline". The ratio of canonical term to drift variants showed the arms were identical. A ratio is better than a distinct-form count, because a count treats a one-off and a dominant form alike.

## 2026-08-08, from memory probe-design-failure-modes

Lessons the memory stated, with their status on 2026-10-22:

- Record an item as 'not settleable with this instrument', not 'unmeasured'. [covered: validate-prompt-rules/SKILL.md, saturated and unsettled readings]
- Fix a losing caveat by restructuring, not by more caveat; a document can be worse than no document. [not shipped: one run]
- Check the criterion is not in the cut-off half of a truncated output; the finding must be the model's own, not supplied by the prompt. [covered in part: validate-prompt-rules/SKILL.md, "Check that the control can fail"; the truncation half is not shipped]

Three rounds (2026-08-07/08), about 10 probe sets on haiku (claude-haiku-4-5 (inferred from the date; the memory says only the family)); six-plus scenarios were invalid or misleading on first design. The scenario triad and the saturation-reading fix shipped in SKILL.md (item-1 restructure measured at n=30). Rows not yet recorded here:

- The two shipped scenario conditions (the control can fail, the control can answer) can conflict. When the thing under test is a wording whose text is the answer, no middle ground exists. Record such an item as "not settleable with this instrument", not "unmeasured", so nobody spends trials there again.
- ASK shape is a first-class confound. A forced-single-slot ASK turns reordering into fake displacement; a multi-slot ASK ("conclusion and next action") finds secondary considerations and inflated a 1/5 to a ship-ready 5/5. Strict single-slot ASK for ship decisions; multi-slot only to explore.
- n=5 is a pilot. A predeclared, clean-classifier n=5 run pointed opposite to two concordant n=15 replications (1/5 against 12/15 and 13/15, about a 1-in-280 outlier). Any 1-2 trial margin at n=5 is below the measured noise floor. The 2026-08 rule "ship only on two concordant n>=15 runs" was replaced on 2026-09-23 by stepped n=5, 7, 10, 15 (see the 2026-09-23 section).
- Row-reading overturned a regex four times: recited format words scored as applied verdicts, and refusals matched negative-wording patterns. Recitation is not application: a coverage or format classifier must check the verdict attached to actual content.
- A run where nothing executed is output-identical to a clean null; `validate.sh` now exits 2 on zero probes.
- 2026-08-29, one completion criterion, three probes in a row. (1) Output truncated at 300 characters (`cut -c1-300`): the control looked like it under-reported, a false signal; the full output named everything 7/7. (2) Untruncated, but the scenario said "privacy.html and terms.html turned up nothing", which hands the model the answer: control 7/7, saturated. (3) Five real `.html` files built in a temp directory, the model ran `find` and read them itself: the arms separated. When the behaviour under test is "report everything you found", the finding must be the model's own, not supplied by the prompt. Check that the criterion is not in the cut-off half of a truncated output.
- The same rule can work for the weak reader only. That completion criterion was control 0/3, rule 3/3 on haiku, and 2/2 in both arms on opus (saturated). It stays for the weakest reader. Another rewrite of the same session was flat on haiku and opus (44 trials) and was deleted.
- A document can be worse than no document. At n=30, a confident primary clause ("no difference = grounds to nominate deletion") produced 60% wrong-deletion verdicts, where bare control produced 0%. Prepended or appended caveats never beat the primary clause (27-33%). The fix that worked was structural: reorder so the gating classification happens first (83%). Fix a losing caveat by restructuring, not by more caveat.
- Reading-based wording instincts went 0-for-3+ against measurement while structural findings all survived. One reviewer's round-1 record: three refuted, one confirmed, one converted, one self-reversed, plus one ship-ready result overturned by its own stricter re-run.
- Open, post-hoc or ceiling-limited: position equivalence is established only at high compliance, unverified at the margin. One n=5 post-hoc observation: a co-located instruction made haiku fabricate rule content where the control correctly refused.
- 2026-09-08, haiku (claude-haiku-4-5 (inferred from the date; the memory says only the family)): one identical arm (same wording, scenario and model) scored 9/15, 4/15 and 7/15 in three n=15 runs. The per-arm total across runs is the only number worth quoting: arm A 20/45 against arm E 14/30, tied. The first run alone read as a clean 9-against-3 win that the second run erased. The 9/15, 4/15, 7/15 spread is also in "Older-model evidence" below.

## 2026-09-11 — two controls, "go and look", classifier check

Two questions need two controls. Bare control answers "is this rule anything at all"; the deployed question is "does this line add to what the reader already loads", and that control preloads `~/.claude/CLAUDE.md` (+`@` siblings) into `CLAUDE_CONFIG_DIR` plus the project `CLAUDE.md` in the cwd, with any always-loaded skill description appended (skills do not load in `-p`).

Measured 2026-09-11 on a PHP package, opus, rows read:

- 26 one-line design rules (架構定位 … 變更範圍) as real-code no-tools probes: 25/26 control 5/5, the 26th saturated on content. Four "headroom" cells were regex false negatives (`…BatchTest`, static `Http::timeout(`, `forgetInstance(PageRegistry`, a `(bool)` cast copied from the excerpt).
- A "go and look" plant (second `columnGap` site outside the reported one) run agentically on a tmp copy: control 3/3 fixed both sites, grepped before editing, wrote the test; two rule arms matched it, one cost +30% and added a dependency. In-view probes cannot measure this class; an agentic probe with the plant outside the excerpt can.
- Same day: an edge-case rule showed opus 0/5 → 5/5 only because the control could fail on that plant; the security sentence beside it was saturated (control guarded the new query param 5/5).

**Why:** with the user's CLAUDE.md loaded, opus already does what most rules say whenever the material is in view. A bare control overstates every rule.

**How to apply:** `preloaded.sh` and `agentic.sh` in `validate-prompt-rules` run the two designs. Test `hit_regex` against a plausible hit and a plausible miss before trial 1; read two rows per cell before quoting a number (the classifier rule in SKILL.md). Rows: session scratchpad `raw26/`, `agentic/runs/`, `LEDGER.md`.

## 2026-09-15 Dispatch phase / brief lines (preloaded.sh, PRELOAD_USER=0, PROJ_MD=CLAUDE.md minus the new lines)
phase bullet: opus ctl 2/5 → A 5/5, sonnet ctl 0/5 → A 5/5 · line-range line: opus ctl 5/5 (leading scenario), sonnet ctl 0/5 → A 5/5 · batching instances: opus ctl 4/5 → 5/5, sonnet ctl 1/5 → 5/5 · simplify ecp preamble old vs new: 5/5 both arms both models, no-tools probe cannot discriminate an agentic no-op. 80 runs total.

## 2026-09-17 simplify CHECKLIST: Prose drift rung, and two duplicated passages (agentic sonnet reviewer, preloaded user CLAUDE.md)
Fixture: a diff renames `quote(express=bool)` to `speed=`; stale docstring (P1), stale caller comment in an untouched file (P2), stale README usage (P3), a past-release changelog line as distractor; round 2 adds an unimplemented spec rule (P4). Scored from a JSON findings block, Spec-section rows excluded from P1-P3 after a range collision was found in rows.
Round 1, n=5, reported at >=70: full rung P1 5/5 P2 5/5 P3 5/5 · rung removed P1 2/5 P2 0/5 P3 1/5 · 7-sentence trim P1 5/5 P2 4/5 P3 5/5 · changelog reported 0/5 in every arm.
Round 2, n=15, full CHECKLIST vs one without the per-skill gate paragraph and the Spec "reports on its own" sentence: P1 15/15 vs 15/15, P2 13/15 vs 13/15, P3 14/15 vs 15/15, P4 15/15 vs 15/15 (Spec section 15/15 both), every finding carried a fix 15/15 both, changelog 0/15 both. Every finding scored 50-69 across the 30 runs (10 rows) was real, which moved the fix gate to 50.

## 2026-09-23 Rewrite of writing-for-agents and validate-prompt-rules for claude-opus-5-5 (CLI 2.1.280)
Design: preloaded user CLAUDE.md (+RTK, ECP) in every arm, `CLAUDE_CONFIG_DIR` + `--setting-sources user` + `--disable-slash-commands`, skill body injected before the scenario as the Skill tool delivers it. A = shipped file, B = rewrite. Classifiers self-tested on a hit and a miss; rows read per cell. Scratchpad of session f9b48292: `wfa/`, `vpr/`, `LEDGER.md`.
Found on the way: `--model opus` resolved to claude-opus-5 on 2.1.278 and claude-opus-5-5 on 2.1.280. An empty config dir gets `skills/synced/` written into it during the run, and 25 skills load without `--disable-slash-commands`.
writing-for-agents, pilot n=5, control/A/B: every content probe saturated in all three arms except the measurement label (control 0/5, A 0/5, B 5/5). Two pilot probes (CSV split, codex escalation) were invalid: the preloaded CLAUDE.md holds both answers. Two n=15 runs, A vs B: label with a model ID 0/15, 0/15 vs 15/15, 15/15 · names `git add -A` 15/15, 14/15 vs 15/15, 15/15 · moment trigger 14/15, 15/15 vs 15/15, 15/15 · rule length, median words, backup-trigger rewrite 101, 100 vs 25, 24 and staging rewrite 97, 93 vs 70, 68. Hedge rule: control kept the hedge 5/5 (now inert on haiku, claude-opus-5 and claude-opus-5-5), deleted.
validate-prompt-rules, pilot n=5 control/A/B: skills disabled in the control command 0/5, 0/5, 5/5 · full model ID 5/5, 0/5, 5/5 (A's alias examples pulled opus to `--model opus`) · two n>=15 runs before shipping 0/5, 0/5, 5/5 · saturated reading 0/5, 5/5, 5/5 (bare Opus reads a saturated tie as "redundant, delete") · leave-one-out arms and reader model saturated. Two n=15 runs, A vs B, after reading every B miss (all classifier misses: Chinese "饱和", "independently"): 0/15 vs 15/15 on the first three in both runs, saturated reading 13/15 and 15/15 vs 15/15.
Cost note: every probe that separated at n=5 (0/5 against 5/5) gave the same result in both n=15 runs, about 420 calls with no new information. The trial rule changed the same day from "two n>=15 runs" to stepped n=5, 7, 10, 15 with a stop at the first clean separation.

## Older-model evidence, moved out of SKILL.md 2026-10-09

SKILL.md cites current-model measurements only. These rows ran on models that are no longer the default. Treat each status as unverified on the current model until it runs again. "haiku" before 2026-10-09 is claude-haiku-4-5.

- Model choice (behind "Probe on the model that reads the artifact"): a rule was inert on claude-haiku-4-5 (5/15 against a 4/15 control) and load-bearing on claude-opus-5 (14/15 against 8/15). The reverse also occurred: inert on opus, 0/6 to 6/6 on claude-haiku-4-5. 2026-10-09: the `except A, B:` red line was load-bearing on claude-haiku-4-5 (0/5 to 5/5) and inert on claude-haiku-5-5 (10/10 in both arms).
- Preloaded control: 2026-09-11, claude-opus-5, 26 design rules that looked useful against a bare reading were 25/26 saturated against the preloaded control. 2026-08-21: a punctuation guardrail looked like a no-op against a bare control, which was clean 10/10. Removed from its own document, the output was clean 0/10. The other paragraphs made the pressure that the guardrail resists.
- Compare arms inside one run: one identical claude-haiku-4-5 arm scored 9/15, 4/15 and 7/15 in three runs of the same input.
- Reword test: a red line's positive rewrite let claude-haiku-4-5 violate it in 1/3 trials, while the blunt negative held 3/3.

Re-run 2026-10-09 on the current models, CLI 2.1.295 (raw rows: session c7da8904 scratchpad `rv-unnamed.NYQjpC/`, `rv-variance.3QsKlD/`):

- Model choice: the first rule is `eli5` Part 2 rule 9, "Cap lists at 5 items". It now changes the answer on both current models: claude-haiku-5-5 1/15 to 9/15, claude-opus-5-5 7/15 to 11-12/15 (two judge passes). The "reverse" case is the `CLAUDE.md` "What a delegate returns" section. It shows no effect on either current model: 6/6 in every arm, because claude-haiku-5-5 now verifies the claim unprompted. Both old haiku-4-5 cells reproduce in the same harness. So neither probe now shows a rule that differs by model. The ECP trigger in SKILL.md is the current example.
- Compare arms inside one run: the original probe (the simplify CHECKLIST fix paragraph) saturates on claude-haiku-5-5, 15/15, 14/15, 14/15. A same-day 9/15 against 0/15 on another probe came from a cwd leak, not sampling (see the Isolation table). Measured later the same day: five runs of the `target-vendor-copy` arm A, n=15 each, 5 minutes apart, scored 11, 10, 8, 10, 10 (max minus min 3, 2 SD = 3.7). The model shows no run-level drift. The rule stands on setup drift between runs. Raw rows: `haikuvar.8CtCiX/`.
- Reword test: the red line is the `except A, B:` rule. The positive-rewrite wording and the probe are lost, so this row is not reproducible.
- Preloaded control: re-run on claude-opus-5-5 (raw rows: `rv-preload.uNkwUu/`). The 26 design-rule probes still saturate against the preloaded control (25/26 at 5/5). The bare control now saturates the same way (25/26), so these probes no longer show a bare control overstating a rule. The punctuation guardrail result reversed: bare control clean 4/15, the style excerpt without the guardrail 14/15, with it 15/15. The guardrail's own effect (1/15) is unsettled. No current-model probe shows the two controls disagreeing, so SKILL.md keeps only the 2026-09-23 opus-5-5 example.

## 2026-10-09 — recount command (unmeasured)

The Classifier section now asks for a read-only recount command. Origin: the main session re-ran a delegate's `grade.py` to verify its counts. That scorer calls a judge model and writes `graded.jsonl` in place. The judge's credentials were already removed, so every row came back ERR and overwrote the delegate's per-row verdicts. The per-model summaries survived in `grade.out`. The wording is a report-format rule, so it was shipped unmeasured.

## 2026-10-17 — call budget, saturation stop, `--tools ""`

claude-sonnet-5-5, n=5, skill body injected as the Skill tool delivers it, old file (A) against new file (B), single-line asks. "Call count before trial 1": A 0/5 (answered "predeclare the target"), B 5/5 (computed arms × probes × models × n). "Control saturated twice, next action": A 0/5 (all redesign and rerun), B 5/5 (report saturated and stop); hand-graded, because the regex scored a negated "don't rewrite" as a miss. The exploratory-probe and cheapest-reader sentences are unmeasured. `--tools ""` on a no-tools probe: one call each, input about 20k to 2.4k tokens, cost $0.0090 to $0.0045. Rows: session c6a25fc8 scratchpad `minab.*/` (labels-final.tsv, recount.py).

## Moved from SKILL.md, 2026-10-17
Each entry sat beside the rule it names. The rule text stays in SKILL.md.

### Isolation

Rule: Create every probe cwd with `mktemp -d /tmp/<name>.XXXXXX`, never under `$HOME`. Keep your outputs wherever you like.

Measured 2026-10-09 on claude-haiku-5-5, one run, n=10 per side: one preloaded arm scored 6/10 with its cwd under `/tmp` and 0/10 with its cwd in a scratchpad under `$HOME`. The scratchpad cwd loaded the live `CLAUDE.md`.

### Isolation

Rule: Create every probe cwd with `mktemp -d /tmp/<name>.XXXXXX`, never under `$HOME`. Keep your outputs wherever you like.

Verified 2026-10-09, CLI 2.1.295, on claude-haiku-5-5, claude-sonnet-5-5 and claude-opus-5-5: the sentinel came back with the file, and NONE came back without it. With `--disable-slash-commands`, the skill list returned NONE. Without it, the skill list returned 25 names on CLI 2.1.280.

### Isolation

Rule: ```

Measured: this wording caught a known-contaminated config 2 of 3 runs. A gate that reads a Yes/No token passed a contaminated control 3 times in 4.

### The method

Rule: - **Probe the case the rule might break**, not only the case it targets.

Measured: on a scenario whose wording implied its own verdict, control and rule arms scored alike 5/5. On a generative one, the control went 0/5. A multi-slot ask turned a 1/5 into a 5/5.

### The method

Rule: **Probe on the model that reads the artifact in deployment.** The main session reads `CLAUDE.md` and skills. A sub-agent reads its brief, and `CLAUDE.md` when i…

Measured 2026-10-06 and 2026-10-09: the `ECP.md` explore-trigger paragraph was inert on claude-opus-5-5 (5/5 in every arm) and load-bearing on claude-haiku-5-5 (1/15 without it, 14/15 with it).

### Three questions, three controls

Rule: When the preloaded files already state the answer, every arm copies it, and the probe measures the preload. To test a general lever of a document, pick a scenar…

Measured 2026-09-23 on claude-opus-5-5: two probes on CSV splitting and on codex escalation scored 5/5 in all three arms, because the preloaded `CLAUDE.md` holds both rules word for word.

### When the behaviour is "go and look"

Rule: A scenario that pastes the code puts the plant in view, and any rule about *finding* the plant saturates by construction. Probe that class agentically. `agentic…

Measured 2026-09-11: the historical miss the rule targeted was fixed 3/3 by the preloaded control in a fresh session. The rule arm matched it and cost 30% more.

### The classifier

Rule: Before you report a count, save each row's hit or miss to a file beside the raw rows. Report a recount command with the count: it reads that file and prints the…

Measured: a static `Http::timeout(` versus `->timeout(`, a test class named `…BatchTest`, and a copied `(bool)` cast each turned a real 5/5 into a reported 1/5. On 2026-09-23, "change the sentence back" missed a `revert|restore` pattern, and a negated "do not judge whether it is risky" tripped a `risky` miss pattern.

### How many trials

Rule: Before trial 1, write the call count: arms × probes × models × n. Report the calls spent with the result.

Measured 2026-10-17 on claude-sonnet-5-5 and claude-opus-5-5: a first round saturated all 20 cells and spent 200 of the run's 362 calls.

### How many trials

Rule: - **Compare arms inside one run.** Never compare a cell with a cell from another run.

Measured 2026-10-09 on claude-haiku-5-5: five runs of one arm scored 8 to 11 of 15, inside sampling noise. A cwd change between two runs moved the same arm from 6/10 to 0/10.

## 2026-10-21 — classifier native defaults, token-cut test, script contracts (unmeasured)

- The classifier: "Build the plausible hit the way the reader would…". Origin: an agentic pptx-cleaning probe (session 207afb98, scratchpad `agentic-gen.ItvRLG/score.py`). The hand-built hit renamed shapes to "物件 N". Every real run wrote PowerPoint's native "Table 3", and a `(Text|Shape|Image|Table) \d+` pattern scored it as a leftover trace in 10/10 runs. Reading two rows per cell caught it before any arm comparison.
- Token-cut test: added on the user's goal of total tokens (document plus run). Unmeasured.
- `preloaded.sh` header claimed probe JSONs need `hit_regex` and `scope`, and named a missing `score26.py`. The runner reads only `scenario` and `ask`. `agentic.sh` header omitted that `repo_path` keeps the work tree. Both cost a read of the script source; both headers now state it.

### 2026-10-21 — measured: classifier line, token-cut test, script headers

Text, preloaded, claude-opus-5-5, n=5, blind labels (scratchpad `vpr-ab.KvtDcy/`, `wfa-ab2.O9zHmx/`):
- Classifier "native default names" line: plausible hit made of native defaults, control 0/5, old 0/5, new 5/5.
- Token-cut test: "next action measures the run itself" saturated (5/5 all arms). Not predeclared: new named `total_cost_usd`/`num_turns` 5/5, old 0/5.
- writing-for-agents detour paragraph: KEEP a header line that says where outputs stay, saturated 5/5 all arms.

Agentic, outer claude-opus-5-5 with the skill body in the task, inner claude-haiku-5-5 6-call A/B, n=10 per arm, mechanical trace scoring (`agentic-gen.ItvRLG/detour_score.py`, scratchpad `detour-old.WlvXtp/`, `detour-new.eVjtzf/`, $5.65):
- All 20 runs finished the task. Median cost $0.28 old vs $0.27 new, turns 7 vs 6.
- Runs that read script source: old 4/10, new 3/10. Unsettled.
- The header fix removed its own detour: `grep scope preloaded.sh` 3/10 old, 0/10 new. New runs still read the header with `head -40` / `sed`: the skill says "do not read" and names no way to see usage.

### 2026-10-21 — v2 vs v3 (the `--help` line, the I/O-free script table, `legacy/`)

Same agentic task and scorer, n=10 each, run together (scratchpad `detour-v2.rkLBAn/`, `detour-v3.LNWob1/`, $5.69):
- Success 10/10 both. Runs that read script source: 1/10 both. Runs that called `--help`: v2 9/10 (no instruction), v3 10/10.
- Median cost $0.25 v2 vs $0.32 v3, turns 5 vs 7.5: the predeclared "not higher" check fails at face value.
- The extra cost is hand-run isolation proofs (the four checks in Isolation, run with `claude -p` outside the script): runs that did them were old 3/10, new 3/10, v2 2/10, v3 5/10. Unsettled, and the Isolation text is the same in all four cells. A run that does the proof costs 7 to 10 calls; one that skips it costs 4.
- Open: `preloaded.sh` and `agentic.sh` print no isolation gate, so the proof is left to each agent and runs split between doing it and skipping it.

### 2026-10-21 — `isolation_gate.py` (v3 rerun vs v4)

Same agentic task, n=10 each, run together (scratchpad `detour-v3b.X87dGB/`, `detour-v4.sQAuvv/`, $5.40). v4 = the gate in both scripts plus the Isolation sentence that hands the proof to the scripts.
- Success 10/10 both. Runs with a hand-run isolation proof: v3b 3/10, v4 0/10. All 10 v4 runs printed the gate line.
- Before the gate, the same task across five cells (old, new, v2, v3, v3b): 16/50 hand-run proofs.
- Cost: median $0.25 vs $0.24, sum $2.94 vs $2.46. Tool calls per run: v3b 4 to 7, v4 4 to 5. Script-source reads 1/10 vs 0/10.
- The v3 cell's $0.32 median (previous section) did not repeat: v3b, the same files, scored $0.25. Read it as run-to-run noise.
- Gate cost: uncached 4.1 s, 3 claude-haiku-5-5 calls; cached 0.05 s. `test_isolation_gate.py`: 4 live tests, the three plants (no `--disable-slash-commands`, `--setting-sources project`, cwd under `$HOME`) each fail the named check.

## 2026-10-21 — call budget of one token pass

A token pass over `~/.claude/CLAUDE.md` and `writing-for-agents` spent about 2,200 `claude -p` calls on about 25 edits, for about 330 tokens saved per load. Two runs with JSON usage cost US$11.58 for 340 calls and US$9.64 for 308 calls, about US$0.03 per call at API prices. Seven probes saturated on the control and still had arms planned; screening first would have skipped their arms. One rationale cut ("so the user can override") had a control at 0/5 and changed behaviour (claude-sonnet-5-5 9/10 to 0/10), so the screen must run on every edit, not only on a class of edits. Parallelism: 340 calls at 8 workers, 0 failures; about 2,400 calls that day, 5 failures, all near a credit cut-off. Rows: `~/.claude/prompt-runs/2026-10-21-token-pass-{r1,ae,fi,wfa,mech}/`, raw rows in each `raw.tar.gz`.

## 2026-10-21 — blind hand labels: not added

Probe 05b of the `SKILL-MECHANICS.md` run was first hand-labelled with the arm visible in the file names, then relabelled blind (shuffled IDs, key opened after labelling). The blind pass changed 0 of 60 A/B labels. The same day's real labelling risk was a metric picked after reading rows (the "so the user can override" offer), which blinding does not catch; "label a probe you add after you read the data as exploratory" covers it. No `blind.py` and no blind-label rule were added. Revisit when a hand-labelled cell sits within 1 trial of a ship threshold. Rows: `~/.claude/prompt-runs/2026-10-21-token-pass-mech/` (`blind/`, `blind-d/`).
