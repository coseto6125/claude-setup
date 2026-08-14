#!/usr/bin/env bash
# PreToolUse(Bash): block `git push` until /simplify ran in this session.
# CLAUDE.md "Important Reminders" states the rule; this hook makes it happen.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

is_git_push() {
  local seg tok sub skip=0
  # split on ; && || | and test each segment
  while IFS= read -r seg; do
    sub=""; skip=0
    set -- $seg
    while [ $# -gt 0 ]; do
      tok=$1; shift
      case "$tok" in
        *=*) [ -z "$sub" ] && continue ;;          # leading VAR=value
      esac
      if [ "$skip" = 1 ]; then skip=0; continue; fi
      case "$tok" in
        git) sub="git"; continue ;;
        -C|-c) [ "$sub" = git ] && skip=1; continue ;;
        -*) continue ;;
      esac
      if [ "$sub" = git ]; then
        [ "$tok" = push ] && return 0
        break
      fi
    done
  done < <(printf '%s\n' "$cmd" | sed 's/&&/\n/g; s/||/\n/g; s/[;|]/\n/g')
  return 1
}

is_git_push || exit 0
[[ "$cmd" =~ --dry-run ]] && exit 0
[[ "${CLAUDE_SKIP_SIMPLIFY:-}" == "1" || "$cmd" == CLAUDE_SKIP_SIMPLIFY=1* ]] && exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
if [ -n "$transcript" ] && [ -r "$transcript" ]; then
  grep -qF 'skills/simplify' "$transcript" && exit 0
fi

reason=$(cat <<'EOF'
Blocked: this session has no /simplify run before the push.

Review work to do first — the skill at ~/.claude/skills/simplify/SKILL.md:
spec conformance, bugs, reuse, quality, efficiency on the current diff.

Then push again. Escape hatch for a push that carries no code change
(tag, branch delete, already-reviewed rebase): prefix the command with
  CLAUDE_SKIP_SIMPLIFY=1
EOF
)

# stdout JSON is the Prime Agent protocol; stderr + exit 2 is the Claude Code one.
jq -nc --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
printf '%s\n' "$reason" >&2
exit 2
