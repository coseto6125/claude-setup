#!/usr/bin/env bash
# Re-state the reply language at each user turn, after compaction, and after each tool result.
# Long sessions drift to English after English tool output; the system prompt sits too far back to hold it.
# Drift sits mid-turn (after tool results), so PostToolUse carries the anchor there too.
# Skip inside a subagent (agent_id present): its report goes to the main model, not the user.
# The anchor itself is written in Chinese: it is the last text before the next block, and an English
# anchor primes English (scan 2026-11-05: 16.2% English right after a tool result with no thinking,
# 2.6% with a thinking block first, so the anchor asks for one short thought before the text).
# One jq call: this runs after every tool result.
jq -c --arg e "$1" --slurpfile s ~/.claude/settings.json '
  select((.agent_id // "") == "") | ($s[0].language // "") as $l | select($l != "")
  | {hookSpecificOutput: {hookEventName: $e,
     additionalContext: ("給使用者看的文字一律用" + $l + "，寫之前先想一句。")}}' 2>/dev/null || true
