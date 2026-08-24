#!/usr/bin/env bash
# ecp adoption, the two numbers that separate a formed reflex from a hook doing the work.
# usage: ecp-adoption.sh [days]   (default 21, the window the 2026-08-15 baseline used)
set -euo pipefail
DAYS="${1:-21}"
cd "$HOME/.claude/projects"
FILES=$(find . -name '*.jsonl' -mtime "-$DAYS")
count() { { echo "$FILES" | xargs rg -c --no-filename -e "$1" 2>/dev/null || true; } | awk '{s+=$1}END{print s+0}'; }

ecp=$(count '"command":"(cd [^;]*&& )?ecp ')
grep_=$(count '"command":"(cd [^;]*&& )?grep ')
hits=$(count 'ecp graph hits')
impact=$(count '"command":"(cd [^;]*&& )?ecp impact')

printf 'window: last %s days\n' "$DAYS"
printf 'ecp called      : %s\n' "$ecp"
printf '  of which impact: %s\n' "$impact"
printf 'leading grep    : %s\n' "$grep_"
printf 'hook graph hits : %s\n' "$hits"
awk -v e="$ecp" -v g="$grep_" 'BEGIN{printf "reflex share    : %.1f%% (ecp / (ecp+grep))\n", (g+e)?100*e/(e+g):0}'
echo
echo 'Baseline 2026-08-15, before the Bash hook: ecp 140, grep 5296, share 2.6%.'
echo 'A rising hits count with a flat ecp count means the hook answers instead of teaching.'
