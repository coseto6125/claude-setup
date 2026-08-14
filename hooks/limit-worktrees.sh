#!/usr/bin/env bash
# PreToolUse hook: block `git worktree add` when ≥ THRESHOLD worktrees exist.
# Prints reuse advice to stderr; Claude sees it via exit 2.

set -euo pipefail

THRESHOLD=200

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

if ! [[ "$cmd" =~ git[[:space:]]+worktree[[:space:]]+add ]]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

count=$(git worktree list | wc -l)

if [ "$count" -lt "$THRESHOLD" ]; then
  exit 0
fi

{
  echo "⚠️  Worktree limit hit: $count existing worktrees (≥ $THRESHOLD)."
  echo ""
  echo "Existing worktrees (reuse via 'git -C <path> checkout <new-branch>' if clean):"
  git worktree list
  echo ""
  echo "Decision rule:"
  echo "  - Sequential task continuation → reuse current worktree, just 'git checkout <new-branch>'"
  echo "  - Parallel sub-agent dispatch on disjoint branches → open new (ephemeral, remove on done)"
  echo "  - CI wait + need to keep current target/ warm → open new"
  echo ""
  echo "Also consider cleaning merged-PR worktrees first (git worktree remove + git branch -D)."
  echo "To bypass this guard: set CLAUDE_ALLOW_WORKTREE_ADD=1 in the command env."
} >&2

# Bypass escape hatch — prefix the bash command with the env var literal
if [[ "$cmd" == CLAUDE_ALLOW_WORKTREE_ADD=1* ]]; then
  exit 0
fi

exit 2
