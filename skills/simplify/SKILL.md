---
name: simplify
description: "This is the code review skill on this machine. Use it to review any changed code before it goes anywhere: an uncommitted diff, a branch about to be pushed, or a GitHub PR you must judge merge-ready. It checks spec conformance, bugs, reuse, quality, and efficiency, then fixes what it finds — tiered, so most diffs cost zero sub-agents. Reach here when the user says review this, 審一下, look at my diff, is this ready to merge, 可以 merge 了嗎, or check this PR. Other skills reach here for `CHECKLIST.md`, the shared review checklist."
---

# Simplify — tiered, ecp-aware diff review

## Phase 1: Identify changes

`git diff` (or `git diff HEAD` for staged changes) to list what changed. With no git changes, fall back to the files the user named or you edited earlier. Record file count, LOC changed, and whether the diff is docs/comments-only or tests-only.

Then pin the **spec source**, in this order: issue references in the commit messages (`#123`, `Closes #45`) fetched with `gh issue view`; a path the user passed; a spec or PRD under `docs/`, `specs/`, or `.scratch/` matching the branch name. None resolves → the Spec section reports "no spec available", which is an explicit outcome, not a silent skip.

## Phase 2: ecp pre-pass (orchestrator, once)

1. `ecp impact --baseline HEAD~1 --repo . --format json` — use the merge-base for PR reviews (`--baseline origin/main`). Not installed or not indexed → `ecp admin index --repo .`, or skip silently; the skill works without graph context.
2. Capture `changed_symbols` (which symbols the hunks resolve to) and `impact_by_symbol` (upstream callers per changed symbol).
3. Risk floor per global CLAUDE.md → Dispatch → *Risk is inferred*: a changed symbol with >10 upstream callers, or one on an auth / payment / schema-migration / concurrency / external-API path, is **HIGH** — surface it before reviewing, not buried in a report. What the user stressed this turn and what the repo's own CLAUDE.md guards raise it further; one sentence from the user lowers it.

## Phase 3: Tier the dispatch

Pick the LOWEST tier the diff qualifies for; Phase-2 risk moves it up.

| Tier | When | Dispatch |
|------|------|----------|
| 0 | docs / comments / lockfile-only | No review. Say so and stop. |
| 1 | <3 files **or** <100 LOC | **Zero agents** — the orchestrator self-reviews against [`CHECKLIST.md`](CHECKLIST.md). |
| 2 | ≤10 files **and** ≤400 LOC | **One agent** carrying every checklist section. |
| 3 | bigger, or cross-crate/cross-package, or Phase-2 HIGH risk | Parallel agents, one per dimension the diff can violate. |

**Reviewer agent** — Tier 2 and Tier 3 both dispatch `subagent_type: deep-review` with `model: sonnet`: read-only, ecp-aware, already carrying the confidence protocol. At Phase-2 HIGH risk, drop the model override so Correctness runs on its native opus.

**Above HIGH** — a diff whose failure would be expensive enough to want a reader whose mistakes are uncorrelated with yours — is out of scope here: report that the risk exceeds this skill and let the user decide, or run Dispatch's cross-family track (codex) alongside this review.

**Tier-3 dimensions** — launch only the ones the diff can violate, typically 2–4:

- **Correctness** and **Quality** — always.
- **Spec** — only when Phase 1 resolved a spec source. Its own agent, so intent findings are never reranked against style findings.
- **Reuse** — only when the diff ADDS functions or utilities (deletions, renames, and edits inside existing bodies duplicate nothing new). Mechanical graph lookup, so `subagent_type: lite-scan` instead.
- **Efficiency** — only when the diff touches non-test code.

## Phase 4: Run the review

Every reviewer — the orchestrator itself at Tier 1 — walks **every rung of every checklist section it owns**, and is done only once each rung has ended as a finding or as explicitly clear.

Agent preamble:

> Repo at `<absolute path>`. Diff in `<location>`. Spec at `<path or fetched issue, else "none">`. Apply every rung of the `<sections>` sections of `~/.claude/skills/simplify/CHECKLIST.md`.
> ecp pre-pass — changed_symbols: `<list>` · impact_by_symbol: `<symbol → upstream callers>` · risk: `<level>`.
> Review the symbols that actually changed; the graph already proved the rename-only and formatting-only sections structure-preserving. Dig in with `ecp inspect --name X --repo .`; blast radius with `ecp impact --target X --direction upstream --repo .`; "does this already exist?" with `ecp find "<concept>" --repo .`.
> Report each finding as file:line, what and why, suggested fix, a **failure_scenario** (concrete inputs or state, and the wrong output or crash they produce), and **confidence 0–100**. A finding you cannot give a failure_scenario for is not a finding — drop it rather than lowering its confidence. Carry the command you ran and its raw output so the orchestrator re-checks without redoing your search. Close with your blind spots: what you did not read, run, or verify. Report the findings you would defend at 50 or above.

## Phase 5: Aggregate and fix

Wait for every reviewer, then act by confidence:

- **≥70** — re-check the finding against the evidence it carries, then fix. Re-checking is one jump to the cited line or command output, not a repeat of the reviewer's search.
- **50–69** — list in the summary as "worth a look".
- **<50** — drop silently.

A false positive at any confidence → note it and move on. After fixing, `ecp find <changed-symbol> --repo .` confirms the fixed symbols still resolve. Summarise what was fixed (or that the diff was already clean), and which tier ran and why.

Spec findings sit under their own `## Spec` heading above the ranked list, and keep their own worst-issue line — a diff can be clean on every other axis and still build the wrong thing, so the two are never ranked against each other.
