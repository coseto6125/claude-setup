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
