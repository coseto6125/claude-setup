#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): after the first edit of a hook in a session, ask for bypass tests and a review.
# Silent for test files, for every other path, and for the same hook again in the same session.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in */.claude/hooks/tests/*) exit 0 ;; */.claude/hooks/*) ;; *) exit 0 ;; esac

session=$(printf '%s' "$input" | jq -r '.session_id // ""')
if [ -n "$session" ]; then
  dir="$HOME/.cache/claude-hook-review"; mkdir -p "$dir" 2>/dev/null || exit 0
  mark="$dir/$(printf '%s\n%s' "$session" "$file" | sha1sum | cut -c1-16)"
  ( set -o noclobber; : > "$mark" ) 2>/dev/null || exit 0   # atomic claim: parallel edits remind once
fi

reason="You changed the hook $file.
Before you report it done:
1. Add a test under the hooks tests/ directory for each spelling that simplify CHECKLIST.md Security rung 14 lists. Each test must fail without your change.
2. Run /simplify on the hook change. Run its codex leg for every hook change, whatever the size tier.
   Word the codex brief as a parser-correctness review (where does the parse disagree with bash?). Codex refuses a brief that asks for bypasses or attacks."

jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$r}}'
