#!/usr/bin/env bash
# Idle-guard (Stop): a completed turn refreshes the activity timestamp to the
# turn-end time. This matters for long agentic turns whose API requests keep the
# cache warm well past the user's original submit -- without it, idle would be
# measured from the submit and false-block the next prompt.

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null || echo default)
[ -z "$sid" ] && sid=default
# State lives under the user's own directory, never a world-writable /tmp path.
# The session id falls back to "default", so a shared /tmp would give any local
# account a predictable name to pre-empt with a symlink.
state_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-idle-guard"
mkdir -p "$state_dir" 2>/dev/null || exit 0
date +%s > "$state_dir/${sid}.last"
exit 0
