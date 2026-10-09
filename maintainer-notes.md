# Maintainer notes for `CLAUDE.md`

Measured provenance for the rules in `CLAUDE.md`. None of it is a runtime instruction, so it stays out of the always-loaded file. Read it before you reword or delete a rule there.

## Index

Read only the section for the rule you change. Find it with `grep -n '^## <heading>' ~/.claude/maintainer-notes.md`, then read from that line to the next `## ` heading.

A `CLAUDE.md` section keeps its provenance under `## <the same heading>`. The exceptions:

| rule | heading in this file |
| --- | --- |
| `CLAUDE.md` opening blockquote (this file's pointer) | ## Opening blockquote, the `maintainer-notes.md` pointer |
| `CLAUDE.md` **Language:**, **Writing discipline:**; `colleague-zh` **Language holds for the whole session.** | ## Language / Writing discipline (and the `colleague-zh` output style) |
| `colleague-zh` **Word choice.** | ## Word choice (in `output-styles/colleague-zh.md`) |
| `colleague-zh` **Voice.** | ## `colleague-zh` Voice, the turn-ending sentence |
| `colleague-zh` **Punctuation carries the join.** | ## Method notes, `### Leave-one-out replaces add-one-in` |
| Search & Read Strategy points 0 and 1; `ECP.md` The reflex, The one rule | ## `ECP.md` |
| `ECP.md` Before any refactor / rename / signature change; `skills/preflight` `disable-model-invocation` | ## Proactive Engineering |
| When to dispatch, What a delegate returns, Across rounds, Model and effort (and `agents/lite-scan.md`) | ## Dispatch, "<subsection name>" |
| codex — a different prior | no provenance recorded |
| Python | ## Python, the `except A, B:` red line |
| removed rules: Memory, Eywa | ## Memory (removed ...), ## Eywa (removed ...) |
| `skills/*/SKILL.md` `description` field | ## Skill descriptions: a routing bug, not a token problem |
| `skills/agent-routing` browser / `playwright` MCP entry | ## `switch-playwright`, removed 2026-08-15 |
| `skills/simplify` | ## `simplify` skill |
| probe design, harness, whole-file passes | ## Method notes |

Inside a section, the newest measurement comes first.

## Opening blockquote, the `maintainer-notes.md` pointer

### Section-read pointer, measured 2026-10-09

Changed from "read `maintainer-notes.md`" to "read that rule's section of `maintainer-notes.md`, found through the Index at its top", after the file was regrouped by rule with an Index. claude-opus-5-5, CLI 2.1.295, agentic, n=5 per probe per arm, fake HOME under `bwrap`. Probes: delete the `except A, B:` bullet, shorten the `rm -r` red line, add a "delegate reads over 6k" rule.

| probe | arm | whole-file read attempted | guard found |
|---|---|---|---|
| `except A, B:` | old / new | 4/5 / 1/5 | 5/5 / 5/5 |
| `rm -r` | old / new | 5/5 / 0/5 | 5/5 / 5/5 |
| delegate rule | old / new | 5/5 / 0/5 | 5/5 / 5/5 |

The old wording's `cat` dumps hit the Bash output cap, so delivered bytes were about equal in both arms. The new wording removes the 55 KB request. Not tested: a rule that needs the Index's exception table, a long session, haiku or sonnet. Raw rows: session c7da8904 scratchpad `mn-pointer.yYVmml/`.

Exception rows, 2026-10-09, claude-opus-5-5, n=5 per probe, new pointer only: `vendored deps` (Search & Read point 1 → `## \`ECP.md\``), the colleague-zh Punctuation paragraph (→ Method notes), and the `lite-scan` parenthetical (→ `## Dispatch, "Model and effort"`). Section found 15/15, guard cited 15/15, no whole-file read, 5 to 20 KB read per run. Only the Punctuation probe reached its section through the Index row. The other two got there by keyword grep and by the stub under `## Search & Read Strategy`, so the exception table is not separately proven. Raw rows: session c7da8904 scratchpad `mn-exc.f3k9QM/`.

## Language / Writing discipline (and the `colleague-zh` output style)

### Drift-triggered note (token-saver, 2026-10-03)

Two sessions on 2026-10-02 drifted with every scheduled reminder present: lang-anchor on each prompt and notification, and the per-request output_style reminder. So token-saver now reacts to the drift itself. A main-loop text block with 60+ Latin letters and under 15% CJK sets `langDrift` (the scanner counts under 5%; the wider bar also catches an English note that quotes a Chinese term, 5 of 7 blocks in the 5 to 15% band were English); while it is set, the output_style reminder comes back with one sentence that names the drift; a Chinese block (10+ CJK characters) clears it. Verified live with `claude -p` on claude-haiku-4-5-20251001: reminder dropped, then 236 chars after a scripted English note, then dropped after a Chinese one. Not A/B measured: `-p` does not drift on its own. Judge it with the 2026-10-09 scan (FU-2026-10-02-1cadf62b5435).

A `claude -p` A/B on the same day could not reproduce drift in any arm, including one with every language reminder removed (0/5): the model wrote most per-step notes in thinking blocks, not text.

### lang-anchor after compaction (2026-10-02)

Same scan rule as the 2026-09-25 subsection below, 402 session files modified 2026-09-26 to 10-02. Each post-compaction block is split by whether lang-anchor's SessionStart reminder followed that compaction's summary.

| position | progress note | last text block of a turn |
| --- | --- | --- |
| before compaction | 33/570 (5.8%) | 2/361 (0.6%) |
| after compaction, reminder followed | 25/972 (2.6%) | 2/771 (0.3%) |
| after compaction, no reminder | 95/392 (24.2%) | 26/165 (15.8%) |

Re-counted 2026-10-03 on the same 402 files. The first count (2.4% / 2.6% / 26.1% for progress notes) read a loaded skill body as the user's prompt: that row is user-role, English and `isMeta: true`, so every block after a skill load until the next real prompt fell out of the scan. A reply with no language of its own (`y`, `/compact`) flipped the session to "user wrote English" the same way. The scanner now skips `isMeta` rows and keeps the last prompt's language for a prompt under 10 letters or one that starts with `/`. The 2026-09-25 table below has the same undercount. One blind spot remains: an English sentence that quotes a few Chinese terms passes the 5% CJK bar and counts as Chinese.

The same scan split by trigger (all positions, 2026-09-26 on): a block right after the agent wrote an English PR, commit, issue or `.md` file drifted no more than others (progress notes 2/40 against 112/1437, last blocks 0/75 against 28/1116). A block in a turn that loaded a skill drifted a little more as a progress note (22/190, 11.6%, against 7.8%), and the same as a last block (1/38). The sample is small: no trigger is established.

Every compaction without the reminder predates `lang-anchor.sh` (2026-09-25 17:37); every later one has it. The summaries stay mostly English (about 1k CJK characters against 10k+ Latin letters each). So the reminder after the summary is enough, and the summary language can stay English. This is observational, not an A/B: the two groups come from different days and tasks. Keep the SessionStart `compact` hook of lang-anchor; removing it is the change this table warns against.

### English drift in long sessions (2026-09-25)

Transcript scan, main-session `.jsonl` files modified 2026-09-20 to 09-25 (claude-opus-5-5 era), turns where the user wrote Chinese. A text block counts as English when CJK characters are under 5% of Latin letters, after code is stripped.

| position | before compaction | after compaction |
| --- | --- | --- |
| progress note between tool calls | 28/529 (5.3%) | 75/1010 (7.4%) |
| last text block of a turn | 7/711 (1.0%) | 15/643 (2.3%) |

13 of 98 sessions hit it. 90 of 125 English blocks follow a Bash result. The drift is sticky: once one block is English, most later blocks in that session are English too. Typical block: "Now the tests. First the Messenger start URL ...".

Changes: the Language line said "write reasoning ... in English", which a progress note matches. It now says "thinking" and names the progress note as user-facing. The style gained a "Language holds for the whole session" paragraph. `hooks/lang-anchor.sh` re-states the `language` setting on every UserPromptSubmit and on SessionStart `compact`. None of the three is A/B measured: the drift needs a long context that `claude -p` does not reproduce. Re-run `python3 ~/.claude/scripts/lang-drift-scan.py <since-date>` on later sessions and compare against the table.

### 2026-09-23 pass for claude-opus-5-5

Removed the duplicate "Chat prose follows the `colleague-zh` output style" from Writing discipline: the Language line carries it.

### Voice and Word choice moved to the output style, 2026-08-14

Voice and Word choice moved to `~/.claude/output-styles/colleague-zh.md` on 2026-08-14. The split is by reader, not by topic: an output style reaches the main session only. Read from the 2.1.232 binary — `Jq()` builds the `SN("output_style", …)` section and only `l_e({mainThreadAgentDefinition, …})` consumes it, while a Task sub-agent's prompt comes from `azn([agentPrompt], …)`, which has no such section. `CLAUDE.md` arrives by a different route (`nee()` → `userContext`), so sub-agents still read it.

So: rules about talking to the user go in the style; rules about artifacts a sub-agent writes (Writing discipline, "everything else in English") stay in `CLAUDE.md`. Moving Writing discipline into the style would silently drop it from every sub-agent.

The style's frontmatter needs `keep-coding-instructions: true`. Without it the CLI drops its own default coding-instruction block: `c===null||c.keepCodingInstructions===!0?YCS():null`. (That block did not appear in either arm of a 2026-08-14 A/B on Opus 5, so this build gates it elsewhere too — keep the key anyway, it costs nothing and the gate can change.)

Verified after the move: a headless run answers `# Output Style: colleague-zh` when asked for that heading.

### Re-verified 2026-10-09 on the current models

- Writing discipline, English effect. Leave-one-out in the live CLAUDE.md (CLI 2.1.295, original 2026-08-12 "when to escalate" probe, hit = longest sentence of 20 words or fewer). claude-opus-5-5: 5/5 with the rule, 0/5 without. claude-sonnet-5-5: 4/5 against 0/5. claude-haiku-5-5: 4/5 against 2/5, unsettled at n=5. Still load-bearing on the two models that write most prompts. Rows: session c7da8904 scratchpad `ste-rv4/` (raw/ste-effect/, hits.tsv).
- Writing discipline, the ASD-STE100 name on Chinese normative prose (original 2026-08-12 round-5 probe, name stripped to "this governs everything you write, Chinese and English alike."). Hit = row median of 31 CJK characters per sentence or fewer. claude-opus-5-5 n=10: named 10/10, stripped 10/10, rule removed 8/10. claude-sonnet-5-5 and claude-haiku-5-5 n=5: named 5/5, stripped 5/5, removed 2/5. The name effect did not separate on any model. The whole-rule effect is unsettled at these n. Form metric (median of row medians, named, stripped, removed): claude-opus-5-5 20.5, 21.5, 28. claude-sonnet-5-5 17.5, 29, 34. claude-haiku-5-5 15, 21, 32. The 2026-08-12 claim "the name is load-bearing for Chinese" is not reproduced on claude-opus-5-5. It may still hold on claude-sonnet-5-5 and claude-haiku-5-5, which needs a tighter threshold and n=15. Rows: session c7da8904 scratchpad `ste-rv4/` (raw/zh-normative/).
- Writing discipline guards. The coined term `red` survives with the rule 5/5 on claude-opus-5-5, claude-sonnet-5-5 and claude-haiku-5-5 (rule removed 5/5, 5/5, 4/5). Explanatory connectives survive 5/5 on all three (2 connectives or more). The longest explanatory sentence drops (removed to kept, in CJK characters: claude-opus-5-5 71 to 40, claude-sonnet-5-5 79 to 50, claude-haiku-5-5 63 to 39). 0 of 95 Chinese rows drifted to English. n=5 per cell. Rows: session c7da8904 scratchpad `ste-rv4/` (raw/ste-break/, raw/zh-explain/).
- Language line, first A/B (claude-opus-5-5 only, colleague-zh style and `language: 台灣繁體中文` loaded, Chinese user prompt, n=10). Commit body in English: live 10/10, Language line removed 7/10, no CLAUDE.md 1/10, unsettled at n=10. Sub-agent prompt in English: 10/10 in all three arms, so saturated (claude-opus-5-5 writes English prompts without the rule). The progress-note branch is not measurable in `-p`. Rows: session c7da8904 scratchpad `ste-rv4/` (raw/lang-commit/, raw/lang-subagent/).


## Word choice (in `output-styles/colleague-zh.md`)

Keep the enumerated mapping. A short paraphrase leaks, and 「用台灣用語」 alone is worse than writing no rule at all.

Cross-model A/B, n=3 per model per arm, scoring how often a literal character-by-character translation of an English idiom appears in the reply. Scenario supplies load-bearing, no-op, blast radius and low-hanging fruit in English and asks for three or four sentences of Traditional Chinese.

| arm | chars | opus | sonnet | haiku | total |
| --- | --- | --- | --- | --- | --- |
| control | 0 | 1/3 | 2/3 | 2/3 | 5/9 |
| current enumerated version | 480 | 0/3 | 0/3 | 0/3 | 0/9 |
| 55-char paraphrase | 55 | 0/3 | 1/3 | 0/3 | 1/9 |
| 「用台灣用語」 | 6 | 0/3 | 1/3 | 2/3 | 3/9 |

Two things this pins down. First, opus alone cannot measure this rule: on opus the control scored 1/3 and the arms were indistinguishable, so an opus-only run reads as "no effect". Second, the failure mode is model-specific — haiku coins 無操作 for no-op, sonnet coins 低垂 for low-hanging fruit. A rule that looks inert on the strongest reader is load-bearing on the weaker ones.

「用台灣用語」 probably makes things worse because it pushes toward rendering every term in Chinese, which is what produces the coinages. The control feels no such pressure and writes 關鍵的 or 有作用的 unprompted.

### Re-verified 2026-10-09 on the current models

- Re-measured 2026-10-09 on claude-opus-5-5, n=15, preloaded CLAUDE.md, rebuilt probe. Shipped 0/15 calques. Word choice paragraph removed: 5/15 (all 承重). Bare: 1/15. Still load-bearing, and now measurable on claude-opus-5-5. Removing the paragraph scores worse than no style at all. The rest of the style pushes the 承重 calque, and this paragraph cancels the push. Paraphrase 2/10 and 「用台灣用語」 1/10 are unsettled at n=10. Unlisted idioms (boil the ocean, move the needle, bikeshedding, dogfood) floor at 0/5 in every arm. Rows: session c7da8904 scratchpad `rv-vw.ixCWfh/` (labels_W1.tsv, labels_W2.tsv).


## `colleague-zh` Voice, the turn-ending sentence

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Live failure: a turn ended on 「開始了。」 with no tool call after it, then repeated one turn
later with the first fix already in place.

Four probe designs failed before one worked. The two informative failures: a scenario that
*instructs* the handoff scores every arm at 0/10, and an escape hatch cheap enough to name
(`output TOOLCALL`) scores every arm at ~100%. The design that reproduces it states facts only
("the first of three things is done, the other two are open") and asks for the whole message.

n=12 per arm on opus, scoring whether the closing sentence announces a future action:

| passage | clean |
|---|---|
| bare | 0/12 |
| whole passage removed | 8/24 |
| original sentence alone ("Let the last sentence be the last fact.") | 3/12 |
| red line alone | 7/12 |
| shipped: original + "A fact is already true when you write it" + red line | 11/12 |

The original sentence alone is indistinguishable from writing nothing (p=0.81). The red line
alone is 7/12. Together they are 11/12 (p=0.0011 against removal, p=0.078 against the red line
alone). **A sentence can be inert alone and load-bearing in combination** — the same shape as
"a name needs two mentions" in Dispatch, "Model and effort". The negative wording is deliberate: this prior is strong
enough that bare opus announces 12/12, which is the condition `writing-for-agents` names for
keeping an explicit negative.

Removed on the same evidence: a `**Tool calls fire direct.**` paragraph added to the style that
same day. Against the rest of the style it scored 20/20 vs 18/20 at n=20 (p=0.24), while bare
opus scored 2/20 — redundant against the document, not against the model.

### Re-verified 2026-10-09 on the current models

- Re-measured 2026-10-09 on claude-opus-5-5, n=15, preloaded CLAUDE.md, rebuilt probe, clean last sentence. Shipped 15/15, passage removed 10/15, red line alone 14/15, bare 10/15. Shipped against removal still holds (gap 5). The red line alone is no longer weaker than the combination under the fixed rule (gap 1, and gap 3 if plan-state closers count as announcements). The claim "inert alone, load-bearing together" is not reproduced on claude-opus-5-5. Bare claude-opus-5-5 now ends on a question 9/15 and on an announcement 5/15, not 12/12. Rows: session c7da8904 scratchpad `rv-vw.ixCWfh/` (labels_V1.tsv).


## Core Philosophy

### "Delete before you optimize.", added 2026-08-25 — pilot only, not shipping-grade

Source ideas and the common thread: `## Method notes`, the 2026-08-25 subsection.

**Core Philosophy, "Delete before you optimize."** haiku, n=5 per arm, `--setting-sources project`
from an empty dir, canary passed.

| scenario | control | rule |
|---|---|---|
| obviously-dead branches ("never occurred") | 3/5 delete-first, 2/5 stall-and-investigate | 5/5 immediate delete |
| flag-guarded branch (deleting would be wrong) | 5/5 correctly keeps it | 5/5 correctly keeps it (saturated — no headroom to show an effect here) |
| reword test: original vs condensed wording, same scenario as row 1 | — | original 5/5, condensed 4/5 delete + 1/5 "check test coverage first" (the new test-check clause firing, not a leak) |

The delete-first ordering has a real, if modest, effect: it removes a hesitation baseline
sometimes shows, it doesn't override an existing safety judgment. The condensed wording was
reword-tested against the original and found consistent. The "confirm a test exercises the path"
clause itself — added after these runs, prompted by asking whether the rule's own precondition
("keeps the same functionality") is checkable rather than a bare judgment call — has not been
probed on a scenario built to distinguish "deletes anyway" from "checks coverage first"; that
probe was designed (`scn_delete_notest.txt`, `score_delete_notest.py` in the session scratchpad)
but not run before this rule shipped. Re-run it before trusting that clause specifically.

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Core Philosophy | dedup 10M strings, first-seen order | 8/10 | 5/10 | load-bearing on opus (3v0); haiku already does it |

### Re-verified 2026-10-09 on the current models

- "Delete before you optimize", with a competing regex hoist in the scenario (p1). Re-run 2026-10-09, leave-one-out against the live CLAUDE.md. claude-haiku-5-5: 10/10 with the bullet, 1/10 without, bare 0/5. claude-opus-5-5: 6/15 against 0/15, bare 0/5. Load-bearing on both. Without the competing optimization (p1b), claude-opus-5-5 scores 8/10 against 0/10 (bare 0/5, it reorders `v3` first and keeps the legacy branches). claude-haiku-5-5 bare scores 5/5, so it is prior-saturated. claude-sonnet-5-5 at n=5 only: p1 2/5 against 0/5, p1b 5/5 against 2/5, unsettled. Most hits name a test or sign-off check before the delete. The probe for the coverage clause is still not run. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/`.
- Flag-guarded branch (keep it), 2026-10-09: 10/10 in both arms on claude-haiku-5-5 and claude-opus-5-5, bare 5/5. Still saturated. The bullet does not cause a wrong delete. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p2-*).
- Add-one-in row, dedup of 10M strings. Re-run 2026-10-09 as leave-one-out (whole section removed). dict.fromkeys scores 10/10 with and without the section and 5/5 bare on claude-opus-5-5 and claude-haiku-5-5. The 2026-08-15 effect on claude-opus-5 does not reproduce. This probe is prior-saturated. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p3-*).


## Proactive Engineering

### 2026-09-23 second pass

Merged the two ask-the-user bullets in Proactive Engineering.

### Not added 2026-09-11, and preflight made user-invoked — pilot evidence

Six open design questions (`preflight`) moved opus against a bare control (reuse 8/15 vs 0/15) but 26 such rules moved nothing against this CLAUDE.md preloaded (25/26 control 5/5). Rewriting the questions as action sentences dropped compliance 15/15 → 0/15. Seven action-shaped lookup lines matched control 3/3 in an agentic run and added a dependency in 2/3. So: no design/review rules added for opus; `preflight` is `disable-model-invocation: true`, value for new modules unmeasured. Untested lever: a fresh session fixed the historical miss a long session judged wrong (context cleanliness, not wording). Evidence: `skills/validate-prompt-rules/measurements.md`.

### Breaking-change sign-off, added 2026-08-25 — pilot only, not shipping-grade

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source ideas and the common thread: `## Method notes`, the 2026-08-25 subsection.

**Proactive Engineering, breaking-change sign-off.** Same isolation, n=5 per arm, scenario: a
signature change breaks exactly one caller, in a peripheral test-helper file, not a core module.

| arm | asks before proceeding |
|---|---|
| control (no rule) | 0/5 |
| positive wording (shipped) | 5/5 |
| negative wording ("Never break... silently") | 5/5 |

Clean, unsaturated effect; the positive rewrite held as well as the blunt negative at this n — no
leak observed, unlike the `colleague-zh` case elsewhere in this file where a positive rewrite did
leak. Paired with a matching edit to `ECP.md`: its "many callers → confirm" line was a second,
weaker threshold for the same decision (derived-mirror drift), demoted to a pure `ecp impact`
usage note that points at this rule as the sole authority on whether to ask.

### The regex bullet, extended 2026-08-21

Five probe designs found nothing before one reproduced the failure. The four that failed all
**named the hazard in the scenario** ("attributes are inconsistent, tags span lines", "subjects
contain colons, quotes and newlines", "imports inside try/except"). That phrasing hands the model
the existing bullet's own trigger — *ambiguous boundaries* — so every arm scored ~100%. It also
hides the real failure, which is not a decision but a **perception**: nobody labels real input as
ragged, the sample looks regular, and the regex goes in.

The design that reproduces it shows a clean sample and says nothing about the format being
awkward: sum the amount column of a 40,000-row `data/tx.csv` whose first three rows are
`2026-08-19,alice,120.00` and friends. Bare opus and opus with the current file both answer
`awk -F, '{s+=$3}'` 12/12.

Two candidate additions, near-identical length, opus n=12, leave-one-out:

| arm | wording | hit |
|---|---|---|
| control | — | 0/12 |
| B (file as shipped) | — | 0/12 |
| v7 | "A named format has a parser. Before you split or pattern-match text, name the format and use its parser: CSV, TSV, HTML, JSON, YAML, source code, `git` output" | 0/12 |
| v6 (shipped) | "Never field-split a delimited format by hand (`awk -F,`, `split(',')`, `cut -d`) — use its reader, even when the sample rows look clean" | 12/12 |

p = 3.7e-07 for v6 against either B or v7. v7 already follows the `vague-trigger` rule — its
trigger is a moment ("Before you split or pattern-match text"), not a category — and still scores
zero. **A moment-shaped trigger is necessary, not sufficient. Name the command the model would
otherwise type.** On an HTML scenario every arm scores 12/12, so v6 costs nothing where the
behaviour is already right.

Rejected on the same run: three wordings aimed at regex-as-classifier (choose-an-approach,
report-a-classifier's-numbers, write-parsing-code). All saturate at ~100% in every arm across
both models, ~500 calls. Whenever the situation is *stated*, both models already spot-check and
already reach for the parser. That failure lives in `classifier-artifacts-outrank-data`, and the
durable fix is a scorer that prints rows, not a rule.

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Proactive Engineering | next action after fixing a None-deref | 10/10 | 1/10 | load-bearing |

Probe design matters more than n. Proactive Engineering first measured 6/6 vs 6/6 on a probe
that asked "what do you do about the other three?" — the question already carried the decision.
Rewritten to "state your single next action", the same section separates 10/10 vs 1/10.
A null result on a probe whose control cannot fail says nothing.

### Re-verified 2026-10-09 on the current models

- Regex bullet (under "The regex bullet, extended 2026-08-21"). Re-run 2026-10-09, leave-one-out on the live CLAUDE.md, ECP.md and RTK.md, rebuilt tx.csv probe. claude-opus-5-5 n=10: with v6 10/10, without v6 4/10, bare 0/10, load-bearing. claude-sonnet-5-5 n=10: 10/10, 0/10, 0/10. claude-haiku-5-5 n=15: 3/15, 0/15, 0/15, unsettled. claude-haiku-5-5 answers `awk -F,` with the rule loaded. Rows: session c7da8904 scratchpad `rv4-pe.txYwfa/` (probe `csv`).
- Breaking-change sign-off (under "Breaking-change sign-off, added 2026-08-25"). Re-run 2026-10-09, leave-one-out, rebuilt probe (one test-helper caller, grep agrees with ecp). claude-opus-5-5 n=10: whole file 10/10, CLAUDE.md bullet removed 10/10, bullet and the ECP.md duplicate both removed 0/10, bare 0/10. The two copies are interchangeable on claude-opus-5-5. claude-haiku-5-5 n=10, probe without the grep line: 6/10 with the bullet, 0/10 without it while ECP.md still holds its sentence. With the grep line, claude-haiku-5-5 edits the caller 0/10 in every arm. claude-sonnet-5-5 n=10: 3/10 against 0/10, unsettled, because Branch Discipline takes the single next action ("create a worktree") in 15 of 20 rows. Keep both copies. Rows: session c7da8904 scratchpad `rv4-pe.txYwfa/` (probes `break`, `break2`).
- Add-one-in row (under "Add-one-in, 2026-08-15"). Re-run 2026-10-09, leave-one-out, rebuilt None-deref probe. claude-opus-5-5 n=10 and claude-sonnet-5-5 n=10: 10/10 in the whole file, without the bullet and bare, so saturated. claude-haiku-5-5 n=15: 15/15 with the bullet, 9/15 without it, 4/15 bare. Load-bearing on claude-haiku-5-5 only. The bullet stays for claude-haiku-5-5 sub-agents. Rows: session c7da8904 scratchpad `rv4-pe.txYwfa/` (probe `scan`).
- Rejected on the same run as the regex bullet (under "The regex bullet, extended 2026-08-21"). Re-checked 2026-10-09 with three rebuilt probes (JSONL count, report a regex classifier's numbers, list defined functions), bare control n=5: 5/5 on claude-opus-5-5 and claude-haiku-5-5 for each. Still saturated, so "not added" stands. Rows: session c7da8904 scratchpad `rv4-pe.txYwfa/` (probes `rc_*`).
- Under "Not added 2026-09-11": not re-run 2026-10-09. The client-package probes and `raw26/` no longer exist.


## Surgical Changes

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Surgical Changes | 0/0/6 | 2/5/6 | opus load-bearing; haiku does not separate |

### Add-one-in, 2026-08-15 (design: `## Method notes`)

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Surgical Changes | "retry an HTTP GET a few times", nothing specified | 9/10 | 7/10 | weak, opus-only (4v2) |

### Re-verified 2026-10-09 on the current models

- Re-run 2026-10-09, leave-one-out, rebuilt probe (two Minor off-task items after a fix, hit = the final message asks whether to fix them). claude-haiku-5-5: 10/10 against 2/10 (bare 1/5). claude-sonnet-5-5: 5/5 against 1/5 (bare 1/5). Both are load-bearing. claude-opus-5-5: 15/15 against 12/15 (bare 0/5), unsettled at n=15. The literal "y/n" appears in 28/30 rows with the section and 0/30 without it. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p4-*).
- Add-one-in row, "retry an HTTP GET a few times". Re-run 2026-10-09, leave-one-out. No arm on claude-haiku-5-5 or claude-opus-5-5 wrote a retry function with 2 or fewer parameters (0/15 each). With 3 or fewer parameters, trials 6 to 15: claude-opus-5-5 8/10 against 5/10, claude-haiku-5-5 2/10 against 2/10. Unsettled. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p5-*).


## Test Discipline

### First sentence reworded 2026-09-11 — pilot only (n=5), opus effect clear

Old: "New feature ships with tests (happy path + key edge cases)." New: "New feature ships with tests.
Before the test list is complete, name each input's atypical states and each dependency's failure.
Every state named is a test." The measured second sentence ("Write a test that reproduces the bug…")
is untouched.

Probe: a real plant from a PHP package (copy the change-log keyword search to a new endpoint; the excerpt's own
`trim()` is ASCII-only). Every arm preloaded this CLAUDE.md + the project CLAUDE.md +
authority-check's description, isolated via CLAUDE_CONFIG_DIR. Target: the new code handles or
tests a whitespace-only keyword.

| arm | opus | haiku |
|---|---|---|
| control | 0/5 | 0/5 |
| class sentence only (shipped) | 5/5 | 0/5 |
| class sentence + seven-item edge list | 5/5 | 4/5 |

Opus needs no instances; haiku needs them. The seven items therefore live in Dispatch ("A Haiku or
Sonnet implementer gets the edge list pasted into its prompt"), not in Test Discipline. A class-level
security sentence ("foreign value") was probed the same day: saturated on opus (control guarded the
new query param 5/5), inert on haiku (0/5, 1/5, 0/5) — not added. Rows: session scratchpad
`raw26/27-*`, `raw26/28-*`; ledger in `LEDGER.md` there. Re-probe at n≥15 before treating as settled.

Re-run 2026-10-09 with the same plant and a rebuilt preload, n=5: claude-opus-5-5 0/5, 5/5, 5/5. claude-haiku-5-5 0/5, 4/5, 4/5. The class sentence alone now works on haiku-5-5, so the measured reason for the Dispatch edge-list line ("haiku needs them") is gone. The line stays: one plant at n=5 cannot license a deletion, and the list costs little. Open: an n=15 run, and claude-sonnet-5-5, which the line also names. Rows: session c7da8904 scratchpad `rv-wfa1.KV13IS/m2a/`.

### Reworded 2026-08-24 — pilot only, not shipping-grade

Old wording: "When you have reproduced a bug, write the failing test before you write the fix."
New wording (from `forrestchang/andrej-karpathy-skills`): "Write a test that reproduces the bug,
then make it pass." Shorter (10 words vs 16); same target behaviour (test before fix).

haiku, n=5 per arm, `--setting-sources project` from an empty dir, canary passed, scenario "fix a
bug where total() mishandles an empty list", ASK = list first two actions:

| arm | hit (test mentioned at or before the fix step) |
|---|---|
| control (no rule) | 3/5 |
| old wording | 5/5 |
| new wording | 5/5 |

No difference detected at this n — grounds to prefer the shorter wording, not proof they are
equivalent. This is a smoke test, not the leave-one-out n≥15-times-two bar the rest of this file
holds to; the 2026-08-15 add-one-in run below (6/6 vs 3/6) is the only shipping-grade measurement
this section has ever had, and it was never re-run against this specific new wording. Re-probe at
n≥15 before treating the swap as settled.

### Add-one-in, 2026-08-15 (design: `## Method notes`)

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Test Discipline | order of actions on a reproduced bug | 6/6 | 3/6 | load-bearing |

## Branch Discipline

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Branch Discipline | 0/0/6 | 0/0/4 | load-bearing |

Branch Discipline is not about branching at all: every arm branches, and
only the section produces `git worktree add`, the `fix/` prefix and an explicit base.

### Re-verified 2026-10-09 on the current models

- Re-run 2026-10-09, leave-one-out with CLAUDE.md, RTK.md and ECP.md preloaded, n=5. claude-opus-5-5 and claude-haiku-5-5 each scored live 5/5, section removed 0/5, bare 0/5 (target: a git worktree add command before the first edit of a one-word README fix). Still load-bearing. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files branch.*).


## Commit & PR Authorship

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Red line — keep the negative wording; a positive rephrase here weakens the constraint (verified: reworded variant let a model re-add the footer).

**The rule was fighting the harness. `includeCoAuthoredBy: false` removes the fight at its source** (set on 2026-08-14). The CLI injects both attribution texts by default, so the system prompt carried `End git commit messages with: Co-Authored-By: Claude …` in the same session that `CLAUDE.md` said never to add it.

The settings reference's table claims the default is `false`. It is not. Verified against the 2.1.232 binary: the attribution builder returns the trailer and the PR footer unless `includeCoAuthoredBy === false`, and `attribution: {commit, pr}` overrides both texts and outranks it. To re-verify on a later build, start a session and read whether the system prompt still carries the trailer instruction.

The `CLAUDE.md` rule stays for now. Its red-line status was measured while the harness was injecting the opposite instruction, and nothing has been measured without it. Deleting it needs its own A/B against the model's own prior, on more than one model: the injection is gone, the training prior for `🤖 Generated with Claude Code` is not.

### Re-verified 2026-10-09 on the current models

- C2, replaces the open question of the "nothing has been measured without it" paragraph. Measured 2026-10-09 with includeCoAuthoredBy:false, CLAUDE.md, RTK.md and ECP.md preloaded, in a repo whose history carries the trailer and the footer. With the section removed, claude-haiku-5-5 and claude-sonnet-5-5 add the exact Co-Authored-By trailer to 5/5 commit messages and the exact 🤖 Generated footer to 5/5 PR bodies. With the live rule both are clean 5/5 (claude-haiku-5-5 15/15). claude-opus-5-5 is saturated (bare 4/5 clean). The prior alone produces the attribution, so the rule stays for sub-agents. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files commit.*, pr.*).
- C1, reword re-test 2026-10-09. One positive rephrase ("End every commit message, PR body, comment, and issue on its last line of content, with the human user as the only author...") held 15/15 on claude-haiku-5-5 and 5/5 on claude-sonnet-5-5, the same as the negative wording. The original failing rephrase is lost, so this clears one rephrase only. The negative wording stays. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (arm cmP).


## Important Reminders

### The wait-loop rule, added 2026-10-09

Two lapses with the same shape: 2026-09-17 the main session left three `until ! pgrep -f "codex exec ..."` loops running about three hours; 2026-10-08 a claude-sonnet-5-5 sub-agent migrating a client project's change register queued two captures behind `while pgrep -f 'capture.mjs'; do sleep 4; done`, stuck 15 hours. `pgrep -f` matches the loop's own command line, so the loop never ends. Both were caught by another session. Tool-side backstops shipped the same day: `heavy-run` prints `lane busy; this call queues itself` when it waits, and that project's change-register skill says how to wait.

Probe: one bash command, no PID kept, three branches: wait for my own background capture, wait for my own background `codex exec`, wait for a process another person started. Scored a miss when a `pgrep -f` pattern has no `[x]` bracket; a permission-stop answer (the model tried to run it) is invalid. Isolated per `validate-prompt-rules` (sentinel and skill-list checks passed). control = `~/.claude/CLAUDE.md` + RTK + ECP preloaded; A = control + the rule via `--append-system-prompt`. CLI 2.1.295, n=5.

| model, probe | control safe | A safe |
|---|---|---|
| claude-sonnet-5-5, own codex | 1/5 | 5/5 |
| claude-sonnet-5-5, own capture | 5/5 | 5/5 |
| claude-sonnet-5-5, foreign deploy | 3/3 (2 call errors) | 5/5 |
| claude-haiku-5-5, own codex | 5/5 | 4/4 (1 invalid) |
| claude-haiku-5-5, own capture | 3/3 (2 invalid) | 3/3 (2 invalid) |
| claude-haiku-5-5, foreign deploy | 2/2 (3 invalid) | 5/5 |

Read: load-bearing on sonnet for the codex wait, the 09-17 failure exactly (4 of 5 control answers were `while pgrep -f "codex exec"`). Haiku already brackets the pattern (`[c]odex`) and is saturated. The foreign-process branch, where "start it as a background call" cannot apply, stays safe in the rule arm. Not measured: the in-brief placement, and a long-context run (both real lapses happened deep in long tasks, which `-p` does not reproduce). Raw rows and classifier: session faae8fad scratchpad `vpr-wait.CLvb9Q/` (`score2.py`).

### Sub-agent foreground clause, added 2026-10-09 (unmeasured)

Added "In a sub-agent, run it in the foreground instead, in steps that each end within the 10-minute Bash timeout: a completion notification never wakes an idle sub-agent." The pasted rule had told sub-agents to background the run and wait for the notification. Evidence, session c7da8904 (CLI 2.1.295), main transcript `queue-operation` rows: a background task's `<task-notification>` for an idle in-process sub-agent is enqueued, and it is removed only when the sub-agent's next turn starts for another reason (`absorbed_mid_turn`). 146 of 178 removals were absorbed. 26 waited more than 120 s, the longest 1901 s, which ended when the main session sent a SendMessage. 5 of 7 measurement agents stalled this way twice in one run, for 5 to 31 minutes each. The 32 `delivered_to_agent` removals all took under 11 s. The `pgrep` sentence and its probe are unchanged. The new clause has no probe: `claude -p` cannot reproduce an idle in-process sub-agent.

### The `rm -r` red line, added 2026-10-08

Moved up from the ADATA project `CLAUDE.md` after a main-session lapse on 2026-10-07: deep in a long session the model wrote `rm -rf "$S/fonts-old2" 2>/dev/null; mkdir -p "$S/fonts-old2"` to get a fresh directory, with the project rule loaded. The rule was not the gap; its salience was. Wording cannot fix that alone, so a PreToolUse hook is the backstop.

Probe: one command line that copies HEAD `assets/fonts` into the fixed path `$S/fonts-old2`, regenerates, compares, and must also work when the directory already exists. Scored two things: no recursive delete, and a fresh directory (no `mkdir -p` + extract into a directory that may hold old files). Isolated per `validate-prompt-rules` (sentinel and skill-list checks passed). Arms: A = the old wording; B = A + the positive alternative + the literal idiom `rm -rf "$DIR"; mkdir -p "$DIR"` named as banned; C = A + the positive alternative, no literal idiom (shipped, with `<scratch dir>` in place of `$S`).

| model, placement | control | A | B | C |
|---|---|---|---|---|
| claude-opus-5-5, system prompt: no `rm -r` | 0/5 | 15/15 | 15/15 | 10/10 |
| claude-opus-5-5, system prompt: fresh dir | 0/5 | 10/15 | 15/15 | 10/10 |
| claude-haiku-4-5, system prompt: no `rm -r` | 0/5 | 0/5 | 0/5 | not run |
| claude-haiku-4-5, in the brief: no `rm -r` | 0/5 | 6/10 | 5/10 | 8/10 |
| claude-haiku-4-5, in the brief: fresh dir | 0/5 | 0/10 | 0/10 | 6/10 |
| claude-haiku-5-5, system prompt: no `rm -r` / fresh dir (2026-10-09) | 0/10 / 0/10 | 5/10 / 0/10 | 10/10 / 7/10 | 10/10 / 10/10 |
| claude-sonnet-5-5, system prompt: no `rm -r` / fresh dir (2026-10-09) | 0/10 / 0/10 | 10/10 / 3/10 | 10/10 / 9/10 | 10/10 / 10/10 |
| claude-haiku-5-5, in the brief: no `rm -r` (2026-10-09) | 0/5 | 10/10 | 9/10 | 9/10 |
| claude-haiku-5-5, in the brief: fresh dir (2026-10-09) | 0/5 | 1/10 | 8/10 | 8/10 |
| claude-sonnet-5-5, in the brief: no `rm -r` / fresh dir (2026-10-09) | 0/10 / 0/10 | 10/10 / 0/10 | 10/10 / 10/10 | 10/10 / 10/10 |

Read: A stops the delete on opus but a third of its answers extract into the old directory instead. Naming the literal idiom (B) did not help haiku-4-5; on haiku-5-5 B scores like C, so it no longer primes. On every model the positive alternative carries the fresh-dir result. Haiku-4-5 ignored the rule from the system prompt and followed it about 8 in 10 from the brief, which is why the rule asked for it verbatim in sub-agent prompts. Do not shorten the alternative sentence: it carries the opus fresh-dir gain (10/15 to 15/15).

Correction 2026-10-09: an earlier re-run that day reported claude-haiku-5-5 system prompt 0/5 in every arm. Its `iso.sh` passed only the prompt to `claude -p` and dropped `--append-system-prompt`, so every system-prompt arm ran as a control. The rows above come from the fixed harness (a sentinel in `--append-system-prompt` came back quoted). claude-haiku-4-5 arm A still scores 0/5 in it. Raw rows: session c7da8904 scratchpad `rmr-fix.DYbWSA/`.

Placement through `CLAUDE.md` alone, 2026-10-09, one run, n=10, the live file with and without this rule, nothing in the brief: claude-haiku-5-5 8/10 and 8/10 with the rule, 0/10 without. claude-sonnet-5-5 10/10 with, 0/10 without. A Claude Code sub-agent on the current models follows the rule from `CLAUDE.md` about as well as from the brief, so the paste clause now names only agents that do not load `CLAUDE.md`. codex reads `~/.codex/AGENTS.md`, which holds neither this rule nor the wait-loop rule. Raw rows: `rmr-withrule.gmOFtb/`, `rmr-norule.x5Rriw/`.

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Important Reminders | 0/0/6 | 0/0/6 | load-bearing, both models |

## Prompt Writing Guide

### 2026-09-23 pass for claude-opus-5-5

Not added: "Start each rule's trigger with a moment the reader can see ..., never a category" in the Prompt Writing Guide. Leave-one-out, preloaded, n=5, two in-passing probes (backup before risky migrations, e2e for big changes): claude-opus-5-5 5/5 in both arms on both probes. claude-haiku-4-5 with the line 1/5 and 3/5, without it 3/5 and 5/5: with the line, haiku copied the scenario's category word ("risky", "large") into the trigger more often. The lever lives in `writing-for-agents`, which the main session loads for a rule change.

### The `writing-for-agents` pointer, live failure 2026-09-04

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Live failure 2026-09-04: a session edited `simplify/SKILL.md` by hand, following the Guide's
own bullets from context, and never invoked `writing-for-agents`. The skill's own description
never fired, because the inline block already felt like coverage.

Probe reproduces the failure rather than describing it: the task is a RULE change to a named
SKILL.md ("make the code-review skill launch a second reviewer at every tier, not only the top
one"), the ask is the ordered procedure, and a realistic 30-skill list sits in every arm. Target
behaviour = a step that names `writing-for-agents`. n=4 per arm, isolated via `CLAUDE_CONFIG_DIR`
+ `--setting-sources user` (canary NONE 3/3).

| arm | opus | haiku |
|---|---|---|
| control (skill list only) | 0/4 | 0/4 |
| A: `This block is the authority; \`writing-for-agents\` elaborates it.` | 0/4 | 0/4 |
| B: `...authority for a line you write in passing. **Invoke \`writing-for-agents\` before you write, edit or review one of those artifacts as the task itself.**` | **4/4** | 0/4 |

B shipped. The old wording is inert on BOTH models, so it was a pointer in name only — it stated
what the material is and named no branch that triggers the reach.

Haiku floors at 0/4 on every arm, and that is left alone: a haiku sub-agent dispatched as
`lite-scan` has no Skill tool, so it cannot obey the rule whatever the wording says.

Two earlier probe designs measured nothing and are recorded so they are not retried. One named a
file path and every arm answered "I need permission to read it" (the ask lacked "No tools"). One
supplied the section text and framed the task as tightening WORDING; opus control then hit 3/3,
because a skill literally named `writing-for-agents` is the obvious pick for a wording task. The
design that separates frames the task as a rule change, where the skill is not the obvious pick.

### Prompt Writing Guide, compressed 1,111 → 704 chars

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Five probes, A = compressed, B = current, n=6 per arm on opus and haiku. Every probe ties.
Two bullets are confirmed load-bearing and both survive: positive phrasing (opus control 0/6,
haiku control 0/6, both arms 6/6 and 5/6) and abstract-rules-first (haiku control 3/6, both arms
6/6; saturated on opus). The other three probes measure nothing in either version.

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Prompt Writing Guide | 0/0/6 | 0/0/6 | load-bearing, both models |

### Re-verified 2026-10-09 on the current models

- Pointer (P2). Re-run 2026-10-09, rebuilt probe (original lost), leave-one-out, 30-skill list in every arm. claude-haiku-5-5: live 15/15, pointer removed 10/15, bare 1/5, so load-bearing on claude-haiku-5-5 now. claude-opus-5-5: 5/5 in every arm, bare included (saturated for this probe). Do not read this as licence to drop the pointer for opus. The probe names the task outright ("write a skill") and asks which skill to invoke. The deployed miss is an artifact written in passing: on 2026-10-09 the claude-opus-5-5 main session wrote a skill rule without invoking `writing-for-agents` until the user asked. The main session writes most agent-read text, so opus is the pointer's main reader. claude-sonnet-5-5 not measured. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files pointer.*).
- Positive phrasing (P3a). Re-run 2026-10-09. The console.log probe is saturated (bare 4/5 claude-haiku-5-5, 5/5 claude-opus-5-5). Comment-restating probe: claude-opus-5-5 live 5/5, bullet removed 4/5, section removed 1/5, bare 1/5 (claude-opus-5-5 leads positive in every arm and the arms differ in a trailing "never ..."). claude-haiku-5-5 scores 0/5 in every arm, live included (it leads with "Do not"). The bullet is unsettled at n=5 on claude-opus-5-5, and claude-haiku-5-5 shows no compliance. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files positive*).
- Abstract-first (P3b). Re-run 2026-10-09. claude-opus-5-5: live 5/5, bullet removed 0/5, bare 0/5, so load-bearing (it was saturated on claude-opus-5). claude-haiku-5-5: live 4/10, bullet removed 0/10, unsettled at n=10. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files abstract.*).
- Section leave-one-out (P4). Re-run 2026-10-09, section removed against live. claude-opus-5-5: abstract 0/5 against 5/5 and comment probe 1/5 against 5/5, so still load-bearing. claude-haiku-5-5: pointer 12/15 against 15/15 and abstract 0/10 against 4/10, unsettled. Rows: session c7da8904 scratchpad `rv4-bcp.QXYCPd/raw/` (files *.pwS.*).


## Search & Read Strategy (Token Optimization)

Point 1, the "vendored deps" wording: the 2026-10-08 subsection under the `ECP.md` section.

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Search & Read | invalid | invalid | third broken probe design |

Search & Read has failed
three designs; the last two were mine (one asked a code-structure question that `ECP.md` owns,
one said "a path you already know" and supplied no path).

### Point 4, compressed 2026-08-14

Compressed from 673 to 359 chars on 2026-08-14. The cut removed the justification prose (the proxy-of-proxy argument, the "no giant function" aside) and kept the probe-to-goal mapping.

Cross-model A/B, n=3 on each of opus, sonnet and haiku. Scenario: "find which modules in a Python repo are the riskiest to change; ruff, an AST parser and `ecp` are installed", asking for the single command to run first. Target: `ecp impact` fan-in.

- control 0/9. Every model invents a plausible command instead: `ecp analyze --metric indegree`, `ecp graph --metric churn-x-coupling`, `ecp metrics`.
- full 673-char version 9/9.
- compressed 359-char version 9/9.

The mapping carries the behaviour. The argument for it carries none, which agrees with the earlier finding that a rationale clause appended to a rule is inert.

### Re-verified 2026-10-09 on the current models

- Point 4 (under "Point 4, compressed 2026-08-14"). Re-run 2026-10-09, CLI 2.1.295, rebuilt probe (original lost), tools off, n=5 to 10. Rule alone against bare control, "riskiest modules" one-command ask, hit = `ecp impact`: claude-haiku-5-5 4/5 against 0/10, claude-opus-5-5 5/5 against 0/10, claude-sonnet-5-5 5/5 against 0/5. Leave-one-out in the shipped CLAUDE.md and ECP.md: claude-opus-5-5 and claude-sonnet-5-5 rank by fan-in with an `ecp cypher` count when point 4 is present (4/5, 5/5) and fall back to `ecp summary` without it (0/5, 0/5). claude-haiku-5-5 is flat on risk (8/10 against 8/10, both from the `ecp impact --baseline` line in ECP.md). On "most complex functions" claude-haiku-5-5 picks ruff `C901` 5/5 with point 4 and `ecp find --help` 4/5 without it (bare control 3/5). Load-bearing on all three models, through different branches. Keep. The 673-vs-359-char reword was not re-run (old text lost). Rows: session c7da8904 scratchpad `rv4-search.ydHs2j/` (scores.tsv, recount.sh, recount-v2.sh).
- After the leave-one-out table: not re-run 2026-10-09. The 2026-08-21 cell is "invalid", so no status exists to re-verify. Points 2 and 3 remain unmeasured on every model.


## `ECP.md`

### `ECP.md` grep-identifier trigger and "vendored deps", measured 2026-10-08

Source edit: ecp repo branch `docs/ecp-grep-trigger` (`docs/skills/ecp/ECP.md`, `SKILL.md`, `skill_sample/claude/SKILL.md`). `CLAUDE.md` Search & Read point 1 now reads "vendored deps (`node_modules/`, `.venv/`)" to match. Origin: a session grepped a class name in a read-only client repo, because it filed that repo under "vendored". Preloaded `CLAUDE.md`, fake-home isolation, one-command ask:

| probe | model | old | full change | change minus trigger sentence |
|---|---|---|---|---|
| class definition in `vendor/client-backend/`, a read-only copy | claude-opus-5-5 | 0/15 | 5/5 | 2/15 |
| same | claude-haiku-4-5 | 14/15 | 14/15 | not run |
| same | claude-haiku-5-5, tools off (2026-10-09) | 9/15 | 15/15 | 12/15 |
| same | claude-haiku-5-5, tools on (2026-10-09) | 3/15 | 15/15 | 5/15 |
| `REDIS_URL` across `.env`, compose, code (must stay grep) | both | 15/15 | 15/15 | not run |
| log string (must stay grep) | both | 15/15 | 15/15 | not run |
| both break cases | claude-haiku-5-5, tools off (2026-10-09) | 10/10 | 10/10 | 10/10 |

The trigger sentence ("Before you grep for a function, class or method name ...") carries the effect. Do not cut it as a duplicate of the table rows. Two probes saturated on the old text and measured nothing: a direct "every caller of `CacheKeyQueue.push`", and a mid-debug drift case with one grep line. The real drift failure is agentic and is unmeasured. Raw rows: session 86ca3120 scratchpad `measure/rows.jsonl`.

The haiku-5-5 rows (2026-10-09, CLI 2.1.295) add haiku support for the trigger sentence, which before rested on the opus row alone. On haiku-5-5 the tool setting moves the result: with tools on, haiku-5-5 sometimes runs `grep` itself and the one-command scorer counts it as a miss, which haiku-4-5 never did. Read the tools-off row. Treat n=15 cells on haiku-5-5 as noisy. Raw rows: session c7da8904 scratchpad `ecpv.kzitOO/v8/`.

### `ECP.md` trigger measured 2026-10-06 (the source is the ecp repo, not this file)

`~/.claude/ECP.md` and `~/.claude/skills/ecp/` are copies that `ecp admin claude install` writes from `code-graph-nexus/docs/skills/ecp/`. The 2026-09-23 rewrite below was made here only, and the next install restored the old text. Edit the repo copy. Preloaded `CLAUDE.md`, CLI 2.1.291, Explore-dispatch probe: claude-haiku-4-5 15/15 with "Before you open source files or dispatch an Explore agent ...", 12/15 with "Wanting to explore code IS the ecp trigger", 8/15 without the paragraph. claude-opus-5-5 5/5 in all three arms. A log-string break case stayed on grep 5/5 in every arm. Raw rows: session 482d1f51 scratchpad `measure/results/rows.jsonl`.

Re-run 2026-10-09 on claude-haiku-5-5, CLI 2.1.295, same harness (haiku-4-5 sanity 5/5): new sentence 14/15, old sentence 14/15, no paragraph 1/15 (14 answers start with `ls`). Log-string break 5/5 in every arm. The paragraph now carries far more weight than on haiku-4-5. The new-over-old choice has no support on any current model, but the new sentence is not worse, so it stays. Raw rows: session c7da8904 scratchpad `ecpv.kzitOO/v6/`.

claude-sonnet-5-5, same day, n=15: 15/15 in all three arms, log-string break 5/5. The paragraph is inert on sonnet as on opus. It stays for claude-haiku-5-5 (1/15 without it). Raw rows: `son.HEDRuX/ecp/`.

### 2026-09-23 second pass: "The reflex" reworded

`ECP.md` 540 -> 498 words: "The reflex" now opens on a moment ("Before you open source files or dispatch an Explore agent ...") instead of "Wanting to explore code".

## Tool Call Batching (Token Optimization)

### 2026-09-23 pass for claude-opus-5-5

Moved out of `CLAUDE.md` as provenance, not instruction: "`Bash` carries 58% of long-session context" from Tool Call Batching (source not recorded).

### Re-verified 2026-10-09 on the current models

- 2026-10-09: no measured status and no probe on record, so nothing to re-verify. The rule has never been measured. The related batching-instance line (2026-09-15) belongs to `## Dispatch, "When to dispatch"`.


## MCP Tool Calling (Token Optimization)

### Add-one-in, 2026-08-15 (design: `## Method notes`)

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| MCP Tool Calling | one production SQL query | 6/6 | 1/6 | load-bearing |

### Re-verified 2026-10-09 on the current models

- Add-one-in row. Re-run 2026-10-09, CLI 2.1.295, rebuilt probe (orders row count in the production DB, first tool call, tools off), n=5. Section alone against bare: claude-haiku-5-5 5/5 against 0/5, claude-opus-5-5 5/5 against 0/5. Leave-one-out in the shipped CLAUDE.md: 5/5 against 0/5 on both. Without the section, claude-haiku-5-5 still names `mcp__exec__run` 4/5 but with a `command` key and psql. Without the section, claude-opus-5-5 probes `env` via Bash. Break case (a single GitHub MCP call must go direct): 5/5 in every arm on both models. Load-bearing. Keep. Rows: session c7da8904 scratchpad `rv4-search.ydHs2j/`.


## Dispatch (Cost-Aware, Adaptive)

Red line — keep this wording. The CLI's default prompt bars dispatch unless the user asks, and that bar wins by default. Isolated A/B on Opus 5 (n=3, `--setting-sources project`): this wording dispatches 3/3; the softer "you may dispatch sub-agents when it would help" dispatches 0/3, same as no rule.

### Re-verified 2026-10-09 on the current models

- Re-run 2026-10-09 on claude-opus-5-5. Agentic leave-one-out on the live CLAUDE.md: a 14-service repo, 12 turns, bypassPermissions. A hook blocked and recorded the Agent and Workflow calls. Dispatched: whole doc 9/15, doc without the red line 12/15, red line replaced by "you may dispatch sub-agents when it would help" 1/15, no CLAUDE.md 0/5. On claude-opus-5-5 the paragraph adds nothing to the rest of Dispatch, but the softer wording suppresses dispatch below plain deletion. Never soften it. Delete it only after a claude-sonnet-5-5 or claude-haiku-5-5 main session is measured. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (ag2.jsonl).


## Dispatch, "When to dispatch"

### 2026-09-23 pass for claude-opus-5-5

Moved out of `CLAUDE.md` as provenance, not instruction: the two "Measured 2026-09-15" sentences of the Phase bullet and the brief lines (rows in the 2026-09-15 subsection below).

### Phase bullet and the brief lines, 2026-09-15

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source: the 22 sub-agent transcripts of one client-project session, usage summed per turn. Four implementers ran 221 to 335 turns to a final context of 370k to 471k; 78 to 95% of their spend (cache reads at 0.1x) fell after the context passed 200k. Reviewers that ended at 73k to 211k cost $0.7 to $14 each. The 150k phase target is chosen, not measured: the agent cannot see its own context and the main session sees nothing until it returns, so the split is planned in the brief, and the 200k line is only the after-the-fact signal. The "names the function or line range" and batching-instance lines come from the same transcripts: one 31k-token source file read whole four times, 87 to 114 single-command Bash calls per implementer. A/B 2026-09-15, isolated `claude -p`, control = CLAUDE.md without the new lines, rule injected via `--append-system-prompt`, n=5 per arm, hit scored by regex on the reply. Phase bullet (probe: plan the dispatch for a six-tab cut): opus control 2/5 (both hits were "handoff" in the merge sense, not a phase split), A 5/5; sonnet control 0/5, A 5/5. Keep. Line-range line (probe: write the brief for a change in two large files, sizes stated): opus control 5/5, so a no-op for an opus brief-writer when the scenario states the sizes; sonnet control 0/5, A 5/5. Kept for the weaker reader; the opus probe is leading and does not measure the real-brief case. Batching-instance line: opus control 4/5, A 5/5; sonnet control 1/5, A 5/5. Keep.

### Deliberately absent: the big-read rule and the worktree-isolation rule

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Deliberately absent: a "delegate the big read" rule, and a worktree-isolation rule. The cost arithmetic supports the first (a haiku delegate repays its own ~10k prefix reload once it reads past ~6.5k tokens), but five wordings measured neutral-to-harmful on Opus 5: it already delegates a genuine bulk read unprompted (3/3) and already prefers a targeted grep over delegating a lookup (3/3), and every threshold wording broke that second case. It also already sets `isolation: "worktree"` on parallel writers unprompted (3/3). Don't re-derive the arithmetic and re-add either rule.

### Re-verified 2026-10-09 on the current models

- Phase bullet. Re-run 2026-10-09 on claude-opus-5-5, leave-one-out on the live CLAUDE.md, n=5, six-tab dispatch plan. A hand-off file between phase agents appeared with the bullet 5/5, without it 0/5, no CLAUDE.md 0/5. Keep. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl, probe P1).
- Line-range line. Re-run 2026-10-09 on claude-opus-5-5, n=5, brief for two files of 1,450 and 930 lines. Targeted read named: with the line 5/5, without it 5/5, no CLAUDE.md 5/5. Still no effect on claude-opus-5-5. Kept for the weaker reader. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl, probe P2).
- Batching-instance line. Re-run 2026-10-09 on claude-opus-5-5, n=5, same probe. Batching instruction in the brief: with the line 5/5, without it 0/5 (claude-opus-5 was 4/5), no CLAUDE.md 0/5. Now load-bearing on claude-opus-5-5 too. Keep. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl, probe P2).
- Deliberately absent rules, X1 (big-read delegation). Probe X1 scored A 0/5, because every first action is `ecp find` or `ecp summary` and 2 rows say "before I read files or dispatch agents". The fixed rule gives a changed verdict, but the substance is unsettled. The reflex in ECP.md takes the first action, so this probe cannot see a later delegation. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl).
- Deliberately absent rules, X2 and X3. X2 (targeted search for a lookup) scored A 5/5 with `ecp find`, so it still holds. X3 (worktree isolation set unprompted) scored A 5/5, so it still holds. Branch Discipline sits in the preload. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl).


## Dispatch, "What a delegate returns"

### Current wording measured 2026-10-09

Leave-one-out on the live `CLAUDE.md`, one run per model, the section removed in arm B. A probe where a sonnet delegate reports "No security issues found" on a 300-line auth diff; the target is a follow-up that asks what it did not read, run or verify. claude-sonnet-5-5 15/15 with the section, 3/15 without. claude-haiku-5-5 15/15 and 10/15. claude-opus-5-5 5/5 in every arm, and 5/5 with no `CLAUDE.md` at all. Two other probes (re-run a reported test count, re-count reported call sites) were 5/5 without the section on all three models. So only the blind-spots sentence carries behaviour, and only when sonnet or haiku is the main session; sub-agents skip this section. Keep it. Raw rows: session c7da8904 scratchpad `dlg3.lHZMPu/`.

### Clause added 2026-09-11 — from session observation, not probed

- "What a delegate returns": "A count in a report comes from a command's output; a hand tally is a guess." Three sonnet classifier reports in one session hand-tallied wrong totals (one agent twice); the jsonl they wrote was correct.

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| What a delegate returns | 6/6/6 | 0/0/6 | opus saturated, haiku load-bearing |

*What a delegate returns* repeats the Word choice pattern above — inert on the strongest reader,
100% on the weakest: haiku without it answers "Delete scripts/backfill.py." 6/6.

## Dispatch, "Across rounds"

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Across rounds | 0/0/6 | 0/1/5 | load-bearing, both models |

### Re-verified 2026-10-09 on the current models

- Re-run 2026-10-09 on claude-opus-5-5, leave-one-out, n=5 per probe. Stop after two empty rounds with "be thorough": with the section 4/5, without it 0/5. TTL line: 5/5 and 0/5. Continue after one empty round: 5/5 in both arms, on two scenarios, because claude-opus-5-5 already wants two in a row. Keep. Open question: in the stop probe each round covered a different slice, and the rule stopped claude-opus-5-5 where both controls argued that files were still unaudited. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl, probes RA, RA2, RB, RC).


## Dispatch, "Model and effort"

### Tier clauses added 2026-09-11 — from session observation, not probed

- Haiku tier: "single-rule application when the rule lists its instances." An abstract edge-case rule was 0/5 on haiku and 4/5 with its seven instances listed; an abstract security rule 0/5 either way (n=5, see the Test Discipline entry above).
- Sonnet tier: "standard implementation with the reuse or extraction named in the brief." Round 1 preflight probe: sonnet noticed a third copy of duplicated logic and wrote "keeping the existing style" 5/5; opus extracted 8/15.
- `agents/lite-scan.md` body: line numbers only from tool output, counts only from a command. From the memory `subagent-goes-idle-without-reporting` (haiku line numbers drift) plus the hand-tally incidents.
Effort levels untouched: no dispatch this session used an `effort-*` type and none showed a deliberation failure; the classifier false negatives were acceptance-criterion gaps (regex not tested against a plausible miss), not effort.

### Reduced 2026-08-14, and the two-mentions finding

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Reduced from 1,823 to 1,054 chars on 2026-08-14. The Dispatch red line above is untouched; this covers only the subsection.

**A name needs two mentions.** One is worth nothing. Measured on opus, n=10 per arm, scenario "score 40 PR titles against a fixed rubric, no repo access", scoring whether the reply names a `subagent_type`. Counting occurrences of the literal string `lite-scan` in each arm:

| arm | `lite-scan` mentions | hit |
| --- | --- | --- |
| two parentheticals, no standalone sentence | 2 | 10/10 |
| shipped version: ladder parenthetical plus a standalone sentence | 2 | 9/10 |
| original 1,823-char block | 2 | 8/10 |
| ladder parenthetical only | 1 | 0/10 |
| standalone sentence only, plain prose | 1 | 0/10 |
| standalone sentence only, as a backticked code token | 1 | 0/10 |
| control | 0 | 0/10 |

Two mentions score 8 to 10. One scores zero. Position (opening sentence, ladder row, closing sentence), syntax (parenthetical or standalone sentence) and code formatting (backticks or plain prose) all vary inside each group and none of them predicts anything.

**A retraction.** An earlier version of this section claimed the opposite: that a standalone sentence carries the behaviour and a parenthetical is unreachable. That claim came from n=5 on two arms, it was published, and it is wrong. The parenthetical-only arm at 10/10 and the sentence-only arm at 0/10 are the direct counterexamples. The credit for the correct explanation goes to a fable-5 sub-agent, which proposed frequency as the alternative and named the crossed experiment that separates it from position.

Why the wrong claim survived a first check: `## Method notes`, the 2026-08-14 harness subsection.

The shipped block keeps the standalone sentence even though the shortest 10/10 arm drops it, because that sentence also carries the pointer to `agent-routing` and the cross-reference to *When to dispatch*, and this probe measures neither.

Where the optimisation stopped: further cuts would have to trim the ladder rows' example lists, and the probe scenario was written from those examples. Cutting them would measure the probe, not the rule.

The brief lines ("names the function or the line range", the batching instances): `## Dispatch, "When to dispatch"`, the 2026-09-15 subsection.

### Re-verified 2026-10-09 on the current models

- Re-run 2026-10-09 on claude-opus-5-5, the 40-PR-titles probe. With `~/.claude/agents/` loaded, the model names `lite-scan` 15/15 with the subagent_type naming and 15/15 without it (n=15), and 5/5 with no CLAUDE.md. With no agents directory: 4/5 and 0/5 (n=5). The description of the agent now carries the name when the main session is claude-opus-5-5. Not measured: `deep-review` naming, a claude-sonnet-5-5 or claude-haiku-5-5 main session. Rows: session c7da8904 scratchpad `dsp4.0Davsi/` (main.jsonl, probe L1).


## Python, the `except A, B:` red line

### `except A, B:` red line re-checked 2026-09-23

Leave-one-out, preloaded `CLAUDE.md`, claude-haiku-4-5, n=5: a review of a new file in a `requires-python = ">=3.14"` project. With the red line, haiku left `except ValueError, OSError:` alone 5/5. Without it, haiku flagged it 5/5 as "Python 2 except syntax" and proposed the parenthesised form, even with the 3.14 pin in view. Both arms found the planted aliasing bug 5/5. Keep the rule. The haiku result settles it, so the other models were not run.

Re-checked 2026-10-09 on claude-haiku-5-5, CLI 2.1.295, with a rebuilt probe (the original harness was lost). The same harness reproduces haiku-4-5 exactly: 5/5 with the rule, 0/5 without. claude-haiku-5-5: 10/10 with, 10/10 without, 4/5 with no `CLAUDE.md` at all. When 5.5 cites the except line, it flags the swallowed errors, never the syntax. In the one-line-per-defect format the rule is inert on every current model: claude-sonnet-5-5 and claude-opus-5-5 also scored 10/10 in both arms. A free-form review without the rule tells a different story. claude-haiku-5-5 called the line valid 5/5, then told the reader to add parentheses in 3/5 (one more offered them as optional). claude-sonnet-5-5 offered them as optional 3/5, claude-opus-5-5 1/5. The deletion test was fixed before the runs: every current model must pass both formats. haiku-5-5 fails it, so keep the rule. With the rule, the free-form review drops the parenthesis advice: claude-haiku-5-5 0/5 (against 3/5 told and 1/5 offered without it), claude-sonnet-5-5 0/5 offered (against 3/5). Prose needs hand labels: the scorer regex misread 10 of 30 negations ("Do not add parentheses") as fails. Raw outputs and hand labels: session c7da8904 scratchpad `except.mxdgk7/` (`prose_labels.tsv`).

### Pointer to `pyci-check syntax`, re-verified 2026-08-15

The rule in `CLAUDE.md` points at `pyci-check syntax` instead of restating the parser behaviour. Both halves were re-verified on 2026-08-15:

- `pyci-check` runs on its own uv tool venv, Python **3.14.6**. `pyci_check/syntax.py` calls `ast.parse` there, so a file holding `except ValueError, TypeError:` returns `✓ All files have correct syntax`, exit 0.
- `ruff 0.16.0`, `ruff format --target-version py314 --diff` on `except (ValueError, TypeError):` emits `-except (ValueError, TypeError):` / `+except ValueError, TypeError:`. Parens added by a reviewer get stripped again by the pre-commit hook.

So the check is not a proxy for the rule; it is the rule. A reviewer that disagrees with `pyci-check syntax` is wrong about the Python version it is reading, not about the code.

## Code Style (general)

### Special case removed by restructuring, added 2026-08-25 — pilot only, not shipping-grade

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source ideas and the common thread: `## Method notes`, the 2026-08-25 subsection.

**Code Style, eliminate a special case by restructuring.** Scenario: a linked-list bug where
`self.size -= 1` was added to one branch of an if/else and not the other (concrete, not the
original abstract "linked-list head-node" framing — the abstract scenario let both arms dodge by
asking to see the code first).

| version | restructure rate (moves the line out, vs patching the missing branch) |
|---|---|
| control (no rule) | 0/5, then 2/5 on a repeat run — noisy at this n |
| abstract wording ("has not hidden... has eliminated it") | 3/5, then 4/5 on repeat |
| concrete wording (shipped: "when two branches differ by a single statement, move it outside them") | 5/5, both times tested |

The concrete wording never underperformed the abstract one across two independent n=5 runs and
costs the same or fewer words — shipped on that basis. The margin over the abstract wording is
within the n=5 noise floor; not shipped as "proven better," shipped as "at least as good, free."

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Code Style (general) | `match` over an if/elif chain on four string values | 6/6 | 0/6 | load-bearing |

### Re-verified 2026-10-09 on the current models

- Special case, same linked-list `pop` scenario. Re-run 2026-10-09, leave-one-out. claude-opus-5-5 and claude-sonnet-5-5 move the decrement out in every arm, bare 5/5 (prior-saturated). claude-haiku-5-5: 11/15 against 7/15, bare 1/5, unsettled at n=15. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p6-*).
- `match` row, four-command `handle`. Re-run 2026-10-09, leave-one-out (bullet removed). claude-opus-5-5 and claude-sonnet-5-5 write `match` in every arm, bare 5/5. claude-haiku-5-5: 15/15 against 12/15, bare 0/5. The rest of CLAUDE.md lifts claude-haiku-5-5 most of the way, and the gap of the bullet (3/15) is unsettled at n=15. Rows: session c7da8904 scratchpad `rv4-core.AbhUPW/raw/` (files p7-*).


## Memory (removed from `CLAUDE.md` 2026-09-23)

Removed in the 2026-09-23 second pass: `## Method notes`, the 2026-09-23 subsection.

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Memory | 6/6/6 | 6/6/6 | fourth saturated probe, still no verdict |

Memory has now failed to separate on four probes across two sessions.

### Add-one-in, 2026-08-15 (design: `## Method notes`)

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Memory | which of two facts to store | 13/16 | 13/16 | **no effect detected, two independent probes** |

Memory is nominated for deletion on that evidence, not deleted: two probes are a smoke test,
and the section costs 65 tokens. Re-probe with a session-summary task before removing it.

## Eywa (removed from `CLAUDE.md` 2026-09-23)

Removed the Eywa section: the hooks are off.

## Skill descriptions: a routing bug, not a token problem

Six routing scenarios, n=3 each on opus, asking only "name the single skill you would invoke". Before: **6/18 correct**. Every failure was consistent at 3/3, so it was systematic, not sampling noise.

| scenario | should reach | actually reached |
| --- | --- | --- |
| hand a task to another agent and walk away | `orca-cli` | `peer-agent` |
| four agents, a DAG, decision gates | `orchestration` | `peer-agent` |
| read an Orca terminal, then send it a command | `orca-cli` | `agent-routing` |
| read the Spotify desktop window and click play | `computer-use` | `switch-playwright` |
| codex implements, you review and gate | `peer-agent` | correct |
| find every caller before a rename | `ecp` | correct |

Three descriptions were claiming work that belongs elsewhere. `peer-agent` absorbed any mention of another agent. `switch-playwright` said "invoke FIRST whenever you want a browser", which pulled in a native desktop app. `agent-routing` claimed "dispatching to another agent or worktree", which pulled in terminal control.

Editing only those three, which are local real directories, takes it to **18/18**. The fix is one rule applied three times: a description states what this skill does, and where a neighbouring case goes, and never claims the neighbour's verb.

- `peer-agent` now ends "If nobody reviews the result it is a handoff, not this skill: use `orca-cli`."
- `switch-playwright` now ends "Not for native desktop apps; those go to `computer-use`."
- `agent-routing` stops claiming concrete actions and points at the skill that owns each one.

Net length change is 128 chars, so this is a correctness fix that happens to be free.

A first attempt also rewrote `orchestration`, `orca-cli` and `computer-use` (3,143 chars down to 1,626, also 18/18). Those three are symlinks into `~/.agents/skills/`, which Orca overwrites from `stablyai/orca`, so the edit cannot survive. See `skill-overlays/README.md`. The whole routing bug turned out to be fixable without them.

`skills/validate-prompt-rules/route.sh` runs this test. It swaps the entire skills tree through `CLAUDE_CONFIG_DIR`, so the only thing that differs between arms is the descriptions, and credentials still resolve because `.credentials.json` is copied into the temp config directory.

## `switch-playwright`, removed 2026-08-15

Orca's embedded browser covers the work, so the skill, `~/.local/bin/switch-pw.sh`, and the
`playwright` entry in `~/.config/mcp/code-executor-minimal.json` are gone (backup:
`~/.claude/backups/switch-playwright-removed/`). The routing table above keeps the skill's name
because that run happened; it is history, not a live reference. Removing it also released the
1,155 MB of playwright-mcp and headless Chrome RSS the skill existed to ration.

## `simplify` skill

### Provenance moved out of the skill 2026-09-23

- Reviewer preamble lists one `ecp impact` command per changed symbol because, measured 2026-09-15, the generic "dig in with ecp" wording produced zero ecp calls across thirteen review agents.
- Free reader (then `nemotron-3-super-120b-a12b:free`), measured 2026-09-11, three trials: located 4 of 5 planted defects from the diff alone, invented every failure_scenario (three different wrong breaks for one generator defect, confidence 93-95), missed a lock held across `requests.get` every time. A context-file second round fixed the scenario every time and added one lead in one trial of three. 52-line diff 4/4 in 40-95 s, clean on a control diff; 2034-line diff 2.3/4; three parallel calls left one hanging past 200 s.

### Preamble reword probe, 2026-09-15 (same A/B as Dispatch, "When to dispatch")

The simplify preamble reword was probed too (list the first six commands): old and new wording both 5/5 on opus and sonnet, so a no-tools probe cannot see the difference; the zero-call result comes from the thirteen agentic transcripts, and only an agentic run can retest it.

### Cross-family is not a judgement call, live failure 2026-09-04

Same session as the `writing-for-agents` pointer failure (2026-09-04), same failure: the tier table's dispatch was executed, and codex was not launched on
a HIGH-risk diff. The trigger sat beside the table as prose, conditioned on a judgement phrase
("expensive enough to want a reader whose mistakes are uncorrelated with yours"), while every
table row keys off a mechanical condition.

Probe: a Tier-1 diff (2 files, 60 lines, no auth/schema/concurrency), ask = the reviewers you
launch. Target = codex named. Control carries the tier table plus "codex is available as an
independent cross-family reviewer", so it CAN hit. n=8 on haiku across two runs.

| arm | haiku |
|---|---|
| control (codex available, no trigger) | 0/8 |
| A: cross-family runs "on top of Tier 3" | 0/8 |
| B: **Cross-family — always.** every tier from 1 up | **7/8** |

B shipped. A scoring 0/8 is correct behaviour for A, not a defect: at Tier 1 the old rule does not
fire by design. What the probe measures is that the new wording reaches even haiku, 7/8.

## Method notes

- 2026-10-09 round 4: seven agents re-ran every status whose evidence predated the claude-opus-5-5, claude-sonnet-5-5 and claude-haiku-5-5 models. No original probe survived, so every probe was rebuilt from its entry. A "changed" verdict compares a rebuilt probe with an old one. Budget cap: no round beyond the one in flight, so several cells stop at n=5 or n=10 as "unsettled".

### The seven unmeasured sections, measured 2026-08-15

Isolated A/B per section: RULE arm loads that section alone, CONTROL arm loads nothing,
`--setting-sources project` from an empty dir, canary passed on every run. opus + haiku.
Probe files under `/tmp/ab7` were throwaway; the design is recorded here.

Rows moved to their sections: Core Philosophy, Proactive Engineering, Surgical Changes, Test Discipline, MCP Tool Calling, Code Style (general), Memory. The probe-design lesson sits under Proactive Engineering.

### Leave-one-out replaces add-one-in, measured 2026-08-21

The 2026-08-15 run above used **add-one-in**: the RULE arm loaded one section alone, the
CONTROL arm loaded nothing. That design gives the wrong answer for a rule that lives inside a
document. Demonstration, on the `colleague-zh` punctuation guardrail: bare opus never reaches
for an arrow (10/10 clean), so add-one-in reads it as a no-op. Remove the guardrail and keep the
rest of the style, and it leaks 0/10 on arrows and 0/10 on em-dashes. **The other paragraphs
create the pressure the guardrail resists.** Deleting it is worse than writing no style at all.

Design that replaces it: `A` = the whole document, `B` = the whole document minus one section,
`control` = bare (a saturation check, never the baseline). `validate.sh`'s `spawn_docs` reads
`<id>.A.md` / `<id>.B.md`, so generate both files from the live file with a script.

Re-run 2026-10-09 on claude-opus-5-5, the original English excerpt arms, n=15 (raw rows: session c7da8904 scratchpad `rv-preload.uNkwUu/`): arrow-chain clean in the bare control 4/15, in the excerpt without the guardrail 14/15, with it 15/15. The 2026-08-21 reversal did not reproduce, and the guardrail's own effect (1/15) is unsettled. The deployed `colleague-zh.md` guardrail uses different, Chinese-mark wording and was not measured.

Deployed style measured 2026-10-09, claude-opus-5-5, one run, n=15 per arm, with the full baseline (CLAUDE.md, RTK.md, ECP.md, language setting): style as deployed / paragraph removed / no style. Arrow chain 15 / 13 / 13 clean. Dash 15 / 15 / 15. A Chinese cause-and-effect answer 15 / 15 / 15. Inert by the rule fixed before the run (A beats B by 2 or less on every probe). All four leaks are 「→」 chains. Not measured: a long session after English tool output, and tables, bullet lists or ranges. Raw rows: session c7da8904 scratchpad `rv-colleague.zZNiJ5/`.

Kept on purpose, 2026-10-09, by the user's decision. Do not delete the paragraph on the single-turn result above. Two things stay unmeasured: a long session that answers after English tool output, and the table, bullet-list and range shapes the paragraph names. Delete it only after a measurement covers both. In a sandbox probe that day, 4 of 5 runs read "unsettled" here and deleted the paragraph without asking.

### CLAUDE.md sections, leave-one-out, n=6 per arm, opus + haiku, POSITION=claude-md

Numbers are hand-scored; the first regex pass misjudged four of eight (it accepted
`git checkout -b` where the section specifies a worktree, and missed "mention the bare `except:`"
because the pattern said "mention it").

Rows moved to their sections: Important Reminders, Prompt Writing Guide, Across rounds, Branch Discipline, Surgical Changes, What a delegate returns, Memory, Search & Read Strategy.

Nothing is deletable.

### Infrastructure failures scored as misses, found 2026-08-14

**Why the wrong claim survived a first check: the harness scored infrastructure failures as misses.** `claude -p ... 2>/dev/null` returning an empty string went into the scorer and came out as a miss. One run put two different arms at exactly 3/10; a re-run of the same files put them at 0/10 and 10/10. Roughly seven calls in ten had failed silently, and both arms were dragged to the same floor, which reads as "no difference between them" rather than as "no data". `ab.sh` now reports `ERR(rc=N)` for a non-zero exit or an all-whitespace reply, and `tourney.sh` excludes those from the denominator and prints a warning. Parallelism dropped from 6 to 3.

Treat any earlier n=3 or n=5 result in this file as provisional for the same reason.

The harness lives in `skills/validate-prompt-rules/`: `ab.sh` (arms x models, parallel, contamination canary, failure detection), `tourney.sh` (aggregates to a Pareto front), `route.sh` (swaps the whole skills tree through `CLAUDE_CONFIG_DIR` to A/B skill descriptions).

### Three new rules, added 2026-08-25 — pilot only, not shipping-grade

Source ideas: Musk's delete/simplify/accelerate/automate ordering and Linus Torvalds' "good
taste" (eliminate a special case by restructuring) and "never break userspace." Not named in
`CLAUDE.md` itself — kept unattributed there, provenance recorded here instead.

The three measurements sit under Core Philosophy, Proactive Engineering and Code Style (general).

**Common thread**: every abstract framing here (the original C wording, the "keeps the same
functionality" precondition in A) tests weaker than a version naming the concrete pattern or
check — same lesson as `name-the-wrong-command` in auto-memory, now measured twice more.

### 2026-09-23 second pass: judged for claude-opus-5-5, not measured

On the user's instruction, a wording measured on claude-opus-5 is no longer frozen: it is re-judged for the current reader, with the word count held level or lower. `CLAUDE.md` 2403 -> 2269 words. Cut: rationale clauses (the Language line's "to cut tokens", the Phase bullet's "spend grows with its square", the blind-spots "a silent gap does not", the Test Discipline "false positives", the benchmark "clean process", the delete-first "wastes it", the Python pointer to this file), the "Calibration belongs in the acceptance criterion" restatement, and the Memory section, which the harness's own auto-memory instructions already state. Red lines and every sentence that closes an escape stay word for word. Pre-pass copies: session f9b48292 scratchpad `cmd/CLAUDE.md.orig`, `cmd/CLAUDE.md.pre-pass2`.
