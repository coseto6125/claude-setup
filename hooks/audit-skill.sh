#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): audit a SKILL.md the moment it is written.
# The rules it checks are the measurable ones; route.sh covers the behavioural rest.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in */SKILL.md) ;; *) exit 0 ;; esac

AUDIT="$HOME/.claude/skills/writing-for-agents/audit.py"
[ -x "$AUDIT" ] || exit 0

findings=$(python3 "$AUDIT" "$file" 2>/dev/null) || true
refs=$(python3 "$AUDIT" refs 2>/dev/null) || true
case "$refs" in clean) ;; *) findings="$findings\n$refs" ;; esac
findings=$(printf '%b' "$findings" | grep -v '^clean$' || true)
case "$findings" in ''|*clean) exit 0 ;; esac

reason="skill audit — $file
$findings

Rule text: ~/.claude/skills/writing-for-agents/SKILL.md. Fix or state why the finding does not apply."

# stdout JSON is the Prime Agent protocol; stderr + exit 2 is the Claude Code one.
jq -nc --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$r}}'
printf '%s\n' "$reason" >&2
exit 2
