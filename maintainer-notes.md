# Maintainer notes for `CLAUDE.md`

Measured provenance for the rules in `CLAUDE.md`. None of it is a runtime instruction, so it stays out of the always-loaded file. Read it before you reword or delete a rule there.

## Language / Writing discipline (and the `colleague-zh` output style)

Voice and Word choice moved to `~/.claude/output-styles/colleague-zh.md` on 2026-08-14. The split is by reader, not by topic: an output style reaches the main session only. Read from the 2.1.232 binary — `Jq()` builds the `SN("output_style", …)` section and only `l_e({mainThreadAgentDefinition, …})` consumes it, while a Task sub-agent's prompt comes from `azn([agentPrompt], …)`, which has no such section. `CLAUDE.md` arrives by a different route (`nee()` → `userContext`), so sub-agents still read it.

So: rules about talking to the user go in the style; rules about artifacts a sub-agent writes (Writing discipline, "everything else in English") stay in `CLAUDE.md`. Moving Writing discipline into the style would silently drop it from every sub-agent.

The style's frontmatter needs `keep-coding-instructions: true`. Without it the CLI drops its own default coding-instruction block: `c===null||c.keepCodingInstructions===!0?YCS():null`. (That block did not appear in either arm of a 2026-08-14 A/B on Opus 5, so this build gates it elsewhere too — keep the key anyway, it costs nothing and the gate can change.)

Verified after the move: a headless run answers `# Output Style: colleague-zh` when asked for that heading.

## Commit & PR Authorship

Red line — keep the negative wording; a positive rephrase here weakens the constraint (verified: reworded variant let a model re-add the footer).

**The rule was fighting the harness. `includeCoAuthoredBy: false` removes the fight at its source** (set on 2026-08-14). The CLI injects both attribution texts by default, so the system prompt carried `End git commit messages with: Co-Authored-By: Claude …` in the same session that `CLAUDE.md` said never to add it.

The settings reference's table claims the default is `false`. It is not. Verified against the 2.1.232 binary: the attribution builder returns the trailer and the PR footer unless `includeCoAuthoredBy === false`, and `attribution: {commit, pr}` overrides both texts and outranks it. To re-verify on a later build, start a session and read whether the system prompt still carries the trailer instruction.

The `CLAUDE.md` rule stays for now. Its red-line status was measured while the harness was injecting the opposite instruction, and nothing has been measured without it. Deleting it needs its own A/B against the model's own prior, on more than one model: the injection is gone, the training prior for `🤖 Generated with Claude Code` is not.

## Dispatch (Cost-Aware, Adaptive)

Red line — keep this wording. The CLI's default prompt bars dispatch unless the user asks, and that bar wins by default. Isolated A/B on Opus 5 (n=3, `--setting-sources project`): this wording dispatches 3/3; the softer "you may dispatch sub-agents when it would help" dispatches 0/3, same as no rule.

## When to dispatch

Deliberately absent: a "delegate the big read" rule, and a worktree-isolation rule. The cost arithmetic supports the first (a haiku delegate repays its own ~10k prefix reload once it reads past ~6.5k tokens), but five wordings measured neutral-to-harmful on Opus 5: it already delegates a genuine bulk read unprompted (3/3) and already prefers a targeted grep over delegating a lookup (3/3), and every threshold wording broke that second case. It also already sets `isolation: "worktree"` on parallel writers unprompted (3/3). Don't re-derive the arithmetic and re-add either rule.

## Search & Read Strategy, point 4

Compressed from 673 to 359 chars on 2026-08-14. The cut removed the justification prose (the proxy-of-proxy argument, the "no giant function" aside) and kept the probe-to-goal mapping.

Cross-model A/B, n=3 on each of opus, sonnet and haiku. Scenario: "find which modules in a Python repo are the riskiest to change; ruff, an AST parser and `ecp` are installed", asking for the single command to run first. Target: `ecp impact` fan-in.

- control 0/9. Every model invents a plausible command instead: `ecp analyze --metric indegree`, `ecp graph --metric churn-x-coupling`, `ecp metrics`.
- full 673-char version 9/9.
- compressed 359-char version 9/9.

The mapping carries the behaviour. The argument for it carries none, which agrees with the earlier finding that a rationale clause appended to a rule is inert.

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

## Dispatch, "Model and effort"

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

**Why the wrong claim survived a first check: the harness scored infrastructure failures as misses.** `claude -p ... 2>/dev/null` returning an empty string went into the scorer and came out as a miss. One run put two different arms at exactly 3/10; a re-run of the same files put them at 0/10 and 10/10. Roughly seven calls in ten had failed silently, and both arms were dragged to the same floor, which reads as "no difference between them" rather than as "no data". `ab.sh` now reports `ERR(rc=N)` for a non-zero exit or an all-whitespace reply, and `tourney.sh` excludes those from the denominator and prints a warning. Parallelism dropped from 6 to 3.

Treat any earlier n=3 or n=5 result in this file as provisional for the same reason.

The shipped block keeps the standalone sentence even though the shortest 10/10 arm drops it, because that sentence also carries the pointer to `agent-routing` and the cross-reference to *When to dispatch*, and this probe measures neither.

Where the optimisation stopped: further cuts would have to trim the ladder rows' example lists, and the probe scenario was written from those examples. Cutting them would measure the probe, not the rule.

The harness lives in `skills/validate-prompt-rules/`: `ab.sh` (arms x models, parallel, contamination canary, failure detection), `tourney.sh` (aggregates to a Pareto front), `route.sh` (swaps the whole skills tree through `CLAUDE_CONFIG_DIR` to A/B skill descriptions).

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

## Python, the `except A, B:` red line

The rule in `CLAUDE.md` points at `pyci-check syntax` instead of restating the parser behaviour. Both halves were re-verified on 2026-08-15:

- `pyci-check` runs on its own uv tool venv, Python **3.14.6**. `pyci_check/syntax.py` calls `ast.parse` there, so a file holding `except ValueError, TypeError:` returns `✓ All files have correct syntax`, exit 0.
- `ruff 0.16.0`, `ruff format --target-version py314 --diff` on `except (ValueError, TypeError):` emits `-except (ValueError, TypeError):` / `+except ValueError, TypeError:`. Parens added by a reviewer get stripped again by the pre-commit hook.

So the check is not a proxy for the rule; it is the rule. A reviewer that disagrees with `pyci-check syntax` is wrong about the Python version it is reading, not about the code.

## `switch-playwright`, removed 2026-08-15

Orca's embedded browser covers the work, so the skill, `~/.local/bin/switch-pw.sh`, and the
`playwright` entry in `~/.config/mcp/code-executor-minimal.json` are gone (backup:
`~/.claude/backups/switch-playwright-removed/`). The routing table above keeps the skill's name
because that run happened; it is history, not a live reference. Removing it also released the
1,155 MB of playwright-mcp and headless Chrome RSS the skill existed to ration.


## The seven unmeasured sections, measured 2026-08-15

Isolated A/B per section: RULE arm loads that section alone, CONTROL arm loads nothing,
`--setting-sources project` from an empty dir, canary passed on every run. opus + haiku.
Probe files under `/tmp/ab7` were throwaway; the design is recorded here.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Code Style (general) | `match` over an if/elif chain on four string values | 6/6 | 0/6 | load-bearing |
| Proactive Engineering | next action after fixing a None-deref | 10/10 | 1/10 | load-bearing |
| MCP Tool Calling | one production SQL query | 6/6 | 1/6 | load-bearing |
| Test Discipline | order of actions on a reproduced bug | 6/6 | 3/6 | load-bearing |
| Core Philosophy | dedup 10M strings, first-seen order | 8/10 | 5/10 | load-bearing on opus (3v0); haiku already does it |
| Surgical Changes | "retry an HTTP GET a few times", nothing specified | 9/10 | 7/10 | weak, opus-only (4v2) |
| Memory | which of two facts to store | 13/16 | 13/16 | **no effect detected, two independent probes** |

Probe design matters more than n. Proactive Engineering first measured 6/6 vs 6/6 on a probe
that asked "what do you do about the other three?" — the question already carried the decision.
Rewritten to "state your single next action", the same section separates 10/10 vs 1/10.
A null result on a probe whose control cannot fail says nothing.

Memory is nominated for deletion on that evidence, not deleted: two probes are a smoke test,
and the section costs 65 tokens. Re-probe with a session-summary task before removing it.

## Leave-one-out replaces add-one-in, measured 2026-08-21

The 2026-08-15 table above used **add-one-in**: the RULE arm loaded one section alone, the
CONTROL arm loaded nothing. That design gives the wrong answer for a rule that lives inside a
document. Demonstration, on the `colleague-zh` punctuation guardrail: bare opus never reaches
for an arrow (10/10 clean), so add-one-in reads it as a no-op. Remove the guardrail and keep the
rest of the style, and it leaks 0/10 on arrows and 0/10 on em-dashes. **The other paragraphs
create the pressure the guardrail resists.** Deleting it is worse than writing no style at all.

Design that replaces it: `A` = the whole document, `B` = the whole document minus one section,
`control` = bare (a saturation check, never the baseline). `validate.sh`'s `spawn_docs` reads
`<id>.A.md` / `<id>.B.md`, so generate both files from the live file with a script.

### CLAUDE.md sections, leave-one-out, n=6 per arm, opus + haiku, POSITION=claude-md

Numbers are hand-scored; the first regex pass misjudged four of eight (it accepted
`git checkout -b` where the section specifies a worktree, and missed "mention the bare `except:`"
because the pattern said "mention it").

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Important Reminders | 0/0/6 | 0/0/6 | load-bearing, both models |
| Prompt Writing Guide | 0/0/6 | 0/0/6 | load-bearing, both models |
| Across rounds | 0/0/6 | 0/1/5 | load-bearing, both models |
| Branch Discipline | 0/0/6 | 0/0/4 | load-bearing |
| Surgical Changes | 0/0/6 | 2/5/6 | opus load-bearing; haiku does not separate |
| What a delegate returns | 6/6/6 | 0/0/6 | opus saturated, haiku load-bearing |
| Memory | 6/6/6 | 6/6/6 | fourth saturated probe, still no verdict |
| Search & Read | invalid | invalid | third broken probe design |

Nothing is deletable. Branch Discipline is not about branching at all: every arm branches, and
only the section produces `git worktree add`, the `fix/` prefix and an explicit base.
*What a delegate returns* repeats the Word choice pattern above — inert on the strongest reader,
100% on the weakest: haiku without it answers "Delete scripts/backfill.py." 6/6.

Memory has now failed to separate on four probes across two sessions. Search & Read has failed
three designs; the last two were mine (one asked a code-structure question that `ECP.md` owns,
one said "a path you already know" and supplied no path).

### Prompt Writing Guide, compressed 1,111 → 704 chars

Five probes, A = compressed, B = current, n=6 per arm on opus and haiku. Every probe ties.
Two bullets are confirmed load-bearing and both survive: positive phrasing (opus control 0/6,
haiku control 0/6, both arms 6/6 and 5/6) and abstract-rules-first (haiku control 3/6, both arms
6/6; saturated on opus). The other three probes measure nothing in either version.

## `colleague-zh` Voice, the turn-ending sentence

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
"a name needs two mentions" above. The negative wording is deliberate: this prior is strong
enough that bare opus announces 12/12, which is the condition `writing-for-agents` names for
keeping an explicit negative.

Removed on the same evidence: a `**Tool calls fire direct.**` paragraph added to the style that
same day. Against the rest of the style it scored 20/20 vs 18/20 at n=20 (p=0.24), while bare
opus scored 2/20 — redundant against the document, not against the model.

## Proactive Engineering, the regex bullet, extended 2026-08-21

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

## Test Discipline, reworded 2026-08-24 — pilot only, not shipping-grade

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
holds to; the 2026-08-15 add-one-in run above (6/6 vs 3/6) is the only shipping-grade measurement
this section has ever had, and it was never re-run against this specific new wording. Re-probe at
n≥15 before treating the swap as settled.

## Three new rules, added 2026-08-25 — pilot only, not shipping-grade

Source ideas: Musk's delete/simplify/accelerate/automate ordering and Linus Torvalds' "good
taste" (eliminate a special case by restructuring) and "never break userspace." Not named in
`CLAUDE.md` itself — kept unattributed there, provenance recorded here instead.

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

**Common thread**: every abstract framing here (the original C wording, the "keeps the same
functionality" precondition in A) tests weaker than a version naming the concrete pattern or
check — same lesson as `name-the-wrong-command` in auto-memory, now measured twice more.
