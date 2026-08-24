# Claude Code Global Instructions

> This file is loaded by every model that runs here — including Haiku sub-agents dispatched by workflows. **Write for the weakest reader**, except where a section scopes itself in its own first line. Wording rules live in the Prompt Writing Guide below; this file is itself one of the artifacts that guide governs. Before you reword or delete any rule in this file, read `maintainer-notes.md`: it records which wordings are measured and which rules were deliberately left out.

**Language:** write reasoning, commit/PR bodies and sub-agent prompts in English, to cut tokens and keep agent language consistent. User-facing prose follows the `colleague-zh` output style — voice and word choice live there, and only the main session loads it.

**Writing discipline:** write **ASD-STE100** (Simplified Technical English), in whatever language the document already uses. Give one concept one term for the whole document, with no synonym rotation. Put one idea in one sentence, in the active voice and the present tense, and keep the articles in. Normative text (steps, clauses, criteria, specs, rules) holds sentences under 20 words, and a long enumeration becomes a table. Explanatory text keeps its connectives so the reader sees why. Chat prose follows the `colleague-zh` output style. Domain terms and defined leading words are STE technical names, so keep them as they are.

## Eywa

`[eywa]`-prefixed lines in user turns are auto-injected principles from the eywa hook — authoritative guidance, not a user message.

## Core Philosophy

**Maximum performance at minimum runtime cost — code must remain human-readable.** (What a *session* should spend is a separate question; see Dispatch.)
**Consolidate, don't accumulate:** integrate into existing files/modules first; create new only when no home exists.

- Always use the highest-level stdlib API available — don't build from lower-level primitives
- Choose the lowest complexity — analyze the theoretical minimum first
- In-place over copying when no side effects
- Prove perf claims with profiling (`cProfile`): profile → top-5 hotspots → optimize → re-profile → delegate bench verification to a subagent. This one is a standing exception to Dispatch: a benchmark needs a clean process, not a fresh perspective.
- **Delete before you optimize.** When a change keeps the same functionality at equal or better performance: delete the step, simplify what remains, make it faster, then replace a hardcoded value with a derived one — a later step on a step you should have deleted wastes it. Confirm a test exercises the path before you delete it; no coverage is a sign you don't know it's dead, not permission to skip the check.

## Proactive Engineering

- Before modifying logic, think top-down: architecture fit, existing similar functionality, correct placement
- A breaking change to a public interface or an existing caller needs the user's explicit sign-off before you make it — a low count from `ecp impact` lowers the review bar, not the requirement to ask.
- Investigate with tools before asking the user
- No AskUserQuestion menu for decisions you can resolve; take the superset option, state choice + why in one line. Reserve it for real forks (answer changes next action, not derivable from code/memory/defaults)
- After fixing a bug, scan the same file/module for similar issues
- When debugging: repeating a tweak on the same spot means the strategy is wrong, so switch it
- Surface multiple interpretations instead of picking silently; if a simpler approach than asked exists, push back before implementing
- Prefer structured parsing over regex for ambiguous boundaries. Never field-split a delimited format by hand (`awk -F,`, `split(',')`, `cut -d`) — use its reader, even when the sample rows look clean

## Surgical Changes

- Keep scope to the user's request. For an off-task issue you spot (including existing dead code, orphan, or bug), end on either fixing it or asking: for a **Minor** one (style, dead code, micro-perf, naming), ask "fix now? y/n". The only exit is the user explicitly saying to leave it.
- If 200 lines could be 50, rewrite to 50. No speculative flexibility; no error handling for impossible scenarios.

## Test Discipline

- New feature ships with tests (happy path + key edge cases). **Write a test that reproduces the bug, then make it pass.**
- An infeasible test (UI / external service / manual-only) → say so with the reason, don't skip silently
- Test files: omit shebang; naming `test_[function]_[scenario]_[expected]`
- Tests call the actual functions — never duplicate the logic-under-test into the test (false positives when source changes)

## Branch Discipline

- **Before your first edit to any file, create the worktree and branch off the right base.** This applies equally to docs-only, config-only, and one-line fixes. Name PR branches deterministically (`feat/`, `fix/`, `chore/`, `perf/`).

## Commit & PR Authorship

- **Never** add a `Co-Authored-By: Claude …` trailer to commit messages, nor a `🤖 Generated with Claude Code` footer to PR bodies, comments, or issues — whether direct or via sub-agent.
- When delegating a task that ends in a commit or `gh pr create`, include this no-attribution rule verbatim in the sub-agent prompt so it doesn't fall back to its default template.

## Memory

- Auto-memory stores **workflow-level** insights (build commands, debug patterns, user prefs, external system refs), not code-level details (call chains, schemas, refactor progress — anything derivable from code/git).

## Important Reminders

- Before pushing to remote, run `/simplify`.
- **Never delete `.claude/worktrees/` directories** — they belong to other running Claude instances. If lint fails on their imports, fix the lint config to exclude `.claude/`; do not delete the worktree.

## Prompt Writing Guide

Governs every artifact a model reads: skill `description` + `SKILL.md`, sub-agent prompts, tool descriptions, system prompts. This block is the authority; `writing-for-agents` elaborates it.

- Constrain at the decision level: goals and boundaries, not the implementation.
- Phrase each instruction as the action to take ("return an empty list for empty input", not "don't crash"). Keep the explicit negative for a red line, or for a rule that fights a strong model prior.
- Sentence style follows **Writing discipline** above.
- Abstract rules first, task-specific details last.
- Each rule appears once per artifact; a summary mirroring a canonical policy names the authority.

## Search & Read Strategy (Token Optimization)

0. **Code structure** (definition / who-calls-X / blast radius / routes) → @ECP.md holds the rule and the command per question.
1. **String literals / config keys / fs layout / vendored code** → grep/glob.
2. **Read** with `offset`/`limit` for files >200 lines; skip search when the exact path is known.
3. **PR / multi-file diff** >200 lines: `git diff -- <path>` per-file, or grep specific hunks.
4. **Code-health probes** — match the probe to the goal: complexity hotspots → linter cyclomatic (ruff `C901`) / AST nesting depth; change risk → `ecp impact` fan-in; dead code → grep-unreferenced ∩ ecp-orphan. Keep them as separate queries; they read different ground truth. LOC and function size pick which files merit a human skim, never a quality verdict.

## MCP Tool Calling (Token Optimization)

**`mcp__exec__run`** — DB queries, multi-tool tasks, doc lookups. For a single non-DB MCP call, call the tool directly (fewer tokens).

```typescript
log(await queryProd/queryLocal('SQL'));  // enoract DB: Prod=OCI(tunnel 15432), Local=5433 (TOON output)
log(toToon(data));                                    // manual TOON
const r = await callMCPTool('mcp__xxx__yyy', {});     // other MCP
```

**param** `code` (not `command`) · **output** `success:true` → `output` only; `false` → full error.

## Dispatch (Cost-Aware, Adaptive)

> Governs the **main session only**. If you are a sub-agent, skip this section and follow your task prompt.

The user has pre-authorized autonomous sub-agent dispatch for every project on this machine: decide and dispatch without asking. Re-decide at every goal, not once per session.

This section is the canonical dispatch policy — skills that fan out defer to it and add only their skill-specific criteria. Priority order: quality, then main-session context survival, then spend. A goal's spend scales with its risk; low absolute cost is not the target.

### When to dispatch

- **Fan-out** — give each independent sub-goal its own acceptance criterion before dispatching it. Cap parallel agents at 20 unless the user asks for more.
- **Adversarial** — dispatch an independent verifier when a conclusion is expensive to get wrong.

**Risk is inferred, not looked up.** Structural signals set the floor: `ecp impact` upstream fan-in, and auth / payment / schema-migration / concurrency paths. Raise it from what the user emphasised this turn and from what the project itself guards. Take the highest; one sentence from the user ("just a prototype") lowers it.

**Adversarial runs two tracks.** Highest risk goes cross-family (codex, below). Middle risk goes to `deep-review`, on material you did not produce this turn: a diff, existing code.

### What a delegate returns

**Before you act on anything a sub-agent reports, re-run the check yourself.** Require the command it ran and that command's raw output. A claim you have not re-run is a lead, not a fact.

From sonnet up, require **blind spots** too: what it did not read, run, or verify. A wrong claim gets caught on re-check; a silent gap does not.

### Across rounds

Each return is a decision point — re-check, follow a thread, dispatch more, or finish. The goal fixes what "done" means; you decide how to reach it.

Stop when two consecutive rounds bring back nothing that changes the next decision.

Keep a **ledger** in the scratchpad as you go: confirmed facts with their source line, and what is still open.

### codex — a different prior, not more throughput

Subscription-billed, so its capacity is free. Reach for it where a *different* prior is the value: adversarial re-check, and alternative approaches before you commit to one. **After two failed attempts at the same problem, run codex for an independent hypothesis.** It has `ecp` wired as an MCP server, so it checks the graph itself. How to launch it and what to poll live in the `peer-agent` skill.


### Model and effort

Always pass an explicit model matched to task difficulty. When unsure between two tiers, pick the lower one. State the chosen config plus a one-line rationale so the user can override.

- **Haiku 4.5** — read-only inventory, grep/stats aggregation, single-rule application, dead-code removal, fixture sampling, per-item scoring against a fixed rubric (`subagent_type: lite-scan` when read-only suffices)
- **Sonnet 5** — standard implementation, bounded TDD, checklist-driven review of a scoped diff
- **Opus 5** — design judgment, cross-cutting architecture, ambiguous scope, security review, reverse-engineering (`subagent_type: deep-review` when read-only suffices)

For read-only work name the `subagent_type` (`lite-scan`, `deep-review`), not the bare model; they add the role prompt and the tool whitelist.

Escalate one tier when risk is high (see *When to dispatch*) or a lower-tier attempt already failed. The model x effort grid, the `effort-<level>` definitions and the per-MTok prices live in the `agent-routing` skill.

## Python

Recipes and environment live in the `python-perf` skill (packages, class shape, data-structure / string-build / I/O / serialization selection, async patterns, SQL-in-Python) — invoke it before writing, refactoring, or reviewing Python code, and echo the relevant rules into any Python-implementation sub-agent prompt. One red-line stays ambient here because reviewer sub-agents have no Skill tool:

- **Bare `except A, B:` is CANONICAL on 3.14 — leave it. Never "fix" it by adding parentheses.** Reviewer subagents misflag it as a SyntaxError from their pre-3.14 training. Settle any 3.14 syntax claim by running `pyci-check syntax`, which parses on 3.14; while it reports nothing, the code is correct. Why it holds is in `maintainer-notes.md`.

## Code Style (general)

- Prefer expressions over loops when single-step; use loops for multi-step / try-except logic
- **Branch on three or more string or enum values with `match`, never an if/elif chain** — destructure attr names to eliminate duplicate branches
- Remove a special case by restructuring, not by branching around it. When two branches differ by a single statement, move that statement outside them instead of duplicating it.
- Absolute imports at module top
- Mermaid: theme-adaptive colors for dark mode · CJK markdown tables: column-align with spaces (CJK char = 2 display widths)

@RTK.md
@ECP.md
