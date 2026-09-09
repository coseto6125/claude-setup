#!/usr/bin/env bash
# PreCompact hook: clear session cache so post-compact prompts can re-inject
# the principles that just dropped out of the compressed context.

set -eo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && exit 0

rm -f "$HOME/.eywa/session_cache/$session_id.txt"
