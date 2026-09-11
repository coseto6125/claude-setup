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
