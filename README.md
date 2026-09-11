# claude-setup

A working Claude Code configuration: global instructions, an output style, sub-agent definitions, hooks, and skills. Everything here runs daily on one machine, so the rules are written for behaviour rather than for documentation.

## Layout

| Path | Loaded when | Notes |
| --- | --- | --- |
| `CLAUDE.md` | every session, main and sub-agent | the global rule file |
| `RTK.md`, `ECP.md` | imported by `CLAUDE.md` | CLI-specific rules |
| `maintainer-notes.md` | never | measured provenance for the rules; read before rewording one |
| `output-styles/colleague-zh.md` | main session only | voice and language for user-facing prose |
| `agents/` | on dispatch | effort-pinned and role-scoped sub-agent definitions |
| `hooks/` | per the events in `settings.example.json` | shell hooks |
| `skills/` | description resident, body on invocation | 25 written here, plus 32 directories vendored from `claude-seo` |
| `settings.example.json` | copy to `~/.claude/settings.json` | read the security notes first |

### The 27 skills written here

| Skill | What it does | Origin |
| --- | --- | --- |
| `agent-routing` | Picks the runner for a piece of work, and which browser drives a page | — |
| `authority-check` | The design questions to settle before writing code that carries authority | — |
| `context-audit` | Audit what fills the context window, examine usage and dependencies, and recommend changes that fit the user's | — |
| `codebase-design` | Vocabulary for deep modules: interfaces, seams, testability | mattpocock |
| `dep-audit` | Upgrades every dependency to latest and audits the breakage against real usage | — |
| `domain-modeling` | Ubiquitous language and ADRs | mattpocock |
| `ecp` | Structural code queries: definitions, callers, blast radius, routes | — |
| `eli5` | Explains a topic for a named audience, shaped for an ADHD reader | [DreambigOu/ELI5](https://github.com/DreambigOu/ELI5) |
| `gh-report` | Files issues and PRs against repositories we do not own | — |
| `grill-me` | A relentless interview to sharpen a plan or design | mattpocock |
| `grill-with-docs` | The same interview, writing ADRs and a glossary as it goes | mattpocock |
| `grilling` | Stress-tests a plan, decision or idea on request | mattpocock |
| `improve-codebase-architecture` | Scans for deepening opportunities, reports them as HTML | mattpocock |
| `mpm` | Reads and updates the cross-session follow-ups log through the `mpm` CLI | — |
| `peer-agent` | Runs codex or another Claude as the implementer while you gate the merge | — |
| `preflight` | Six design questions answered in one line each before a new module; user-invoked | — |
| `pr-finalize` | Removes a finished PR's worktree and branch | — |
| `pr-review-multiagent` | Six-angle merge-readiness review, posted to the PR | — |
| `python-perf` | Package defaults, class shape and the selection tables for Python | — |
| `simplify` | The code review skill on this machine | — |
| `to-questionnaire` | Turns a decision you cannot answer into a questionnaire for someone else | mattpocock |
| `to-spec` | Turns the conversation into a spec in the issue tracker | mattpocock |
| `to-tickets` | Breaks a plan into tracer-bullet tickets with their blocking edges | mattpocock |
| `ui-ux-pro-max` | A local UI/UX database plus a registry of external component sources | — |
| `validate-prompt-rules` | A/B tests whether a prompt rule changes model behaviour at all | — |
| `wait-what` | Re-pitches a message that did not land | mattpocock |
| `writing-for-agents` | Rules for any document an agent reads | mattpocock |

The `mattpocock` rows started as [mattpocock/skills](https://github.com/mattpocock/skills) and were rewired here: `ecp` commands replace subjective judgement calls, and the dispatch sentences point back at `CLAUDE.md`. Re-install from upstream by rebuilding on the upstream file and re-applying those edits, not by overwriting.

## Install

```bash
git clone <this repo> ~/claude-setup
cp -r ~/claude-setup/{CLAUDE.md,RTK.md,ECP.md,maintainer-notes.md,agents,hooks,output-styles,skills} ~/.claude/
cp ~/claude-setup/settings.example.json ~/.claude/settings.json
```

Then edit `~/.claude/settings.json`: replace `<YOUR_CONTEXT7_API_KEY>`, and expand `$HOME` in the hook paths if your shell does not.

`settings.example.json` is this machine's `settings.json` with that one key blanked and `$HOME` put back where the absolute path was. It sets `modelSettings` rather than `model`, so it pins an effort level per model and leaves the model itself to whatever the CLI last selected. Add `"model": "opus[1m]"` if you want it fixed.

`CLAUDE.md` settles Python 3.14 syntax arguments by running [`pyci-check`](https://github.com/coseto6125/pyci-check), so install it or that rule has nothing to point at. The programs the hooks call are listed under Security notes and none of them ship here either.

## Vendored third-party skills

`skills/seo` and the 31 `skills/seo-*` directories are [`claude-seo`](https://github.com/AgriciDaniel/claude-seo) v2.2.5 by AgriciDaniel, MIT-licensed, copied unmodified. They sit here so one clone reproduces the whole machine, not because they were written for it. Two directories the upstream install creates are excluded: `seo/.venv` (777 MB) and `seo/ms-playwright` (656 MB). Install those from the upstream repo, or run `skills/seo/bin/claude-seo` and let it build them. `seo/runtime-state.json` is machine state and is excluded too.

Upgrade by re-installing from upstream rather than by patching here.

## Security notes

These are properties of this configuration, not defects. Read them before you copy anything into `~/.claude`.

**`settings.example.json` turns the permission prompts off.** It carries `"defaultMode": "bypassPermissions"` together with `"skipDangerousModePermissionPrompt": true` and `"skipAutoPermissionPrompt": true`. Copied as-is, Claude Code runs shell commands, edits files and reaches the network with no confirmation step. That suits one machine whose owner watches every session, and it removes a safety boundary everywhere else. Set `"defaultMode": "default"` and drop both `skip*` keys unless you want the same trade.

**The permission `allow` list runs to 45 entries.** Each one is a subcommand pattern rather than a whole command family, and the widest of them (`Bash(python3:*)`, `Bash(xargs:*)`, `Bash(cat:*)`) approve an arbitrary argument to a general-purpose program. Combined with the mode above, that is the real reach. Cut the list down to what you run.

**Hooks execute on every matching event.** `hooks/` holds twelve scripts and `settings.example.json` wires seven of them: `auto-etoon.sh`, `limit-worktrees.sh`, `guard-main-edit.sh`, `guard-push-simplify.sh` and `ecp-graph-nudge.sh` on `PreToolUse`, `idle-guard-stop.sh` on `Stop`, `idle-guard-submit.sh` on `UserPromptSubmit`. Read each one before you install it. `guard-main-edit.sh` enforces a rule `CLAUDE.md` only states — it refuses an edit to a file on the default branch and prints the worktree command to use instead. `guard-push-simplify.sh` blocks `git push` until `/simplify` has run in that session. `ecp-graph-nudge.sh` hands over the exact `ecp impact` command a symbol's direct callers cannot answer on their own.

The other five ship unwired, so wire them yourself or delete them. `audit-skill.sh` belongs on `PostToolUse` for `Edit`, `Write` and `MultiEdit`, and checks a `SKILL.md` against the measurable rules the moment it is written. `worktree-symlinks.sh` is the second. The three `eywa-*.sh` scripts are the rest: they inject coding principles on `UserPromptSubmit`, capture them on `Stop`, and clear the session cache on `PreCompact`. They read `$HOME/.eywa/` and query a local server on `127.0.0.1:8788`; without that server running, `eywa-inject.sh` is a no-op.

**Four programs run from hooks and none of them ships here** (`eywa` is the fourth, wired by nothing in `settings.example.json`): `rtk` on `PreToolUse`, `$HOME/.local/bin/ecp` on `PreToolUse`, `SessionStart` and `UserPromptSubmit`, and `$HOME/.orca/agent-hooks/claude-hook.sh` on twelve events. Only the Orca one tests for the file first: it branches on `$OSTYPE`, runs the `.cmd` variant on Windows shells, and falls back to draining stdin and printing `{}` when the file is missing. The `ecp` and `rtk` entries have no guard at all, so a missing binary is a failed hook rather than a no-op. `settings.example.json` also sets `~/.claude/statusline.sh` as the status line, and that script is not in this repo either. Install those programs, or delete the entries.

**The vendored `skills/seo` tree ships 60 Python scripts and a launcher.** They fetch and render arbitrary URLs through Playwright, and they read API credentials from the environment: `DATAFORSEO_PASSWORD`, Google service-account files for GSC and GA4, Moz, Bing Webmaster, and others. Nothing here holds a key, and none of these run until the skill is invoked; the code is upstream's, so review it there before you point it at a site you do not own.

**`skills/ui-ux-pro-max/local/lighthouse_ab.py` runs unpinned code in an unsandboxed browser.** It calls `npx --yes lighthouse`, which fetches whatever the npm registry serves at that moment, and it launches Chrome with `--no-sandbox`. Point it at pages you trust. Its `label=` argument also lands in the output path unfiltered, so a label containing `../` writes outside the report directory.

**`skills/improve-codebase-architecture` produces an HTML report that loads CDN scripts.** Tailwind and Mermaid come from `cdn.tailwindcss.com` and `cdn.jsdelivr.net` with no integrity pin, and Mermaid initialises at `securityLevel: "loose"`. The report holds your repository's structure and the skill opens it in your browser.

**`skills/validate-prompt-rules/route.sh`, `preloaded.sh` and `agentic.sh` copy `.credentials.json` into a temp directory.** The A/B arms authenticate from that copy. `mktemp -d` gives the directory mode 0700 and the copy keeps the source's 0600, so another account cannot read it, and an `EXIT INT TERM` trap removes it on every exit path. It is still a second plaintext token on disk while the script runs.

## The output style reaches the main session only

`output-styles/colleague-zh.md` never loads into a sub-agent. Read from the CLI binary (2.1.232): `Jq()` emits the `output_style` section and only `l_e({mainThreadAgentDefinition, …})` consumes it, while a Task sub-agent's prompt is built by `azn([agentPrompt], …)`. `CLAUDE.md` travels a different route (`nee()` → `userContext`) and does reach sub-agents.

That split decides where a rule goes. Rules about talking to the user live in the style. Rules about artifacts a sub-agent writes live in `CLAUDE.md`.

A custom output style also needs `keep-coding-instructions: true` in its frontmatter. Without it the CLI drops its own default coding-instruction block.

## Token footprint

Measured, not estimated: `claude -p "Reply with exactly: OK" --output-format json --max-turns 1 <flags>`, summing `usage.input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, one variable per run. Baseline is headless with MCP off and the default output style.

| Layer | tokens |
| --- | --- |
| tool schemas, built-in prompt, env | 20,102 |
| `CLAUDE.md` family | 9,748 |
| skills listing | 5,137 |
| `colleague-zh` output style | 924 |
| MCP (deferred tools) | 71 |

The decomposition is additive: 34,987 − 9,748 − 5,137 = 20,102.

These numbers were measured before the private-workspace material came out, so the `CLAUDE.md` family and the skills listing now cost a little less than the table says. Re-run the command above to get the figure for this tree.

Per-tool schema cost, from `--disallowedTools <tool>`:

| Tool | tokens |
| --- | --- |
| Workflow | 7,900 |
| Skill (removes the skills listing too) | 5,137 |
| Agent | 2,313 |
| ScheduleWakeup | 1,695 |
| ReportFindings | 821 |
| Read | 608 |
| ListAgents | 397 |
| Edit | 348 |
| Write | 236 |
| ToolSearch | −19,648 |

`ToolSearch` is negative because disabling it inlines every deferred MCP tool schema. That mechanism is why MCP costs 71 here instead of ~20k.

## Attribution

- `skills/ui-ux-pro-max/{data,scripts,references}` come wholesale from [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill). `local/` and its `SKILL.md` are local work.
- `skills/writing-for-agents` cites [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) for the ASD-STE100 summary.
- `skills/i-have-adhd` comes from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd), MIT, Ayoub Ghriss.
- `skills/eli5` comes from [DreambigOu/ELI5](https://github.com/DreambigOu/ELI5), MIT.
- `skills/{agent-routing,peer-agent}` drive the Orca agent runner and assume it is installed.
- Orca's own `orchestration`, `orca-cli` and `computer-use` skills come from [stablyai/orca](https://github.com/stablyai/orca) and Orca installs them into `~/.agents/skills/` itself, so they are not copied here. `agent-routing` quotes three sentences from Orca's orchestration guide and re-checks them with its own `check-anchors.sh`; that guide ships inside the Orca binary and is read with `orca-ide skills get orchestration`, so it moves with the app rather than with any file.

## Removed before publishing

Skills that only run against one private workspace, a set of hooks that forwarded conversation text to a local HTTP service together with the `CLAUDE.md` section that made that service's replies authoritative, the `CLAUDE.md` section and the `settings.json` entries for a private MCP server, the auto-memory directory, and the real `settings.json` with its API key.

The history was rebuilt from a single commit for the same reason. An earlier published history carried absolute home paths, a private Notion database and owner ID, and internal project names.
