#!/usr/bin/env bash
# SubagentStart / SubagentStop hook: keep one marker file per running sub-agent that can edit
# files, so guard-cargo-disk.sh can block cargo while an agent's edits are half written.
# Marker: ~/.cache/claude-agents/<session_id>/<agent_id>, content = agent_type.
# Read-only agent types get no marker. A marker older than 90 minutes counts as stale
# (an agent killed without SubagentStop); guard-cargo-disk.sh ignores it.

set -uo pipefail

input=$(cat)
event=$(jq -r '.hook_event_name // ""' <<<"$input")
session=$(jq -r '.session_id // ""' <<<"$input")
agent=$(jq -r '.agent_id // ""' <<<"$input")
type=$(jq -r '.agent_type // ""' <<<"$input")
[[ "$session" =~ ^[A-Za-z0-9_-]+$ && "$agent" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

dir="$HOME/.cache/claude-agents/$session"
case "$event" in
  SubagentStart)
    case "$type" in
      Explore|Plan|lite-scan|deep-review|claude-code-guide|statusline-setup) exit 0 ;;
    esac
    mkdir -p "$dir" && printf '%s\n' "${type:-unknown}" > "$dir/$agent"
    ;;
  SubagentStop)
    rm -f -- "$dir/$agent"
    ;;
esac
exit 0
