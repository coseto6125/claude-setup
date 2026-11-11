#!/usr/bin/env bash
# After a compaction, ask the main session to decide whether a fresh session takes over.
# Fires on the 5th compaction, then on every 3rd after it: a session that is mid-task when the
# reminder lands gets it again later.
# Counts the transcript's compact_boundary entries. The boundary is written before this hook
# runs (transcript order checked 2026-11-07). grep skips the other lines of a transcript that
# reaches 100 MB; jq confirms the entry type, so a line that carries the string in another field
# never counts.
# Skip inside a subagent (agent_id present): only the main session hands off.
first=5 every=3
transcript=$(jq -r 'select((.agent_id // "") == "") | .transcript_path // empty' 2>/dev/null)
[ -n "$transcript" ] && [ -r "$transcript" ] || exit 0
k=$(grep -aF -- '"compact_boundary"' "$transcript" \
  | jq -cR 'fromjson? | select(.type == "system" and .subtype == "compact_boundary")' | wc -l)
(( k >= first && (k - first) % every == 0 )) || exit 0
jq -nc --argjson k "$k" --arg skill "$HOME/.claude/skills/handoff/SKILL.md" '
  {hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: (
    "Compaction reminder: this session has been compacted \($k) times. "
    + "Decide now whether a fresh session takes over the work.\n"
    + "Hand off when most of these hold:\n"
    + "- The remaining work needs more than one more compaction.\n"
    + "- You re-read files or re-derive facts that the summary dropped.\n"
    + "Continue when the work ends before the next compaction.\n"
    + "Tell the user your decision and its reason in one sentence.\n"
    + "To hand off, read \($skill) and follow it, including its section \"Start the next session\".")}}' \
  2>/dev/null || true
