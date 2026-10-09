---
name: agent-routing
description: "Choose which agent runner, which channel, or which browser a piece of work goes to — Orca, the harness's own SendMessage, or ecp. Use while deciding between them, and whenever a task needs a browser at all: rendering a URL, screenshotting a local dev server, or checking how a page looks. Once the target is known, drive it directly with `orca-cli` for Orca worktrees, terminals, and the embedded browser, `orchestration` for supervising a task DAG, `computer-use` for desktop windows."
---

# Agent routing

Three systems reach other agents here, and each owns a different layer. Orca carries
lifecycle, the harness carries content between Claude Code sessions, and ecp sees the
code all of them are about to touch. This skill decides which one a given piece of
traffic belongs to. The Orca commands themselves live in the `orchestration` and
`orca-cli` skills, whose guides come version-matched from the `orca` binary.

## Before splitting work

Before creating the tasks that fan work across agents, check whether the intended
targets collide in the code graph:

```bash
ecp peers plan --targets <symbol,symbol,...> --direction both --format json
```

`clusters` groups targets whose blast radii intersect and `overlaps` names each
intersection. Give each cluster its own task so every dispatch owns a disjoint
surface, and chain targets that must stay separate despite an overlap with
`task-create --deps` rather than dispatching them in one wave.

`plan` compares only the targets passed to it, reading the code graph and never the
live session registry, so an empty `overlaps` means those targets do not collide with
each other. To cover work already in flight, add the targets other agents currently
hold to the same `--targets` list.

`plan` inherits the lower-bound caller counts that `ECP.md` describes for `ecp impact`.
For a common symbol name, grep the call sites before you trust a clean result.

To collect what the other agents hold, treat Orca's task specs as the roster and
`ecp peers status` as evidence of who is actively touching code. The listing runs
narrower than the work in flight. It reports only sessions that hold a dirty surface and
acted in this repo recently. A clean worktree, a session quiet past the liveness window,
and an agent that edits this repo by absolute path from another cwd are absent from it.
(Needs ecp 0.9.1 or later.)

`ecp peers status --pairs` answers a coarser question than `plan`: it reports two
sessions holding an overlay entry for the same file, since the manifest does not record
which declarations changed. Read a HARD pair as "this file is worth a look" rather than
as a certain conflict, because two sessions working in different functions of one file
raise it by design. Ask `plan` for the symbol-level answer.

## Choosing a channel

Orca messages carry lifecycle: `taskId`, `dispatchId`, and completion authority.
What two Claude Code sessions exchange around that work — a question, a finding, a
warning that a change landed, a review of each other's diff — is content, and content
travels over the harness's own `SendMessage` tool, addressed by the session name
`ListAgents` reports.

Route by what the message is:

- Lifecycle (`worker_done`, `heartbeat`, `escalation`, `decision_gate`) and the initial
  dispatch stay on Orca. `SendMessage` carries plain text only, so a lifecycle message
  sent that way updates no task and leaves the dispatch open.
- Follow-ups to an already-dispatched Claude worker, and content between Claude
  sessions, go over `SendMessage`. It delivers into the recipient's conversation
  directly, so it needs no terminal handle and no shell quoting.
- Anything for opencode, gemini, or a bare shell goes over Orca, and so do codex
  lifecycle and terminal input. `ListAgents` reports Claude Code sessions only.
  Content for codex can also go over `ecp peers say` (see *Reaching codex*).

Content reaching a peer without passing through the coordinator is the point: two
workers cross-reviewing hand each other raw diffs directly, and the coordinator
receives one `worker_done` carrying the conclusion. When a peer exchange changes a
task's scope or settles a decision the coordinator is tracking, send that back as a
`status` message so the DAG reflects what the workers agreed.

## Where this overrides the Orca guides

The `orchestration` and `orca-cli` guides predate cross-session messaging, so they
route every handoff prompt through a terminal. Two of their instructions take the
routing above on top. Each quote is a heading in the guide that `ORCA skills get orca-cli`
serves (`ORCA` is the binary the `orca-cli` skill resolves: `orca-ide` on Linux). When a quote no longer matches that guide, re-read its section before you trust
the override.

- "Independent new-worktree handoff:" starts a worker with `worktree create --prompt`.
  Use it for a worker that does not exist yet. A worker being created is not yet in
  `ListAgents`, so `SendMessage` cannot reach it.
- "Existing-terminal handoff:" sends a brief with `terminal send`. That covers
  non-Claude agents. Hand an existing Claude Code session its brief with `SendMessage`.
  Ownership transfers the same way, so the guide's rule against lifecycle state for a
  handoff still holds.

`check-anchors.sh` in this skill's folder checks those two quotes against the running
Orca and names any that no longer match. It probes the app version on each run and pulls
the guide only when Orca itself changed, so the usual run costs one status call.

## Anything that needs a browser

The trigger is the wish to see a page. The moment the thought forms (render this URL,
screenshot the dev server, check how the page looks, does this layout overflow), the
browser is Orca's embedded one, reached through `orca-cli`.

**Never hand-write a Playwright script, and never launch a browser binary directly.**
The `playwright` MCP entry is gone; `~/.claude/maintainer-notes.md`
records why.

Route by what holds the pixels, not by whether the target feels Orca-managed. The
question "is this Orca's business?" is the step that fails: a local dev server reads as
plain shell work, and the browser rule never fires.

- A URL, a local dev server, a web app, a rendered document → `orca-cli`, embedded browser.
- A desktop window, a webview, an app that is not a page → `computer-use`.

## Reaching codex

`ListAgents` reports Claude Code sessions only, so `SendMessage` never reaches codex.
Codex lifecycle and terminal input go over Orca. Content can also go over
`ecp peers say --to <name>`, the one channel to codex that needs no terminal.
`ecp peers` is the one layer that sees codex and Claude at once. Codex exports
`CODEX_THREAD_ID` to its shell and ecp reads it, so any launch form enrolls codex as one
stable peer (codex-cli 0.155.1, 2026-09-23). To address it by a name instead of its id,
launch it with one:

```bash
ORCA terminal create --worktree active --command 'ECP_AGENT_NAME=<name> codex' --json
```

`worktree create --agent codex` forwards no per-call arguments, so it cannot carry a name.

## Model and effort

`~/.claude/CLAUDE.md` holds the ladder that decides which tier a task gets. This section holds the mechanics behind it.

Two knobs are adjustable. Thinking is not one of them.

- **model** — the per-call `model` param on the Agent tool, or the agent definition's frontmatter. Pass it on every call; name `opus` when the task needs the top tier.
- **effort** — no per-call param on the Agent tool. Set it through agent-definition frontmatter. The generic `effort-<level>` definitions in `~/.claude/agents/` carry no model binding, so they compose with the per-call `model` param into a full model x effort grid; the per-call `model` overrides the frontmatter. `lite-scan` and `deep-review` add role prompts and tool whitelists on top. Only Workflow `agent()` has a true per-call `effort`. New definitions register at session start, not mid-session.
- **thinking** — fixed. Sub-agents inherit the session's extended-thinking toggle, and "think hard" or "ultrathink" keywords in a prompt do not change any budget. Adapt through model and effort only.

Per-MTok list prices:

| model | input / output | cache read |
|---|---|---|
| Haiku 5.5, prompt up to 100K tokens | $0.10 / $0.50 | 0.1x |
| Haiku 5.5, prompt over 100K tokens | $0.50 / $2.50 | 0.1x |
| Sonnet 5.5 | $2 / $10 | $0.20 (0.1x) |
| Opus 5.5 | $4 / $20 | $0.20 (0.05x) |
| Fable 5.1 | $10 / $50 | $0.25 (0.025x) |

Source: platform.claude.com/docs/en/about-claude/pricing (2026-09-11). Sonnet and Opus re-checked in the bundled `claude-api` skill on 2026-09-25, Haiku 5.5 on 2026-10-09.
