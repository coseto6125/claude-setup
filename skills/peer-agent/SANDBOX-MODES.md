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

## A peer that must look at a page

Verifying what a page renders — a design cut, an editor screen, a layout after a change — needs a
browser. A browser needs a writable temp directory and the network. `--sandbox read-only` gives
neither, and the run does not stop: the peer keeps going, reasons from the source instead, and hands
back a report whose findings never touched the page. Measured 2026-09-05 on two audits: both came
back with every observable row marked unverified.

The signatures, so you recognise them in a log rather than reading them as a refusal:

- `EROFS: read-only file system, mkdtemp '/tmp/playwright-artifacts-…'`
- `UtilBindVsockAnyPort:309: socket failed 1` — the browser daemon's own socket
- DNS failures on the site and on any API the tooling calls

`--sandbox workspace-write` does not fix it: it permits the workdir and `/tmp`, and usually no
network, so the browser starts and the page never loads.

So a page-verifying peer launches with `--dangerously-bypass-approvals-and-sandbox`, and the brief
does the bounding that the sandbox no longer does:

- name a scratch directory for screenshots with `-C`, outside the repository
- forbid writes to the repository in one line, and say the deliverable is a report
- for a shared site, forbid every action that writes: no save, publish, schedule, delete or import
- when a credential is needed, name the one file it may read and tell it not to print the value

`pagelens` (installed for codex as a skill) is what such a peer should query the page with: `find`,
`near`, `read`, `why_disabled` answer in tens of tokens where an accessibility snapshot costs tens of
thousands. It does not remove the sandbox requirement — its Orca executor shells out to the same
browser daemon whose socket read-only blocks.

**The cheaper split, when the peer only needs to judge:** drive the browser yourself, save the
screenshots and the measurements, and hand a read-only peer the artefacts. Reach for it when the
question is "is this right" rather than "go find out". Screenshots stay with you either way — you can
read an image and a headless peer cannot.
