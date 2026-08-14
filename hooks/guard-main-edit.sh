#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit): block the first edit on a protected
# branch of a repo that has a remote. CLAUDE.md "Branch Discipline" states the rule;
# this hook makes it happen. Remote-less repos (scratchpads) are not guarded.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
[ -n "$file" ] || exit 0
[[ "${CLAUDE_ALLOW_MAIN_EDIT:-}" == "1" ]] && exit 0

dir=$(dirname "$file")
while [ ! -d "$dir" ] && [ "$dir" != "/" ]; do dir=$(dirname "$dir"); done

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$root" branch --show-current 2>/dev/null) || exit 0
case "$branch" in main|master|develop) ;; *) exit 0 ;; esac
[ -n "$(git -C "$root" remote)" ] || exit 0

reason=$(cat <<EOF
Blocked: '$file' sits on protected branch '$branch' in $root.

Branch off before the first edit, whatever the work type — feature, bug fix,
docs-only, config-only, one-line fix all take a branch:
  git -C '$root' worktree add ../<slug> -b <feat|fix|chore|perf>/<slug>
then edit the file at that path instead.

Escape hatch when the user asked to commit straight on '$branch':
  CLAUDE_ALLOW_MAIN_EDIT=1 in the hook env.
EOF
)

# stdout JSON is the Prime Agent protocol; stderr + exit 2 is the Claude Code one.
jq -nc --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
printf '%s\n' "$reason" >&2
exit 2
