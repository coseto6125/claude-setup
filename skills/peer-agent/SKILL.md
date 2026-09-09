---
name: peer-agent
description: Run a peer coding agent (codex, or another Claude) as the implementer in its own worktree while you review its diff and gate the merge. Use when the user names codex, when two agents cross-review each other's diffs, or for a multi-PR program you supervise. If nobody reviews the result it is a handoff, not this skill; use `orca-cli` instead.
---

# Peer-agent programs

This skill covers only what is specific to driving a peer agent: the launch, the poll, the diff gate. Reviewing the diff itself is `simplify`, and worktree mechanics are `orca-cli`; both are assumed known here.

You review, gate, and merge. The **peer** implements in its own worktree. The channel
between you is asynchronous, lossy, and echo-prone — every rule below exists because
skipping it produced a *false signal that looked exactly like success*.

Treat the peer as a peer: it gets the goal and the gate, decides the implementation,
and may refuse with reasons. CLI mechanics (worktrees, terminals, handoffs) live in
the `orca-cli` skill; this skill is the collaboration contract on top of them.

## Two ways to run a peer

**Supervised** is the default. Orca launches the peer as a worker, the peer ends
with a `worker_done` message carrying its report, and you wait on that message.
Delivery is then a fact the runtime states, not a shape you look for in a file.
`ORCA` is the placeholder the `orca-cli` skill resolves (`orca-ide` on Linux, never bare `orca`: outside an Orca terminal that is the GNOME screen reader). Confirm Orca is up with `ORCA status --json`, then follow the `orchestration`
skill: `task-create`, `dispatch --inject`, and
`check --wait --types worker_done,escalation,question --timeout-ms <n>`. A
review-only `worker_done` reports findings and authorises no edits of yours.
**Ack every delivery the wait returns, heartbeats included.** `check --wait` re-delivers the
oldest unacknowledged delivery and holds the ones behind it, so a loop that only greps for
`worker_done` reads the same heartbeat forever while the report sits queued. Measured
2026-09-09: the task showed `completed` for 12 minutes before an `--ack` let the report through.

**Detached** is for an Orca that is not running, or a peer you deliberately keep
outside it. `setsid codex exec` writes to a log, and the rest of this file covers
what that costs.

**Keep the pair on disk whichever mode ran.** A report that arrives is not yet a
report you hold. Write the brief you sent and the report you got, verbatim, to one
file per peer in the scratchpad, and name the mode that ran on its first line.

You write that file, not the peer. You hold both halves. A read-only peer holds
one and can write neither.

A message read once lives only in your context. A compaction takes it, and takes
the brief that explains it. The next round then re-commissions work already done,
and a finding you did not act on has no second reader. The file is the record. The
message is only how it arrived.

## The brief is the contract

This section governs a peer that lives across sessions. A one-shot consult —
a review, a second opinion, one bounded experiment — carries its whole brief in
the launch prompt and writes no file. Reach for a brief file when the peer will
outlive its first prompt.

Peer instances die — app restarts, deleted worktrees, cleared sessions — and come
back with no memory. Survive that by putting the standing contract in a file inside
the peer's worktree (`<NAME>-BRIEF.md`), and keeping every sent message short.

- **Send self-contained messages.** Each one states current state (what is merged, at
  which SHA), where the brief lives, and what "done" looks like. Assume the reader
  just woke up with amnesia, because it often did.
- **Keep the wire simple.** Parentheses and quotes inside a `--text` payload get eaten
  by the shell bridge — the peer's terminal then tries to *execute* your prompt and
  reports a syntax error. Put substance in the brief; send a short, punctuation-light
  pointer to it.
- **Keep the brief authoritative.** When a rule changes, edit the brief. A rule that
  lives only in a sent message dies with the session.
- **Every gate is executed literally, including against the brief itself.** A criterion
  like "`git status --porcelain` is empty when you finish" reads as an instruction to
  delete the untracked brief, and a peer that obeys it leaves you with no record of what
  you commissioned. Name the exceptions in the gate, or commit the brief before you
  launch. Measured 2026-08-23: codex deleted `SINK-BRIEF.md` and said so in its report --
  it followed the gate exactly as written.

## Commission, don't dictate

- **Name the gate, not the implementation.** Specify the acceptance criterion, the
  evidence required, and the constraints that must hold. Let the peer choose how.
- **Commission an experiment when the outcome is uncertain.** "Build it, measure it
  against the gate, open a PR only if the data clears; otherwise report ABANDON with
  the numbers." This converts a speculative task into a decidable one, and the
  abandonments come back with evidence instead of excuses.
- **Grant the right to refuse.** Say explicitly that a reasoned ABANDON is an
  acceptable deliverable. A peer that talks you out of a bad change is the system
  working.
- **Amend gates in the open.** When you discover your own gate was mis-specified,
  amend the brief and require the PR body to state the amendment and its rationale.
  A silently moved goalpost is indistinguishable from a rigged one.

## Launching a detached peer

`codex exec` is the headless entry point. The sandbox mode decides what the peer may do to your
tree; four properties of the harness decide whether the run lives long enough to produce anything,
and one more decides whether you can tell that it did.

[`DETACHED-LAUNCH.md`](DETACHED-LAUNCH.md) holds the two launch recipes, the four harness properties
that keep a run alive, how to read a report out of a log, and how to wait on one. A supervised peer
reaches none of it — Orca owns the lifetime and delivers the report as a message.

### Model and effort

**Every launch names the model and the effort on the command line.** `~/.codex/config.toml` carries a
default, and a default is invisible: two runs a week apart read the same log path and mean different
things. Name both, and record the pair beside the findings.

- Model: `-m gpt-6-astra` — the gpt-6 line, and the only slug in it. Check the slug is still listed
  with `python3 -c "import json;print([m['slug'] for m in json.load(open('$HOME/.codex/models_cache.json'))['models']])"`,
  because a wrong slug fails late, inside the run.
- Effort: `-c model_reasoning_effort="medium"` — the standing level for every launch, whatever the
  brief covers. Split a brief wider than one reader holds across several peers at `medium`, one per
  dimension, rather than raising the level.

### The sandbox

**The deliverable picks the sandbox.** Decide it once, when you write the brief.

| The peer delivers | Sandbox | Why that one |
|---|---|---|
| a report — a review, an audit, a second opinion | `--sandbox read-only` | a reviewer that can write edits the files it was asked to judge, while you are editing them too |
| a change — a fix you commissioned, an implementation, a migration, a branch to push | write-capable, in its own git worktree | say in one line why the task needs it |
| a judgement on a rendered page | write-capable, network on | a browser needs a writable temp directory and the network |

A peer that reviews AND then fixes what it found is two commissions, not one. Take the
report, decide what to act on, then commission the fix with the sandbox that fix needs.

**A missing write fails late and reads like a refusal.** The peer runs, hits the denial at
the end, and reports something you will mistake for a reasoned ABANDON. Picking the row
costs one line; picking it wrong costs the run. [`SANDBOX-MODES.md`](SANDBOX-MODES.md)
carries the failure signatures and the browser recipe.

## Cross-review

Each side reviews the other's diffs, and reviews them adversarially.

- **Give reviewers raw data, not your summary.** A reviewer handed pooled results will
  either rubber-stamp them or have to go dig up the per-run values anyway. Hand over
  the raw table and let it re-derive your conclusion.
- **Ask for the challenge list.** "List every way a reader could legitimately attack
  this" surfaces the scoping problems — cherry-picked baseline, unmeasured
  configuration, variance hidden by a median — while they are still cheap to fix.
- **Let the reviewer commission its own confirming work.** If it judges that an extra
  measurement is needed to defend a claim, it should run that measurement rather than
  hedge the claim in prose.
