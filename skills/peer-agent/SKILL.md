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

## The brief is the contract

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

## Launching codex so it survives you

`codex exec` is the headless entry point. Three properties of the harness decide whether
the run lives long enough to produce anything.

```bash
setsid codex exec --sandbox workspace-write --skip-git-repo-check -C "$PWD" \
  "Read <BRIEF path> and carry out exactly what it asks." \
  < /dev/null > "$SCRATCH/codex-<task>.log" 2>&1 & disown
```

- **`setsid` is what keeps it alive.** Without a new session, the peer belongs to the
  tool call's process group and dies with it. `nohup … &` is not enough.
- **`< /dev/null` or it hangs.** Without it the peer waits on stdin until timeout and
  produces nothing.
- **Launch it from a foreground Bash call that returns immediately**, not with
  `run_in_background: true`. Backgrounded tool calls carry a wall-clock cap that kills a
  long peer run mid-flight, and their completion notification describes the wrapper.
- **One log path per run.** A second launch writing the same path truncates the first
  run's log under it, and you then read a mixture of two runs as though it were one.
- **Never `pkill -f` on a pattern that also matches the command line you are launching**
  — including one later in the same `&&` chain. `pkill`'s exit status aborts the chain
  before the relaunch, so you kill the peer and skip its replacement in one line.

- **For an audit, use `--sandbox read-only` and take the report off stdout.** The peer is reading and
  judging, not building, so the sandbox that cannot write anything is both the safest and the one
  with no path to get wrong. Reserve `workspace-write` for peers that actually implement.
- **If the peer must write a file, point it at a path the sandbox allows.** `workspace-write` permits
  the workdir, `/tmp` and `$TMPDIR` — nothing else. A report path outside those roots fails at the
  very end, after the whole audit is done, with `patch rejected: writing outside of the project`, and
  the finished work dies with the process. Ask for the report on stdout as well either way: the log
  survives a rejected write, and a scratchpad path under `~/.cache` is not writable.

Verify the launch by process, not by log, and **bracket a character so `pgrep` cannot match its own
command line**: `pgrep -f "[c]odex exec" | wc -l`. Plain `pgrep -f "codex exec"` matches the pgrep
itself, always returns at least 1, and turns "is it still running" into a constant yes — a wait loop
gated on it can only ever end by timing out. The bracket also fails if the same shell line repeats the
unbracketed pattern anywhere, so keep the check in a line of its own.

## Waiting: poll the artifact, not the chatter

**Never poll a peer's terminal for a keyword you sent it.** The terminal echoes your
own instruction text back, so you match your own words and see a completion that never
happened. Poll something the peer **produces** instead: a PR opening, a branch pushed,
a file appearing at a known path, a commit landing.

Four things impersonate a completion signal:

- **Echoed keywords** — a verdict name, a done-marker, an option you listed in a menu.
- **Agent state** — a peer reads `done`/`idle` while a benchmark or build it launched
  is still running in a background terminal.
- **A redirected output file** — `codex exec … > out.txt` creates the file at launch, so
  its existence proves the run started, nothing more. Its *contents* are a shape you are
  guessing at, and a real run opens with the CLI's own banner lines, not with your work.
- **The harness's own task-completion notification** — it reports the wrapper shell you
  launched from, which exits the moment it has spawned a detached peer. "Exit code 0,
  completed" then arrives while the peer is on its second tool call of forty. The tell is
  a run that "finished" in seconds with a truncated log; `pgrep` settles it, the
  notification does not.

When a keyword really is the only available signal, confirm it against a produced
artifact before acting on it.

**Prefer the harness signal to a loop of your own, but only when the harness owns the
process.** A subagent, or a command the harness itself runs to completion, re-invokes you
on exit, and that exit is the one completion signal you did not have to guess. A detached
`setsid` peer is not owned by the harness, so its notification describes the wrapper; for
that case write one bounded wait loop and let it be the only watcher.

When a wait loop is genuinely the only option:

- **Gate on the process, not on the text.** `! pgrep -f "<the peer's command>"` is
  decidable. A `grep` for the shape of the output is a guess wearing a condition's
  clothes.
- **Never AND a decidable condition with a guessed one.** The guess pins the whole
  expression false forever. The loop never exits, no error is raised, and it spins
  quietly for the life of the session — the failure mode is a spinner that never stops,
  traced back hours later to a `grep` pattern that never could have matched.
- **Bound every loop.** Give it a deadline, and on expiry exit non-zero naming what it
  waited for. A wait that cannot fail cannot be debugged.

Before every send, re-acquire the terminal handle by listing — handles change across
app restarts — and confirm the target is the agent's TUI rather than a bare shell.

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
