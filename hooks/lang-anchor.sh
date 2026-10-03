#!/usr/bin/env bash
# Re-state the reply language at each user turn and after compaction.
# Long sessions drift to English after English tool output; the system prompt sits too far back to hold it.
lang=$(jq -r '.language // empty' ~/.claude/settings.json)
[ -z "$lang" ] && exit 0
jq -nc --arg e "$1" --arg l "$lang" '{hookSpecificOutput: {hookEventName: $e,
  additionalContext: ("Write every text block the user sees in " + $l + ", including a one-line note between tool calls. Keep thinking and sub-agent prompts in English.")}}'
