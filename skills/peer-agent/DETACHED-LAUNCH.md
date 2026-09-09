# Detached peer: launch, delivery, waiting

The `peer-agent` skill holds the rule that a detached peer is the fallback mode; this file holds its
mechanics. Every line here exists because skipping it produced a false signal that looked exactly
like success.

The read-only recipe, for a peer whose deliverable is a report:

```bash
setsid codex exec -m gpt-6-astra -c model_reasoning_effort="medium" \
  --sandbox read-only --skip-git-repo-check -C "$PWD" \
  "<the brief, or: Read <BRIEF path> and carry out exactly what it asks>" \
  < /dev/null > "$SCRATCH/codex-<task>.log" 2>&1 & disown
```

The write-capable recipe, for a peer whose deliverable is a change:

```bash
setsid codex exec -m gpt-6-astra -c model_reasoning_effort="medium" \
  --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -C "$PWD" \
  "<the brief, or: Read <BRIEF path> and carry out exactly what it asks>" \
  < /dev/null > "$SCRATCH/codex-<task>.log" 2>&1 & disown
```

Give a write-capable peer its own git worktree whenever your session keeps working meanwhile. Two
writers in one checkout produce a tree neither of them can reason about, and test runs from both
sides interleave — measured on 2026-08-21, a review peer launched with the bypass flag rewrote
`session.rs`, `meeting.ts` and `LiveView.tsx` under review and ran the author's own test suite by
name, so no result from either side was trustworthy until the whole thing was untangled by hand.

- **`setsid` is what keeps it alive.** Without a new session, the peer belongs to the
  tool call's process group and dies with it. `nohup … &` is not enough.
- **`< /dev/null` or it hangs.** Without it the peer waits on stdin until timeout and
  produces nothing.
- **Launch it from a foreground Bash call that returns immediately**, not with
  `run_in_background: true`. The two do opposite things at the 120s mark: a
  `run_in_background: true` call is SIGTERM'd there (exit 143), while a foreground call is
  adopted as a background task and runs to completion. The Bash `timeout` parameter does
  not raise that cap — a call carrying `timeout: 600000` is still cut at 120s. Either way
  the completion notification describes the wrapper shell, not the peer.
- **One log path per run.** A second launch writing the same path truncates the first
  run's log under it, and you then read a mixture of two runs as though it were one.
- **Never `pkill -f` on a pattern that also matches the command line you are launching**
  — including one later in the same `&&` chain. `pkill`'s exit status aborts the chain
  before the relaunch, so you kill the peer and skip its replacement in one line.

- **Ask for the report on stdout whatever the mode.** The log survives a rejected write.
- **Read a detached peer's report from the end of the log.** Searching for the header
  you asked for is the trap. A peer answers in its own shape: it renumbers, it writes in
  the language the brief is written in, it drops a heading it judged redundant. A grep
  for your header then returns nothing. Nothing reads exactly like a peer that died. Measured 2026-09-05: two consecutive runs were reported dead on that evidence
  while both reports sat complete in their logs. Judge delivery by the process, then
  read the tail: `pgrep -x codex` says whether it is still alive, and the last ~200
  lines say whether it finished. This is the cost the supervised mode removes.

Both flags carry edges that decide whether a headless run finishes at all, and two more modes sit between them. [`SANDBOX-MODES.md`](SANDBOX-MODES.md) holds the four.

Verify the launch by process, not by log, and **bracket a character so `pgrep` cannot match its own
command line**: `pgrep -f "[c]odex exec" | wc -l`. Plain `pgrep -f "codex exec"` matches the pgrep
itself, always returns at least 1, and turns "is it still running" into a constant yes — a wait loop
gated on it can only ever end by timing out. The bracket also fails if the same shell line repeats the
unbracketed pattern anywhere, so keep the check in a line of its own: a Monitor script that contains
the unbracketed pattern matches itself and never fires.

**Anchoring the pattern to the start does not work.** `pgrep -f "^codex"` matches nothing, because the
command line begins with the interpreter or the absolute path (`node /home/…/codex exec …`), so the
check reports "finished" the moment it runs. `pgrep -x codex` matches on the process name instead, and
answers "is any codex alive".

**Name the run, not the program.** "Is any codex alive" and "is mine still running" are different
questions, and only the second one ends a wait. Other sessions on this machine launch their own peers,
so `codex exec` matches theirs, and a loop gated on it waits out the longest-running stranger. Put a
token in the launch that nothing else carries, then pgrep that token: the brief path is already unique
per run, so `pgrep -f "[c]odex.*<brief basename>"` names one peer. Measured 2026-09-07: four loops
gated on `[c]odex exec` ran 20 minutes past their own peer's exit, against another session's 3-hour
run, and died to memory pressure with the report sitting complete in its log.

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

- **Run the loop under Monitor, not under Bash.** Bash kills a `run_in_background: true`
  call at 120s, so the watcher dies long before the peer does, and the peer then finishes
  unobserved. Monitor takes `timeout_ms` up to 3600000, or `persistent: true` for the
  session.
- **Gate on the process, not on the text.** `! pgrep -f "<the run's own token>"` is
  decidable. A `grep` for the shape of the output is a guess wearing a condition's
  clothes.
- **Never AND a decidable condition with a guessed one.** The guess pins the whole
  expression false forever. The loop never exits, no error is raised, and it spins
  quietly for the life of the session — the failure mode is a spinner that never stops,
  traced back hours later to a `grep` pattern that never could have matched.
- **Bound every loop.** Give it a deadline, and on expiry exit non-zero naming what it
  waited for. A wait that cannot fail cannot be debugged.

**A peer dies with the session that spawned it.** A crash or a teardown kills the process group,
and the log then ends inside a tool trace with no report. The work is not lost: the peer's own
transcript survives on disk, so you resume the run instead of paying for it twice.
[`RESUME.md`](RESUME.md) holds the recipe and the flag order it needs.

Before every send, re-acquire the terminal handle by listing — handles change across
app restarts — and confirm the target is the agent's TUI rather than a bare shell.
