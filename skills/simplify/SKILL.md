---
name: simplify
description: "The code review skill on this machine. Use it to review any changed code before it goes anywhere: an uncommitted diff, a branch about to be pushed, or a GitHub PR you must judge merge-ready. It checks spec conformance, bugs, security, reuse, quality, and efficiency, then fixes what it finds. Reach here when the user says review this, 審一下, is this ready to merge, 可以 merge 了嗎, or check this PR. Other skills reach here for `CHECKLIST.md`, the shared review checklist."
---

# Simplify — tiered, ecp-aware diff review

## Phase 1: Identify changes

`git diff` (or `git diff HEAD` for staged changes) to list what changed. With no git changes, fall back to the files the user named or you edited earlier. Record file count, LOC changed, and whether the diff is docs/comments-only or tests-only.

When the diff changes a `.rs` file or a `Cargo.toml`, open [`rust.md`](rust.md) now. Its rungs join the Correctness and Quality sections at every tier.

Then pin the **spec source**, in this order: issue references in the commit messages (`#123`, `Closes #45`) fetched with `gh issue view`; a path the user passed; a spec or PRD under `docs/`, `specs/`, or `.scratch/` matching the branch name. None resolves → the Spec section reports "no spec available", which is an explicit outcome, not a silent skip.

## Phase 2: ecp pre-pass (orchestrator, once)

1. `~/.claude/skills/simplify/prepass.sh HEAD~1` — use the merge-base for PR reviews (`prepass.sh origin/main`). Pass the repo path as a second argument when the cwd is not the repo. Do not run `ecp impact --baseline` by hand. When it exits non-zero because ecp is missing or the repo is not indexed → `ecp admin index --repo .`, or skip silently.
2. Record what the script prints: the changed-symbol counts, the symbols with upstream callers (most callers first), and the risk line. It counts non-test callers for the risk line. Its `note:` and `stderr:` lines are caveats for the report.
3. Risk floor, per CLAUDE.md Dispatch *Risk is inferred*: a changed symbol with >10 upstream callers, or one on an auth / payment / schema-migration / concurrency / external-API path, is **HIGH**. A changed file under `.github/workflows/`, a CI config, an installer or a release script is **HIGH** too. Tell the user before you review, not at the end of the report.

## Phase 3: Tier the dispatch

Pick the LOWEST tier the diff qualifies for; Phase-2 risk moves it up. Tier a diff that fixes earlier review findings by its own size and risk. Tier a peer's diff the same way.

| Tier | When | Claude agents | Cross-family readers |
|------|------|---------------|----------------------|
| 0 | docs / comments / lockfile-only | None. Say so and stop. | none |
| 1 | <3 files **or** <100 LOC | **Zero** — the orchestrator self-reviews against [`CHECKLIST.md`](CHECKLIST.md) | codex |
| 2 | ≤10 files **and** ≤400 LOC | **One**, carrying every checklist section | codex |
| 3 | bigger, or cross-crate/cross-package, or Phase-2 HIGH risk | One per dimension the diff can violate | codex; Gemini at Phase-2 HIGH risk |

**HIGH runs Tier 3.** HIGH is the top level Phase 2 assigns, so it never qualifies a diff out of the tier it just earned.

**Reviewer agent** — Tier 2 and Tier 3 both dispatch `subagent_type: deep-review` with `model: sonnet`. At Phase-2 HIGH risk, pass `model: opus`. When the agent list has no `deep-review`, dispatch `general-purpose` with the same model.

**Dispatching is part of the invocation.** The agents and readers the tier names need no separate approval; launch them.

Walk the dimensions yourself only when the `Agent` tool is absent from your tool set, and open the summary with `Tier <n>, run inline: Agent tool unavailable`. That is a downgrade you report, not a judgement call you justify.

**Tier-3 dimensions** — launch only the ones the diff can violate, typically 2–4:

- **Correctness** and **Quality** — always. The Quality agent carries the Conventions section too.
- **Spec** — only when Phase 1 resolved a spec source, as its own agent.
- **Reuse** — only when the diff ADDS functions or utilities, not for deletions, renames, or edits inside existing bodies. Dispatch `subagent_type: lite-scan`, or `general-purpose` with `model: haiku` when `lite-scan` is not defined.
- **Security** — only when the diff touches a route table, an auth or session path, a tenancy check, a permission, a credential, a webhook handler, a tool the model can call, or a server-side fetch of a caller-supplied URL. The Security section routes into `~/.claude/skills/simplify/security/SURFACES.md`, which loads depth only for the surfaces it finds. Runs on `deep-review` at its native opus.
- **Efficiency** — only when the diff touches non-test code.

### Cross-family readers

Start each reader as a background Bash call from the repo root, at the same time as the tier's agents. Write its brief to a file first. Each script returns when its review ends: wait for the completion notification, then read the report file. A background call you start this way is the only watcher it needs.

**codex.**

```bash
bash ~/.claude/skills/simplify/codex-review.sh "<scratchpad>/codex-brief.md" "<scratchpad>/codex-review.md"
```

The brief carries the diff location and what the change is for. It also carries the decisions that were settled by argument rather than measurement, what any earlier round already found, and the finding format the agent preamble names. Ask it for a **challenge list**: every way a reader could legitimately attack this diff. Tell it that "clean, no findings" is a welcome result.

A brief wider than one reader holds is split across several codex runs, one per dimension, each carrying only its own dimension: one brief file and one report file per run. With the `peer-agent` skill loaded and Orca up, run codex supervised at `medium` instead, per that skill's *Two ways to run a peer*.

**Gemini — Phase-2 HIGH risk only.**

```bash
bash ~/.claude/skills/simplify/gemini-review.sh "<scratchpad>/gemini-brief.md" "<scratchpad>/gemini-review.md"
```

Its brief is the Phase-4 agent preamble with the ecp lines dropped, and with two additions:

1. Save the diff as `<scratchpad>/gemini-diff.patch`, and name that path in the brief.
2. Add this line: `Use only file-reading tools. Run no shell command.`

Drop the absolute repo path, and say what the code is for instead — this brief leaves the machine, and the path names the user, the client and the project. Read the diff before you send it: a hunk that REMOVES a credential still carries that credential in its `-` lines.

**Read the Gemini report as leads, not as findings.** Take the file:line and the claim, verify the location yourself, and discard its failure_scenario and confidence: they never enter the Phase-5 ladder.

**A non-zero exit is a skip, not a stop.** Read the end of the log the run kept: `<report>.log`, plus `<report>.agy.log` for Gemini. Report it in the summary as `<reader> skipped: <stderr reason>`, and carry on with the review. Gemini exit 5 means the Gemini quota is used up: skip Gemini for this review. Do not run it again, and do not switch it to another agy model.

## Phase 4: Run the review

Every reviewer — the orchestrator itself at Tier 1 — walks **every rung of every checklist section it owns**, and is done only once each rung has ended as a finding or as explicitly clear.

The preamble below carries the review rules, not just the dispatch text: scope, confidence floor, and blind spots bind an inline pass exactly as they bind an agent.

Agent preamble:

> Repo at `<absolute path>`. Diff in `<location>`. Spec at `<path or fetched issue, else "none">`. Apply every rung of the `<sections>` sections of `~/.claude/skills/simplify/CHECKLIST.md`.
> ecp pre-pass — changed_symbols: `<list>` · impact_by_symbol: `<symbol → upstream callers>` · risk: `<level>` · commands: one `ecp impact --target <symbol> --direction upstream --repo .` per changed symbol, listed here.
> Review the symbols that actually changed; the graph already proved the rename-only and formatting-only sections structure-preserving. That proof covers code only: *Prose drift* still searches the text for every renamed name. Read the enclosing function of every hunk: a bug on an unchanged line of a touched function is in scope, because the diff re-exposes it. Run every command the pre-pass lists and paste each output under the finding it supports; a definition question goes to `ecp inspect --name X --repo .` and a reuse question to `ecp find "<concept>" --mode bm25 --repo .`, output pasted the same way.
> Open with the rung ledger that CHECKLIST.md defines. Report each finding as file:line, what and why, suggested fix, a **failure_scenario** (concrete inputs or state, and the wrong output or crash they produce), and **confidence 0–100**. A finding you cannot give a failure_scenario for is not a finding — drop it rather than lowering its confidence. Realistic-but-rare state keeps its confidence: a race, a nil on a cold-cache path, a falsy zero, a boundary the code does not exclude. Score a finding below 50 only when the code refutes it — quote the line that makes it impossible, or the guard that already handles it. Carry the command you ran and its raw output so the orchestrator re-checks without redoing your search. Close with your blind spots: what you did not read, run, or verify. Report the findings you would defend at 50 or above.
> Write the whole report to `<scratchpad>/review-<sections>.md`. Your final message holds only that path and one line per finding: confidence, file:line and the claim.

**Sweep — Phase-2 HIGH risk only.** Once the reviewers return, take one more pass yourself over the diff and its enclosing functions, holding their finding list. Look only for what the list misses: moved code that dropped a guard or an anchor, a default evaluated once at definition, a lock scope that shrank, setup/teardown asymmetry in tests, a config default flipped. An empty sweep is a valid result.

## Phase 5: Aggregate and fix

Wait for every reviewer and every cross-family reader. Read every report file in full. Act by confidence, scored against the anchors in [`CHECKLIST.md`](CHECKLIST.md#confidence); the Gemini scores do not count toward these bands:

- **≥50, the fix gate** — re-check the finding against the evidence it carries, then fix. Re-checking is one jump to the cited line or command output, not a repeat of the reviewer's search. The 50 anchor already means the finding is real. A finding whose evidence the re-check cannot confirm is not fixed: it goes under `## Scanned, not acted on`. For a confirmed finding with a statement shape, run `ecp pattern --pattern '<the defect as an ast-grep pattern>' --lang <ext> --repo .`. Each hit with the same defect is a **sibling**: fix it too.
- **<50** — drop. A finding you spent a command investigating and then rejected goes under `## Scanned, not acted on` too: one line each, carrying its score and why it stays.

Fix everything you can reach. Three classes stay unapplied and go to the summary as proposals, each carrying the concrete change it proposes and one line saying why it stays unapplied:

- a fix that changes intended behaviour
- a fix that reaches outside the files the diff touches, except a *Prose drift* fix, a sibling fix or an *Orphaned code* deletion: apply those in any file of the repo
- a fix big enough to be its own change: a refactor, an API change, a migration

A false positive at any confidence → note it and move on. After fixing, `ecp find <changed-symbol> --repo .` confirms the fixed symbols still resolve.

After the last fix in a local repo, run `~/.claude/skills/simplify/review-mark.sh mark <repo>`. Skip it for a GitHub PR you reviewed without a local checkout.

Summarise what was fixed (or that the diff was already clean), and which tier ran and why. Report the cross-family findings separately from the tier's. A finding two model families reach independently outranks its confidence score. Rank Correctness findings above Reuse, Quality, Conventions, and Efficiency findings.

Spec findings sit under their own `## Spec` heading above the ranked list, and keep their own worst-issue line. Never rank them against the other findings.

Close the summary with `## Not covered`: every reviewer's blind spots, merged into one deduplicated list. At Phase-2 HIGH risk, also name the files the user must read before the change ships.
