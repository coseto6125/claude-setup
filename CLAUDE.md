# Claude Code Global Instructions

> This file is loaded by every model that runs here — including Haiku sub-agents dispatched by workflows. **Write for the weakest reader**, except where a section scopes itself in its own first line. Before you reword or delete any rule in this file, read that rule's section of `maintainer-notes.md`, found through the Index at its top: it records which wordings are measured and which rules were deliberately left out.

**Language:** write your thinking, commit/PR bodies and briefs (sub-agent prompts) in English. Every text block the user sees is user-facing prose, including a one-line note between tool calls. The `colleague-zh` output style sets its language, voice and word choice, and only the main session loads it.

**Writing discipline:** write **ASD-STE100** (Simplified Technical English), in whatever language the document already uses. One term per concept, document-wide. Put one idea in one sentence, in the active voice and the present tense, and keep the articles in. Normative text (steps, clauses, criteria, specs, rules) holds sentences under 20 words, and a long enumeration becomes a table. Explanatory text keeps its connectives so the reader sees why. Domain terms and defined leading words are STE technical names, so keep them as they are.

## Core Philosophy

**Maximum performance at minimum runtime cost — code must remain human-readable.** (Session spend: see Dispatch.)
**Consolidate, don't accumulate:** integrate into existing files/modules first; create new only when no home exists.

- Always use the highest-level stdlib API available — don't build from lower-level primitives
- Choose the lowest complexity — analyze the theoretical minimum first
- In-place over copying when no side effects
- Prove perf claims with profiling (`cProfile`): profile → top-5 hotspots → optimize → re-profile → delegate bench verification to a subagent. Paste this check into its brief: "Removing a piece that takes 10% of the run makes the run at most about 11% faster. A result past the bound measured a cache, a no-op or a bug." This is a standing exception to Dispatch.
- **Delete before you optimize.** When a change keeps the same functionality at equal or better performance: delete the step, simplify what remains, make it faster, then replace a hardcoded value with a derived one. Confirm a test exercises the path before you delete it. No coverage means unknown, not dead.

## Proactive Engineering

- Before modifying logic, think top-down: architecture fit, existing similar functionality, correct placement
- Before the first edit on work that leaves this machine, list every place a reader could inspect, and the check for each.
- Before a breaking change, apply the breaking-change rule in `ECP.md`. An upgrade that runs by itself, such as a format version that triggers an automatic rebuild, usually needs no question. Verify that it leaves no old data behind, and report the rebuild and that check.
- Investigate with tools before you ask. For a decision you can resolve, take the superset option and state choice + why in one line. Reserve an AskUserQuestion menu for a real fork: the answer changes the next action and no code, memory or default settles it
- After fixing a bug, scan the same file/module for similar issues
- When debugging: a second tweak on the same spot means switch strategy
- Surface multiple interpretations instead of picking silently. When a simpler approach than the one the user asked for exists, push back and wait for the answer before you implement either one
- Prefer structured parsing over regex for ambiguous boundaries. Never field-split a delimited format by hand (`awk -F,`, `split(',')`, `cut -d`) — use its reader, even when the sample rows look clean

## Surgical Changes

- Keep scope to the user's request. For an off-task issue you spot (including existing dead code, orphan, or bug), end on either fixing it or asking. A bug with a small, local fix: fix it and report the fix. A bug whose fix is large or changes behaviour that others rely on: ask, and include the fix you propose. For a **Minor** one (style, dead code, micro-perf, naming), ask "fix now? y/n". The only exit is the user explicitly saying to leave it.
- If 200 lines could be 50, rewrite to 50. No speculative flexibility; no error handling for impossible scenarios.

## Test Discipline

- New feature ships with tests. Before the test list is complete, name each input's atypical states and each dependency's failure. Every state named is a test. **Write a test that reproduces the bug, then make it pass.**
- An infeasible test (UI / external service / manual-only) → say so with the reason, don't skip silently
- Test files: omit shebang; naming `test_[function]_[scenario]_[expected]`
- Tests call the actual functions — never duplicate the logic-under-test into the test

## Branch Discipline

- **Before your first edit to any file, create the worktree and branch off the right base.** This applies equally to docs-only, config-only, and one-line fixes. Name PR branches deterministically (`feat/`, `fix/`, `chore/`, `perf/`).

## Commit & PR Authorship

- **Never** add a `Co-Authored-By: Claude …` trailer to commit messages, nor a `🤖 Generated with Claude Code` footer to PR bodies, comments, or issues — whether direct or via sub-agent.
- When delegating a task that ends in a commit or `gh pr create`, include this no-attribution rule verbatim in the brief.

## Important Reminders

- Before pushing to remote, run `/simplify`.
- **Never run `rm -rf` / `rm -r` on a path built from a variable or a glob.** Delete only named files by literal absolute path, and only files you created. When a step needs an empty directory, create a new one: `mktemp -d "<scratch dir>/name.XXXXXX"`, or move the old one aside with `mv` first. `mkdir -p` into a directory that may already exist mixes in its old files. When you delegate shell work to an agent that does not load this file, such as codex, paste this rule verbatim into its brief.
- **Never delete `.claude/worktrees/` directories** — they belong to other running Claude instances. If lint fails on their imports, fix the lint config to exclude `.claude/`; do not delete the worktree.
- **Before you write a loop that waits for another process,** start that process as a background call and act on its completion notification. In a sub-agent, run it in the foreground instead, in steps that each end within the 10-minute Bash timeout: a completion notification never wakes an idle sub-agent. Never poll with `pgrep -f '<its command>'`: the pattern matches the loop's own command line, so the loop never ends. End a turn only when the work is done or blocked, never to report progress. When you delegate shell work, paste this rule into the brief.

## Prompt Writing Guide

Governs every artifact a model reads: skill `description` + `SKILL.md`, briefs, tool descriptions, system prompts. This block is the authority for a line you write in passing. **Invoke `writing-for-agents` before you write, edit or review one of those artifacts as the task itself.** It carries the levers this block does not: the information hierarchy, progressive disclosure, completion criteria, the seven review modes, and `audit.py`.

- Constrain at the decision level: goals and boundaries, not the implementation.
- Phrase each instruction as the action to take ("return an empty list for empty input", not "don't crash"). Keep the explicit negative for a red line, or for a rule that fights a strong model prior.
- Sentence style follows **Writing discipline** above.
- Abstract rules first, task-specific details last.
- Each rule appears once per artifact; a summary mirroring a canonical policy names the authority.

## Search & Read Strategy (Token Optimization)

0. **Code structure** (definition / who-calls-X / blast radius / routes) → @ECP.md holds the rule and the command per question.
1. **String literals / config keys / fs layout / vendored deps (`node_modules/`, `.venv/`)** → grep/glob.
2. **Read** with `offset`/`limit` for files >200 lines; skip search when the exact path is known.
3. **PR / multi-file diff** >200 lines: `git diff -- <path>` per-file, or grep specific hunks.
4. **Code-health probes** — match the probe to the goal: complexity hotspots → linter cyclomatic (ruff `C901`) / AST nesting depth; change risk → `ecp impact` fan-in; dead code → grep-unreferenced ∩ ecp-orphan. Keep them as separate queries. LOC and function size pick which files merit a human skim, never a quality verdict.

## Tool Call Batching (Token Optimization)

- **Never issue two independent Bash calls.** Join them with `;` in one call. The probing trio you reach for first — `pwd; ls; git status` — is one call, not three.
- **Screenshot tokens scale with pixel area** (≈ W×H/784; a long edge over 2576px, or 1568px on Haiku, is downscaled first). Resize to cut them. PNG compression saves nothing. Tile a multi-page sweep into one contact sheet rather than reading N images.

## MCP Tool Calling (Token Optimization)

**`mcp__exec__run`** — DB queries, multi-tool tasks, doc lookups. For a single non-DB MCP call, call the tool directly (fewer tokens).

```typescript
log(await queryProd/queryLocal('SQL'));  // project DB helpers (TOON output)
log(toToon(data));                                    // manual TOON
const r = await callMCPTool('mcp__xxx__yyy', {});     // other MCP
```

**param** `code` (not `command`) · **output** `success:true` → `output` only; `false` → full error.

## Dispatch (Cost-Aware, Adaptive)

> Governs the **main session only**. If you are a sub-agent, skip this section and follow your task prompt.

The user has pre-authorized autonomous sub-agent dispatch for every project on this machine: decide and dispatch without asking. Re-decide at every goal, not once per session.

This section is the canonical dispatch policy — skills that fan out defer to it and add only their skill-specific criteria. Priority order: quality, then main-session context survival, then spend. A goal's spend scales with its risk; low absolute cost is not the target.

### When to dispatch

- **Fan-out** — give each independent sub-goal its own acceptance criterion before dispatching it. Cap parallel agents at 20 unless the user asks for more. **Never open one of the targets yourself to calibrate the fan-out.** Dispatch first; if the returns show the criterion was wrong, fix the criterion and re-dispatch. When three or more of those agents will read the same files, dispatch one exploration agent first. It writes a code map to the scratchpad, and every brief points at that map.
- **Adversarial** — dispatch an independent verifier when a conclusion is expensive to get wrong. Before you call a deliverable ready to send to an outside reader, when it carries claims you took from documentation or code (versions, dates, steps the reader must run), dispatch the cross-family verifier on it.
- **Phase** — an implementer runs one phase: write, or make the tests pass, or fix the audit findings. A fresh agent takes the next phase through one hand-off file in the scratchpad. Size each phase to its kind's context target: a research or spec phase 150k, a write phase 200k, a test-and-fix phase 250k. A transcript that ended more than 50k above its phase's target is the signal to split the next brief finer.

**Risk is inferred, not looked up.** Structural signals set the floor: `ecp impact` upstream fan-in, and auth / payment / schema-migration / concurrency paths. Raise it from what the user emphasised this turn and from what the project itself guards. Take the highest; one sentence from the user ("just a prototype") lowers it.

**Adversarial runs two tracks.** Highest risk goes cross-family (codex, below). Middle risk goes to `deep-review`, on material you did not produce this turn: a diff, existing code.

### What a delegate returns

**A delegate's claim is a lead until you re-run its command.** Require the command it ran and its raw output. Every count comes from that output, never a hand tally.

From sonnet up, require **blind spots** too: what it did not read, run, or verify.

### Across rounds

Each return is a decision point — re-check, follow a thread, dispatch more, or finish. The goal fixes what "done" means; you decide how to reach it.

Before the second round's dispatch, write `"subagentPromptCacheTtl": "1h"` into the project's `.claude/settings.local.json`, never `~/.claude/settings.json`. It applies to the next dispatch with no restart.

Stop when two consecutive rounds bring back nothing that changes the next decision.

Keep a **ledger** in the scratchpad as you go: confirmed facts with their source line, and what is still open.

### codex — a different prior, not more throughput

Subscription-billed, so its capacity is free. Reach for it where a *different* prior is the value: adversarial re-check, and alternative approaches before you commit to one. **After two failed attempts at the same problem, run codex for an independent hypothesis.** Its `~/.codex/AGENTS.md` routes code structure to the `ecp` CLI, so it checks the graph itself. How to launch it and what to poll live in the `peer-agent` skill.

### Model and effort

Always pass an explicit model matched to task difficulty. When unsure between two tiers, pick the lower one. State the chosen config plus a one-line rationale so the user can override.

- **Haiku** — read-only inventory, grep/stats aggregation, single-rule application when the rule lists its instances, dead-code removal, fixture sampling, per-item scoring against a fixed rubric (`subagent_type: lite-scan` when read-only suffices)
- **Sonnet** — standard implementation with the reuse or extraction named in the brief, bounded TDD, checklist-driven review of a scoped diff
- **Opus** — design judgment, cross-cutting architecture, ambiguous scope, security review, reverse-engineering (`subagent_type: deep-review` when read-only suffices)

For read-only work name the `subagent_type` (`lite-scan`, `deep-review`), not the bare model.

A Haiku or Sonnet implementer gets the edge list pasted into its prompt: empty · absent · list-for-scalar · whitespace-only string · dependency down · concurrent duplicate call · machine-parsed output.

A brief names the function or the line range for every file over 200 lines it sends the agent to, so the agent reads it with `offset`/`limit` and never the whole file. It also pastes the batching instances: `cd` and the command after it are one call, and consecutive grep, sed and test runs are one call.

Escalate one tier when risk is high (see *When to dispatch*) or a lower-tier attempt already failed. The model x effort grid, the `effort-<level>` definitions and the per-MTok prices live in the `agent-routing` skill.

## Python

Recipes and environment live in the `python-perf` skill — invoke it before writing, refactoring, or reviewing Python code, and echo the relevant rules into any Python-implementation brief. One red-line stays ambient here because reviewer sub-agents have no Skill tool:

- **Bare `except A, B:` is CANONICAL on 3.14 — leave it. Never "fix" it by adding parentheses.** Reviewer subagents misflag it as a SyntaxError from their pre-3.14 training. Settle any 3.14 syntax claim by running `pyci-check syntax`, which parses on 3.14; while it reports nothing, the code is correct.

## Code Style (general)

- Prefer expressions over loops when single-step; use loops for multi-step / try-except logic
- **Branch on three or more string or enum values with `match`, never an if/elif chain** — destructure attr names to eliminate duplicate branches
- Remove a special case by restructuring, not by branching around it. When two branches differ by a single statement, move that statement outside them instead of duplicating it.
- Absolute imports at module top
- Mermaid: theme-adaptive colors for dark mode · CJK markdown tables: column-align with spaces (CJK char = 2 display widths)

@RTK.md
@ECP.md
