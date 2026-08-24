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
| `skills/` | description resident, body on invocation | 25 skills |
| `settings.example.json` | copy to `~/.claude/settings.json` | read the security notes first |

## Install

```bash
git clone <this repo> ~/claude-setup
cp -r ~/claude-setup/{CLAUDE.md,RTK.md,ECP.md,maintainer-notes.md,agents,hooks,output-styles,skills} ~/.claude/
cp ~/claude-setup/settings.example.json ~/.claude/settings.json
```

Then edit `~/.claude/settings.json`: replace `<YOUR_CONTEXT7_API_KEY>`, and expand `$HOME` in the hook paths if your shell does not.

`CLAUDE.md` settles Python 3.14 syntax arguments by running [`pyci-check`](https://github.com/coseto6125/pyci-check), so install it or that rule has nothing to point at. The programs the hooks call are listed under Security notes and none of them ship here either.

## Security notes

These are properties of this configuration, not defects. Read them before you copy anything into `~/.claude`.

**`settings.example.json` turns the permission prompts off.** It carries `"defaultMode": "bypassPermissions"` together with `"skipDangerousModePermissionPrompt": true` and `"skipAutoPermissionPrompt": true`. Copied as-is, Claude Code runs shell commands, edits files and reaches the network with no confirmation step. That suits one machine whose owner watches every session, and it removes a safety boundary everywhere else. Set `"defaultMode": "default"` and drop both `skip*` keys unless you want the same trade.

**The permission `allow` list runs to 45 entries.** Each one is a subcommand pattern rather than a whole command family, and the widest of them (`Bash(python3:*)`, `Bash(xargs:*)`, `Bash(cat:*)`) approve an arbitrary argument to a general-purpose program. Combined with the mode above, that is the real reach. Cut the list down to what you run.

**Hooks execute on every matching event.** `hooks/` holds nine scripts and `settings.example.json` wires seven of them: `auto-etoon.sh`, `limit-worktrees.sh`, `guard-main-edit.sh`, `guard-push-simplify.sh` and `ecp-graph-nudge.sh` on `PreToolUse`, `idle-guard-stop.sh` on `Stop`, `idle-guard-submit.sh` on `UserPromptSubmit`. Read each one before you install it. `guard-main-edit.sh` enforces a rule `CLAUDE.md` only states — it refuses an edit to a file on the default branch and prints the worktree command to use instead. `guard-push-simplify.sh` blocks `git push` until `/simplify` has run in that session. `ecp-graph-nudge.sh` hands over the exact `ecp impact` command a symbol's direct callers cannot answer on their own.

The other two ship unwired, so wire them yourself or delete them. `audit-skill.sh` belongs on `PostToolUse` for `Edit`, `Write` and `MultiEdit`, and checks a `SKILL.md` against the measurable rules the moment it is written. `worktree-symlinks.sh` is the second.

**Three programs run from hooks and none of them ships here**: `rtk` on `PreToolUse`, `$HOME/.local/bin/ecp` on `PreToolUse`, `SessionStart` and `UserPromptSubmit`, and `$HOME/.orca/agent-hooks/claude-hook.sh` on eleven events. Only the Orca one tests for the file first, and it writes the path inside single quotes, so a plain shell does not expand `$HOME` and the test fails whatever the file's real state. The `ecp` and `rtk` entries have no guard at all, so a missing binary is a failed hook rather than a no-op. `settings.example.json` also sets `~/.claude/statusline.sh` as the status line, and that script is not in this repo either. Install those programs, or delete the entries.

**`skills/ui-ux-pro-max/local/lighthouse_ab.py` runs unpinned code in an unsandboxed browser.** It calls `npx --yes lighthouse`, which fetches whatever the npm registry serves at that moment, and it launches Chrome with `--no-sandbox`. Point it at pages you trust. Its `label=` argument also lands in the output path unfiltered, so a label containing `../` writes outside the report directory.

**`skills/improve-codebase-architecture` produces an HTML report that loads CDN scripts.** Tailwind and Mermaid come from `cdn.tailwindcss.com` and `cdn.jsdelivr.net` with no integrity pin, and Mermaid initialises at `securityLevel: "loose"`. The report holds your repository's structure and the skill opens it in your browser.

**`skills/validate-prompt-rules/route.sh` copies `.credentials.json` into a temp directory.** The A/B arms authenticate from that copy. `mktemp -d` gives the directory mode 0700 and the copy keeps the source's 0600, so another account cannot read it, and an `EXIT INT TERM` trap removes it on every exit path. It is still a second plaintext token on disk while the script runs.

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
