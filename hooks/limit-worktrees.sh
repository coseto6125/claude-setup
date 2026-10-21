#!/usr/bin/env bash
# PreToolUse hook: block `git worktree add` when ≥ THRESHOLD worktrees exist.
# Prints reuse advice to stderr; Claude sees it via exit 2.

set -euo pipefail

THRESHOLD=200

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only git options may sit between git and the subcommand (git -c k=v -C <dir> worktree add),
# so `git commit -m '… worktree add …'` does not match.
opts='([[:space:]]+(-[Cc][[:space:]]+[^[:space:];&|]+|-[^[:space:];&|]*))*'
add_re="(^|[^[:alnum:]_-])git${opts}[[:space:]]+worktree[[:space:]]+add"
if ! [[ "$cmd" =~ $add_re ]]; then
  exit 0
fi

# Bypass: the env var literal anywhere in the command (after a cd, a git -C, a subshell)
if [[ "$cmd" == *CLAUDE_ALLOW_WORKTREE_ADD=1* ]]; then
  exit 0
fi

# Count the worktrees of the repo the command names with -C, else of the cwd.
# A -C target that does not resolve (spaces, a variable) falls back to the cwd.
repo=.
dir_re='git([[:space:]]+(-c[[:space:]]+[^[:space:];&|]+|-[^C[:space:];&|][^[:space:];&|]*))*[[:space:]]+-C[[:space:]]+([^[:space:];&|]+)'
if [[ "$cmd" =~ $dir_re ]]; then
  repo=${BASH_REMATCH[3]}; repo=${repo#[\"\']}; repo=${repo%[\"\']}; repo=${repo/#\~/$HOME}
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || repo=.
fi
if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

count=$(git -C "$repo" worktree list | wc -l)

if [ "$count" -lt "$THRESHOLD" ]; then
  exit 0
fi

{
  echo "⚠️  Worktree limit hit: $count existing worktrees (≥ $THRESHOLD)."
  echo ""
  echo "Existing worktrees (reuse via 'git -C <path> checkout <new-branch>' if clean):"
  git -C "$repo" worktree list
  echo ""
  echo "Decision rule:"
  echo "  - Sequential task continuation → reuse current worktree, just 'git checkout <new-branch>'"
  echo "  - Parallel sub-agent dispatch on disjoint branches → open new (ephemeral, remove on done)"
  echo "  - CI wait + need to keep current target/ warm → open new"
  echo ""
  echo "Clean idle worktrees whose work is already pushed or merged, from the repo directory:"
  echo "  bash ~/.claude/skill_script/sweep-merged-worktrees.sh --dry-run   # list"
  echo "  bash ~/.claude/skill_script/sweep-merged-worktrees.sh --force     # remove"
  echo "To bypass this guard: put CLAUDE_ALLOW_WORKTREE_ADD=1 in the command."
} >&2

exit 2
