# Knobs

This is a settings reference, not a list of recommended changes. The `Verified` column records the original documentation or measurement source; check support and behavior in the user's installed version before relying on a knob. Doc pages live under `https://code.claude.com/docs/en/`.

## Fixed cost (paid every session)

| Item | Knob | Semantics | Verified |
|---|---|---|---|
| Built-in tool schema | `permissions.deny: ["Tool"]` in settings, or `--disallowedTools Tool` at launch | A bare tool name removes the schema from context. A scoped rule such as `Tool(spec)` keeps the schema and blocks only matching calls. Needs a restart. `EndConversation` cannot be removed. | `permissions.md`; verify schema savings with a local comparison |
| Bundled skill description | `skillOverrides: {"name": "<state>"}` in settings | States: `on` (name + description), `name-only`, `user-invocable-only` (hidden from the model, in the `/` menu), `off` (hidden from both). `/skills` menu writes it with Space and Esc. | `skills.md#override-skill-visibility-from-settings` |
| All bundled skills at once | `disableBundledSkills: true` | Disables every bundled skill except `/doctor`. Use only when no bundled skill is wanted. | `settings-reference.md` |
| User or project skill description | `disable-model-invocation: true` in the SKILL.md frontmatter | Same effect as `user-invocable-only`, held in the skill itself. | `skills.md` |
| Duplicate CLAUDE.md on the load chain | `claudeMdExcludes: ["<absolute glob>"]` in settings | Claude Code loads `CLAUDE.md` and `CLAUDE.local.md` from the cwd and every ancestor. The glob matches absolute paths and merges across scopes. Managed-policy files cannot be excluded. | `memory.md#exclude-specific-claude-md-files` |
| MCP tool schemas | Tool search (`ENABLE_TOOL_SEARCH`) | Deferred schemas cost 0 until loaded through ToolSearch. The default already defers. | `mcp.md#scale-with-mcp-tool-search` |

## Variable cost (grows with the session)

| Item | Knob | Semantics | Verified |
|---|---|---|---|
| Bash output ceiling | `bashOutputMaxChars` in settings (2.1.261+); older: env `BASH_MAX_OUTPUT_LENGTH` | Default 30,000 chars, ceiling 128,000. A failed command keeps about 10,000 chars inline. | `tools-reference.md#output-limits` |
| MCP result ceiling | env `MAX_MCP_OUTPUT_TOKENS` | Default 25,000 tokens. Above it the result goes to a file and the path returns. | `mcp.md` |
| Auto-compact trigger | `autoCompactWindow` in settings, `/autocompact 500k`, `--autocompact`, or env `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | A token count between 100K and 1M. Default sits near the model limit. Earlier compaction lowers per-turn input at the price of summary fidelity. | `model-config.md#set-the-auto-compact-window` |
| Sub-agent returns | none | No setting truncates or summarises them. The return contract in the dispatch prompt is the only lever. | `sub-agents.md` |

## Choosing candidates

Build the candidate list from the current session's inventory and the user's goal, following Step 3 in `SKILL.md`. There is no default deny list or transferable token-saving table: availability and measured costs depend on the installed version, model and session configuration.

## Measurement notes

- Input volume is not billed cost: distinguish uncached input, cache creation and cache reads when discussing monetary savings. Headless and interactive sessions may expose different tools.
- Use Step 4 in `SKILL.md` to interpret history evidence before making recommendations.
- Prefer the session's `/context all` breakdown for skill description tokens. File bytes and character counts are size measurements, not token counts.
