# codex sandbox modes

Reached from [`SKILL.md`](SKILL.md) when a run needs a mode other than the two recipes there: `--sandbox read-only` for a peer that judges, `--dangerously-bypass-approvals-and-sandbox` for a peer that must produce a change.

- **`--dangerously-bypass-approvals-and-sandbox` drops the sandbox *and* the approval prompts.** A
  detached peer needs the second half: one that stops on an approval it cannot show anyone has not
  failed, it has hung, and that looks identical to a peer still working. The peer then reaches the
  network and the whole filesystem, so a task needing `notion`, `gh`, `ecp`, `uv` or a package index
  behaves as it would in your own session. Name the workdir with `-C` and bound the peer through the
  brief. Reach for it when the peer must produce a change, not when it must produce a judgement.
- **`--sandbox danger-full-access` is the weaker half of that.** It removes the sandbox and leaves
  approvals in place, so it fits an interactive session where somebody can answer them, and stalls a
  headless one. The narrower sandboxes fail in a way that is easy to misread: the peer keeps working,
  silently loses a source, and hands back a result built on less evidence than you think it had.
- **`--sandbox read-only` is what a reviewing peer gets.** An adversarial review, an audit, a second
  opinion on a diff: nothing needs to be written, so the mode with no write path removes a whole class
  of accident. It also bounds what the peer can claim — it cannot run a build that needs a cache, so
  its findings come back as arguments you re-check rather than as edits you inherit.
- **`--sandbox workspace-write` sits between them, and its edges bite.** It permits the workdir, `/tmp`
  and `$TMPDIR`, nothing else, and usually no network. A report path outside those roots fails at the
  very end, after the whole task is done, with `patch rejected: writing outside of the project`, and the
  finished work dies with the process. A scratchpad path under `~/.cache` is not writable.
