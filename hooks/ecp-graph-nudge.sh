#!/usr/bin/env bash
# PreToolUse(Bash): ecp's graph hits, plus the command that answers what they cannot.
# The hits are a d=1 slice. Blast radius, entry points and cross-file callers need
# `ecp impact`, so the hook hands over the exact command with the symbol filled in.
set -euo pipefail

ECP="${ECP_BIN:-$HOME/.local/bin/ecp}"
[ -x "$ECP" ] || exit 0

input=$(cat)
out=$(printf '%s' "$input" | "$ECP" hook pre-tool-use --claude-code 2>/dev/null) || exit 0
[ -n "${out//[[:space:]]/}" ] || exit 0

context=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""')
[ -n "$context" ] || { printf '%s' "$out"; exit 0; }

# Symbol lines look like "  name (path:line) [Kind]"; take the first, it is the hit ecp ranked highest.
symbol=$(printf '%s' "$context" | sed -n 's/^[[:space:]]\{2\}\([A-Za-z_][A-Za-z0-9_]*\) (.*/\1/p' | head -1)
[ -n "$symbol" ] || { printf '%s' "$out"; exit 0; }

read -r -d '' nudge <<EOF || true
$context
  -- Those callers are the d=1 slice. Full blast radius, cross-file callers and entry points:
     ecp impact --target $symbol --direction upstream --repo .
EOF

printf '%s' "$out" | jq -c --arg c "$nudge" '.hookSpecificOutput.additionalContext = $c'
