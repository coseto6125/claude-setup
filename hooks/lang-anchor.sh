#!/usr/bin/env bash
# Re-state the reply language at each user turn, after compaction, and after each tool result.
# Long sessions drift to English after English tool output; the system prompt sits too far back to hold it.
# Drift sits mid-turn (after tool results), so PostToolUse carries the anchor there too.
# Skip inside a subagent (agent_id present): its report goes to the main model, not the user.
# One jq call: this runs after every tool result.
jq -c --arg e "$1" --slurpfile s ~/.claude/settings.json '
  select((.agent_id // "") == "") | ($s[0].language // "") as $l | select($l != "")
  | {hookSpecificOutput: {hookEventName: $e,
     additionalContext: ("Write every text block the user sees in " + $l + ", including a one-line note between tool calls. Keep thinking and sub-agent prompts in English.")}}' 2>/dev/null || true
