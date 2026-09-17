#!/usr/bin/env bash
# usage: prune-scratchpad.sh [--dry-run]
# Deletes Claude Code session temp dirs (<root>/<project>/<session>/, which hold scratchpad/ and tasks/)
# when nothing inside them changed in SCRATCH_KEEP_DAYS days (default 14), then removes emptied project dirs.
# Root: SCRATCH_ROOT, else $CLAUDE_CODE_TMPDIR/claude-<uid>, else /tmp/claude-<uid>.
# The current session (CLAUDE_CODE_SESSION_ID) is always kept. Files directly under the root are left alone.
# As a SessionStart hook it forks the work and prints nothing, because hook stdout lands in the session context.
# SCRATCH_FOREGROUND=1 runs it in the foreground, for tests.
# Known gap: a session idle for the whole window that resumes between the scan and the rm loses the files it just wrote.
set -u
root=${SCRATCH_ROOT:-${CLAUDE_CODE_TMPDIR:-/tmp}/claude-$(id -u)}
days=${SCRATCH_KEEP_DAYS:-14}
dry=0; [ "${1:-}" = --dry-run ] && dry=1
[[ "$days" =~ ^[0-9]+$ ]] && [ -d "$root" ] || exit 0
mins=$((10#$days * 1440))   # 10# keeps 08 and 010 decimal; bash reads a leading zero as octal

prune() {
  local session project recent old_projects=()
  # Read project ages before pruning: deleting a session dir touches its project dir's mtime.
  while IFS= read -r -d '' project; do old_projects+=("$project"); done \
    < <(find "$root" -mindepth 1 -maxdepth 1 -type d ! -mmin -"$mins" -print0 2>/dev/null)
  for session in "$root"/*/*/; do
    session=${session%/}
    # A symlinked project or session dir leads outside the root, so neither is followed.
    [ -d "$session" ] && [ ! -L "$session" ] && [ ! -L "$(dirname "$session")" ] || continue
    [ "$(basename "$session")" = "${CLAUDE_CODE_SESSION_ID:-}" ] && continue
    # Any entry newer than the cutoff keeps the session, the session dir itself included, so a just-created empty dir survives.
    # A scan that errors proves nothing about age, so the session stays.
    recent=$(find "$session" -mmin -"$mins" -print -quit 2>/dev/null) || continue
    [ -n "$recent" ] && continue
    if [ "$dry" = 1 ]; then du -sh "$session" 2>/dev/null; else rm -rf -- "$session" 2>/dev/null; fi
  done
  [ "$dry" = 1 ] && return
  # A project dir a starting session just created is new, so only an old one that is now empty goes.
  for project in "${old_projects[@]}"; do rmdir -- "$project" 2>/dev/null; done
}

if [ "$dry" = 1 ] || [ -t 1 ] || [ "${SCRATCH_FOREGROUND:-0}" = 1 ]; then prune; else (prune >/dev/null 2>&1 &); fi
exit 0
