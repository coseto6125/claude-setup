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
| `skills/` | description resident, body on invocation | 38 written or adapted here, plus 32 SEO directories adapted from `claude-seo` |
| `skill_script/` | called by skills and by one `SessionStart` hook | shell helpers with their tests |
| `mods/token-saver/` | every session, through `env.CLAUDE_CODE_PLUGIN_DIRS` in `settings.example.json` | a mod that trims the session prompt; `claude plugin test mods/token-saver` runs its checks |
| `settings.example.json` | copy to `~/.claude/settings.json` | read the security notes first |

### The 38 skills written or adapted here

| Skill | What it does | Origin |
| --- | --- | --- |
| `agent-routing` | Picks the runner for a piece of work, and which browser drives a page | — |
| `authority-check` | The design questions to settle before writing code that carries authority | — |
| `catchup` | Catches you up on the chat since your last message and lists every call waiting on you; user-invoked | — |
| `codebase-design` | Vocabulary for deep modules: interfaces, seams, testability | mattpocock |
| `context-audit` | Audit what fills the context window, examine usage and dependencies, and recommend changes that fit the user's | — |
| `decider-2b` | Calls and tunes a local Decider-2B endpoint, and measures whether a prompt change helped | — |
| `dep-audit` | Upgrades every dependency to latest and audits the breakage against real usage | — |
| `diagnose` | Debugs a failing test or wrong output, starting before the first edit | — |
| `domain-modeling` | Ubiquitous language and ADRs | mattpocock |
| `ecp` | Structural code queries: definitions, callers, blast radius, routes | — |
| `eli5` | Explains a topic for a named audience, shaped for an ADHD reader | [DreambigOu/ELI5](https://github.com/DreambigOu/ELI5) merged with [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) |
| `external-writing` | Writes for a reader outside the project: a client letter, a report, a résumé | — |
| `gh-report` | Files issues and PRs against repositories we do not own | — |
| `grill-me` | A relentless interview to sharpen a plan or design | mattpocock |
| `grill-with-docs` | The same interview, writing ADRs and a glossary as it goes | mattpocock |
| `grilling` | Stress-tests a plan, decision or idea on request | mattpocock |
| `handoff` | Writes a hand-off document so a fresh session can continue the work | — |
| `improve-codebase-architecture` | Scans for deepening opportunities, reports them as HTML | mattpocock |
| `mpm` | Reads and updates the cross-session follow-ups log through the `mpm` CLI | — |
| `notebooklm` | Hands a large external read to NotebookLM through the `nlm` CLI, so only its answers enter context | — |
| `peer-agent` | Runs codex or another Claude as the implementer while you gate the merge | — |
| `pr-body` | Writes a PR title and body in a fixed four-section shape, with a rollback call | — |
| `pr-finalize` | Removes a finished PR's worktree and branch | — |
| `pr-review-multiagent` | Six-angle merge-readiness review, posted to the PR | — |
| `preflight` | Six design questions answered in one line each before a new module; user-invoked | — |
| `python-perf` | Package defaults, class shape and the selection tables for Python | — |
| `retro` | Looks back at a session and proposes changes to the environment, not the code | — |
| `rust-best-practices` | Idiomatic Rust design rules: ownership, API shape, error types, traits, unsafe, crate layout | [BeautifulRust](https://github.com/morganlinton/BeautifulRust) |
| `rust-perf` | Rust performance measurement and the Rust traps that pass review | — |
| `rust-port` | Ports C, C++, Python, Go, JavaScript or TypeScript to idiomatic Rust, porting the tests first | [BeautifulRust](https://github.com/morganlinton/BeautifulRust) |
| `simplify` | The code review skill on this machine | — |
| `to-questionnaire` | Turns a decision you cannot answer into a questionnaire for someone else | mattpocock |
| `to-spec` | Turns the conversation into a spec in the issue tracker | mattpocock |
| `to-tickets` | Breaks a plan into tracer-bullet tickets with their blocking edges | mattpocock |
| `ui-ux-pro-max` | A local UI/UX database plus a registry of external component sources | [nextlevelbuilder](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) and others; see Attribution |
| `validate-prompt-rules` | A/B tests whether a prompt rule changes model behaviour at all | — |
| `wait-what` | Re-pitches a message that did not land | mattpocock |
| `writing-for-agents` | Rules for any document an agent reads | mattpocock |

The `mattpocock` rows started as [mattpocock/skills](https://github.com/mattpocock/skills) and were rewired here: `ecp` commands replace subjective judgement calls, and the dispatch sentences point back at `CLAUDE.md`. Re-install from upstream by rebuilding on the upstream file and re-applying those edits, not by overwriting.

The `BeautifulRust` rows start from [morganlinton/BeautifulRust](https://github.com/morganlinton/BeautifulRust) v1.4.0 (commit `c6f56d2`, MIT). Its `rust-review` skill is folded into `skills/simplify/rust.md`. `skills/rust-best-practices/measurements.md` lists every deliberate divergence from upstream; read it before you sync.

## Install

```bash
git clone <this repo> ~/claude-setup
cp -r ~/claude-setup/{CLAUDE.md,RTK.md,ECP.md,maintainer-notes.md,maintainer-notes-archive.md,agents,hooks,mods,output-styles,skill_script,skills} ~/.claude/
cp ~/claude-setup/settings.example.json ~/.claude/settings.json
```

Then edit `~/.claude/settings.json`: replace `<YOUR_CONTEXT7_API_KEY>`, and expand `$HOME` in the hook paths if your shell does not.

Mods are an early-access Claude Code feature. `mods/token-saver/.claude-plugin/types/` is generated on your machine and not shipped, so `tsconfig.json` resolves only after that directory exists. The mod runs without it. To turn the mod off, remove `CLAUDE_CODE_PLUGIN_DIRS` from `env`.

`settings.example.json` is this machine's `settings.json` with that one key blanked and `$HOME` put back where the absolute path was. It sets `modelSettings` rather than `model`, so it pins an effort level per model and leaves the model itself to whatever the CLI last selected. Add `"model": "opus[1m]"` if you want it fixed.

`CLAUDE.md` settles Python 3.14 syntax arguments by running [`pyci-check`](https://github.com/coseto6125/pyci-check), so install it or that rule has nothing to point at. The programs the hooks call are listed under Security notes and none of them ship here either.

## Vendored third-party skills

`skills/seo` and 30 of the `skills/seo-*` directories come from [`claude-seo`](https://github.com/AgriciDaniel/claude-seo) v2.3.1 by AgriciDaniel, MIT-licensed. Every one of their 31 `SKILL.md` files adds `disable-model-invocation: true`, so the 31 descriptions stay out of the routing context until you call a skill by name. 23 of those files also have edited bodies: all-caps emphasis toned down, contradictory lines removed, and the AI-crawler material in `seo-technical` moved into references. The other 8 differ from the upstream tag only in the paths the installer rewrites. `skills/seo-lite` is written here from the same material and keeps only the on-page and JSON-LD checks. They sit here so one clone reproduces the whole machine, not because they were written for it. Two directories the upstream install creates are excluded: `seo/.venv` (777 MB) and `seo/ms-playwright` (656 MB). Install those from the upstream repo, or run `skills/seo/bin/claude-seo` and let it build them. `seo/runtime-state.json` is machine state and is excluded too.

Upgrade by re-installing from upstream, then re-apply the `SKILL.md` edits above; diff against the upstream tag to find them.

## Security notes

These are properties of this configuration, not defects. Read them before you copy anything into `~/.claude`.

**`settings.example.json` turns the permission prompts off.** It carries `"defaultMode": "bypassPermissions"` together with `"skipDangerousModePermissionPrompt": true` and `"skipAutoPermissionPrompt": true`. Copied as-is, Claude Code runs shell commands, edits files and reaches the network with no confirmation step. That suits one machine whose owner watches every session, and it removes a safety boundary everywhere else. Set `"defaultMode": "default"` and drop both `skip*` keys unless you want the same trade.

**The permission lists gate almost nothing.** `settings.example.json` ships no `allow` list, `deny` holds only `SendFeedback`, and `ask` is empty. Combined with the mode above, every other tool call runs unasked. Add `deny` and `ask` entries for what you want stopped.

**Hooks execute on every matching event.** `hooks/` holds twenty-one scripts and `settings.example.json` wires sixteen of them:

| Event | Scripts |
| --- | --- |
| `PreToolUse` | `guard-push-simplify.sh`, `guard-main-edit.sh`, `limit-worktrees.sh`, `guard-podman-prune.sh`, `guard-cargo-disk.sh` |
| `PostToolUse` | `lang-anchor.sh`, `audit-skill.sh`, `review-hook-edit.sh` |
| `PostToolUseFailure` | `loop-guard.py` |
| `Stop`, `PostCompact` | `idle-guard-stop.sh` |
| `UserPromptSubmit` | `idle-guard-submit.sh`, `lang-anchor.sh` |
| `SessionStart` | `patch-tool-persist.py`, `prune-scratchpad.sh`, `guard-rtk-hook.sh`; on `compact` also `compact-handoff-nudge.sh` and `lang-anchor.sh` |
| `SubagentStart`, `SubagentStop` | `track-subagents.sh` |

Read each one before you install it. `guard-main-edit.sh` enforces a rule `CLAUDE.md` only states — it refuses an edit to a file on the default branch and prints the worktree command to use instead. `guard-push-simplify.sh` blocks `rm -r` on a path built from a variable or a glob, and blocks `git push` until `skills/simplify/review-mark.sh` has recorded that a review covered the content the push sends. `guard-podman-prune.sh` blocks an unfiltered "remove all images" on podman or docker. `guard-cargo-disk.sh` blocks a compiling cargo command while a sub-agent that `track-subagents.sh` recorded can still edit files, blocks a `cargo test` with no test-thread cap, and checks free disk space. `loop-guard.py` adds a note to switch strategy when the same tool call fails the same way a third time. The Bash rewrite runs as `etoon hook claude`, which calls `rtk` itself, so wire no separate rtk hook: Claude Code applies only one `updatedInput` per tool call. `guard-rtk-hook.sh` warns at startup when `settings.json` holds that separate entry, which `rtk init -g --auto-patch` adds. `settings.example.json` also runs `skill_script/sweep-merged-worktrees.sh` on `SessionStart`: at most once per 12 hours per repo, it removes each idle, clean worktree whose PR merged at least 2 hours ago at the local tip, and deletes that branch. Run it with `--dry-run` to see what it would remove. The hooks and scripts assume Linux: GNU coreutils, `flock` and bash 5. `prune-scratchpad.sh` deletes every session temp directory under `$CLAUDE_CODE_TMPDIR` in which nothing changed for 14 days (`SCRATCH_KEEP_DAYS`), so a file you parked in a scratchpad is gone two weeks after its session last wrote there. Run it with `--dry-run` first to see the list.

The other five ship unwired, so wire them yourself or delete them. `ecp-graph-nudge.sh` hands over the exact `ecp impact` command a symbol's direct callers cannot answer on their own; ecp's own `ecp hook` entries replace it here. `worktree-symlinks.sh` is another. The three `eywa-*.sh` scripts are the rest: they inject coding principles on `UserPromptSubmit`, capture them on `Stop`, and clear the session cache on `PreCompact`. They read `$HOME/.eywa/` and query a local server on `127.0.0.1:8788`; without that server running, `eywa-inject.sh` is a no-op.

**Several programs run from hooks and none of them ships here** (`eywa` is wired by nothing in `settings.example.json`): `etoon` and the `rtk` it calls on `PreToolUse`, `$HOME/.claude/bin/cc-auto-etoon` as the `--pre` rewriter of that entry and inside `guard-cargo-disk.sh`, `$HOME/.local/bin/ecp` on `PreToolUse`, `PostToolUse`, `SessionStart` and `UserPromptSubmit`, and `$HOME/.orca/agent-hooks/claude-hook.sh` on sixteen events. Only the Orca one tests for the file first: it branches on `$OSTYPE`, runs the `.cmd` variant on Windows shells, and falls back to draining stdin and printing `{}` when the file is missing. The `ecp` and `etoon` entries have no guard at all, so a missing binary is a failed hook rather than a no-op. `guard-cargo-disk.sh` fails closed: without `cc-auto-etoon` it reads every command that mentions cargo as an uncapped compile and blocks it. `settings.example.json` also sets `~/.claude/bin/cc-statusline` as the status line, and that program is not in this repo either. Install those programs, or delete the entries.

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

These numbers predate later edits to the `CLAUDE.md` family and the skills. Re-run the command above to get the figure for this tree.

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

- `skills/ui-ux-pro-max/{data,scripts,references}` come wholesale from [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill). `SKILL.md` is rewritten here. `local/` folds in other sources, each named at the top of its file: [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (`anti-patterns.md`), tdimino's `design-critique` and `minoan-frontend-design` (`critique-framework.md` and the references it lists), Google Labs' [DESIGN.md](https://github.com/google-labs-code/design.md) format (`design-md.md`) and W3C [clreq](https://www.w3.org/TR/clreq/) (`cjk-line-breaking.md`). `local/sources.md` registers external component and icon sources with their licenses.
- `skills/writing-for-agents` cites [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) for the ASD-STE100 summary.
- `skills/eli5` comes from [DreambigOu/ELI5](https://github.com/DreambigOu/ELI5), MIT, merged with the output-shape rules of [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd), MIT, Ayoub Ghriss.
- `skills/rust-best-practices`, `skills/rust-port` and `skills/simplify/rust.md` come from [morganlinton/BeautifulRust](https://github.com/morganlinton/BeautifulRust), MIT, Morgan Linton, with the local changes that `skills/rust-best-practices/measurements.md` lists.
- `skills/{agent-routing,peer-agent}` drive the Orca agent runner and assume it is installed.
- Orca's own `orchestration`, `orca-cli` and `computer-use` skills come from [stablyai/orca](https://github.com/stablyai/orca) and Orca installs them into `~/.agents/skills/` itself, so they are not copied here. `agent-routing` quotes three sentences from Orca's orchestration guide and re-checks them with its own `check-anchors.sh`; that guide ships inside the Orca binary and is read with `orca-ide skills get orchestration`, so it moves with the app rather than with any file.

## Removed before publishing

Skills that only run against one private workspace, a set of hooks that forwarded conversation text to a local HTTP service together with the `CLAUDE.md` section that made that service's replies authoritative, the `CLAUDE.md` section and the `settings.json` entries for a private MCP server, the auto-memory directory, and the real `settings.json` with its API key.

The history was rebuilt from a single commit for the same reason. An earlier published history carried absolute home paths, a private Notion database and owner ID, and internal project names.
