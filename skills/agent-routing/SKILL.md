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

Caller sets are a lower bound, since the resolver suppresses ambiguous bare calls to
common names. For a common symbol name, grep the call sites before trusting a clean
result.

To collect what the other agents hold, treat Orca's task specs as the roster and
`ecp peers status` as evidence of who is actively touching code. The listing runs
narrower than the work in flight: it reports the sessions that hold a dirty surface and
acted in this repo recently, so a clean worktree, a session quiet past the liveness
window, and an agent editing this repo by absolute path from another cwd are all absent
from it. (Needs ecp 0.9.1 or later.)

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
- Anything for codex, opencode, gemini, or a bare shell goes over Orca; `ListAgents`
  reports Claude Code sessions only.

Content reaching a peer without passing through the coordinator is the point: two
workers cross-reviewing hand each other raw diffs directly, and the coordinator
receives one `worker_done` carrying the conclusion. When a peer exchange changes a
task's scope or settles a decision the coordinator is tracking, send that back as a
`status` message so the DAG reflects what the workers agreed.

## Where this overrides the Orca guides

The `orchestration` and `orca-cli` guides predate cross-session messaging, so they
route every free-form prompt through a terminal. Three of their instructions take the
routing above on top. Each quote is verbatim from the guide `orca skills get
orchestration` serves; when a quote no longer matches what that guide says, re-read
its section before trusting the override.

- Messaging: "`terminal send` when an existing agent needs a free-form prompt"
  applies to non-Claude agents. Reach an existing Claude Code session with
  `SendMessage`.
- Full Handoffs: "Existing terminal handoff:" covers non-Claude agents. Hand a Claude
  Code session its brief with `SendMessage`; ownership transfers the same way, so the
  guide's own rule against creating lifecycle state for a handoff still holds.
- Worker Terminals: "Use `orca worktree create --prompt ...` or `orca terminal send
  ...` for full handoffs or untracked/lightweight prompts" splits by whether the
  worker exists yet. Use `worktree create --prompt` for one that does not exist,
  `terminal send` for an existing non-Claude one, and `SendMessage` for an existing
  Claude Code session. A worker being created is not yet in `ListAgents`, so
  `SendMessage` cannot reach it.

`check-anchors.sh` in this skill's folder checks those three quotes against the running
Orca and names any that no longer match. It probes the app version on each run and pulls
the guide only when Orca itself changed, so the usual run costs one status call.

## Anything that needs a browser

Wanting to see a page IS the trigger. The moment the thought forms — render this URL,
screenshot the dev server, check how the page looks, does this layout overflow — the
browser is Orca's embedded one, reached through `orca-cli`.

**Never hand-write a Playwright script, and never launch a browser binary directly.**
Drive Orca's embedded browser through `orca-cli` instead. The `playwright` MCP entry
was removed on 2026-08-15 because the embedded browser covers the work, and re-creating
it by hand re-imports the 1,155 MB of playwright-mcp and headless-Chrome RSS that
removal released. `~/.claude/maintainer-notes.md` records the decision.

Route by what holds the pixels, not by whether the target feels Orca-managed. Judging
"is this Orca's business?" is the step that fails: a local dev server reads as plain
shell work and the browser rule never fires.

- A URL, a local dev server, a web app, a rendered document → `orca-cli`, embedded browser.
- A desktop window, a webview, an app that is not a page → `computer-use`.

## Reaching codex

`ListAgents` reports Claude Code sessions only, so every channel to codex runs through
Orca. `ecp peers` is the one layer that can see codex and Claude at once, since
`resolve_session_id` accepts `ECP_SESSION_ID` ahead of every host-specific variable.
Codex exports no session id of its own, so give it one when the terminal is created:

```bash
ORCA terminal create --worktree active \
  --command 'ECP_SESSION_ID=<stable-name> ECP_AGENT_NAME=<stable-name> codex' --json
```

Without it, each ecp call under codex falls back to a per-process id and enrolls as a
fresh dead session.

## Model and effort

`~/.claude/CLAUDE.md` holds the ladder that decides which tier a task gets. This section holds the mechanics behind it.

Two knobs are adjustable. Thinking is not one of them.

- **model** — the per-call `model` param on the Agent tool, or the agent definition's frontmatter. Inherit is reserved for tasks that genuinely need the session's top-tier model.
- **effort** — no per-call param on the Agent tool. Set it through agent-definition frontmatter. The generic `effort-<level>` definitions in `~/.claude/agents/` carry no model binding, so they compose with the per-call `model` param into a full model x effort grid; the per-call `model` overrides the frontmatter. Verified live. `lite-scan` and `deep-review` add role prompts and tool whitelists on top. Only Workflow `agent()` has a true per-call `effort`. New definitions register at session start, not mid-session.
- **thinking** — fixed. Sub-agents inherit the session's extended-thinking toggle, and "think hard" or "ultrathink" keywords in a prompt do not change any budget. Adapt through model and effort only.

Per-MTok list prices, input/output: Haiku 4.5 $1/$5 · Sonnet 5 $3/$15 (intro $2/$10 through 2026-08-31) · Opus 5 $5/$25.
