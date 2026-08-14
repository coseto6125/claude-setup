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

`switch-playwright` was measured here but does not ship in this repo. It drove a private HTTP MCP, so it went out with the rest of that material. The rule it demonstrates still holds for the descriptions that remain.

A first attempt also rewrote `orchestration`, `orca-cli` and `computer-use` (3,143 chars down to 1,626, also 18/18). Those three are symlinks into `~/.agents/skills/`, which Orca installs and overwrites from `stablyai/orca`, so the edit cannot survive and they are not published here. To override one of their rules, quote the sentence inside `agent-routing` and declare the exception there: `anchors.txt` holds the quoted sentences and `check-anchors.sh` re-checks them against the guide Orca actually ships. The whole routing bug turned out to be fixable without them.

Orca does not refresh those three on a schedule of its own. On 2026-08-15 all three sat three weeks behind the running app: `orchestration` still read the terminal handle from `startupTerminal.handle` where the shipped guide reads `agentTerminalHandle` first, and `orca-cli`'s description had lost the artifact triggers that decide whether it gets picked at all. That second one is why descriptions get checked before bodies. A stale body misinforms a skill that was already invoked; a stale description stops the invocation happening. `orca skills update` refuses to run from a shell that forwards to an Orca host on another machine, so the comparison is manual: `diff <(orca-ide skills get <name>) ~/.agents/skills/<name>/SKILL.md`.

`skills/validate-prompt-rules/route.sh` runs this test. It swaps the entire skills tree through `CLAUDE_CONFIG_DIR`, so the only thing that differs between arms is the descriptions, and credentials still resolve because `.credentials.json` is copied into the temp config directory.

## Python, the `except A, B:` red line

The rule in `CLAUDE.md` points at `pyci-check syntax` instead of restating the parser behaviour, so the tool has to be installed for the rule to land: [coseto6125/pyci-check](https://github.com/coseto6125/pyci-check). Both halves were re-verified on 2026-08-15:

- `pyci-check` runs on its own uv tool venv, Python **3.14.6**. `pyci_check/syntax.py` calls `ast.parse` there, so a file holding `except ValueError, TypeError:` returns `✓ All files have correct syntax`, exit 0.
- `ruff 0.16.0`, `ruff format --target-version py314 --diff` on `except (ValueError, TypeError):` emits `-except (ValueError, TypeError):` / `+except ValueError, TypeError:`. Parens added by a reviewer get stripped again by the pre-commit hook.

So the check is not a proxy for the rule; it is the rule. A reviewer that disagrees with `pyci-check syntax` is wrong about the Python version it is reading, not about the code.

## `switch-playwright`, removed 2026-08-15

Orca's embedded browser covers the work, so the skill, `~/.local/bin/switch-pw.sh`, and the
`playwright` entry in `~/.config/mcp/code-executor-minimal.json` are gone (backup:
`~/.claude/backups/switch-playwright-removed/`). The routing table above keeps the skill's name
because that run happened; it is history, not a live reference. Removing it also released the
1,155 MB of playwright-mcp and headless Chrome RSS the skill existed to ration.
