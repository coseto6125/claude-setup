# Measurements behind the SKILL.md rules

Evidence for SKILL.md sections, one dated section each. Read when you doubt a rule; SKILL.md carries the rule.

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
- Compare arms inside one run: the original probe (the simplify CHECKLIST fix paragraph) saturates on claude-haiku-5-5, 15/15, 14/15, 14/15. A same-day 9/15 against 0/15 on another probe came from a cwd leak, not sampling (see the Isolation table). The mid-range run-to-run spread on claude-haiku-5-5 is still unmeasured.
- Reword test: the red line is the `except A, B:` rule. The positive-rewrite wording and the probe are lost, so this row is not reproducible.
- Preloaded control: re-run on claude-opus-5-5 (raw rows: `rv-preload.uNkwUu/`). The 26 design-rule probes still saturate against the preloaded control (25/26 at 5/5). The bare control now saturates the same way (25/26), so these probes no longer show a bare control overstating a rule. The punctuation guardrail result reversed: bare control clean 4/15, the style excerpt without the guardrail 14/15, with it 15/15. The guardrail's own effect (1/15) is unsettled. No current-model probe shows the two controls disagreeing, so SKILL.md keeps only the 2026-09-23 opus-5-5 example.

## 2026-10-09 — recount command (unmeasured)

The Classifier section now asks for a read-only recount command. Origin: the main session re-ran a delegate's `grade.py` to verify its counts. That scorer calls a judge model and writes `graded.jsonl` in place. The judge's credentials were already removed, so every row came back ERR and overwrote the delegate's per-row verdicts. The per-model summaries survived in `grade.out`. The wording is a report-format rule, so it was shipped unmeasured.
