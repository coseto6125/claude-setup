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

# Inject only when a hit is an identifier the command itself names. A hit counts when its name has an
# inner underscore or camelCase and appears as a whole word in the command. Plain words (debug, info,
# create, node) matched log greps and git calls: 2026-09-23, 50 sessions, 1,710 injections, 1 in 20
# relevant; this gate keeps 211 of them.
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
symbol=""
while IFS= read -r name; do
  printf '%s' "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' || continue
  printf '%s' "$name" | grep -Eq '[A-Za-z0-9]_[A-Za-z0-9]|[a-z][A-Z]' || continue
  printf '%s' "$cmd" | grep -Fqw -- "$name" || continue
  symbol=$name; break
done < <(printf '%s' "$context" | sed -n 's/^[[:space:]]\{2\}\([^[:space:]]*\) (.*/\1/p')
[ -n "$symbol" ] || exit 0

read -r -d '' nudge <<EOF || true
$context
  -- Those callers are the d=1 slice. Full blast radius, cross-file callers and entry points:
     ecp impact --target $symbol --direction upstream --repo .
EOF

printf '%s' "$out" | jq -c --arg c "$nudge" '.hookSpecificOutput.additionalContext = $c'
