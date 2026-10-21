#!/usr/bin/env bash
# Run a feedback-loop command N times and report its verdicts and speed.
# Usage: loop.sh <runs> <command> [args...]
# A non-zero exit is red. The loop is tight when every run gives the same verdict.
set -uo pipefail

[[ $# -ge 2 && $1 =~ ^[1-9][0-9]*$ ]] || { echo "usage: loop.sh <runs> <command> [args...]" >&2; exit 2; }
runs=$1; shift
out=$(mktemp)
red=0; green=0; times=()
for ((i = 1; i <= runs; i++)); do
  start=${EPOCHREALTIME/[.,]}                   # microseconds, no fork inside the timed window
  if "$@" >"$out" 2>&1; then
    green=$((green + 1))
  else
    red=$((red + 1))
    # Keep the first red output: it is the symptom to compare against the user's report.
    [[ -f $out.red ]] || cp "$out" "$out.red"
  fi
  times+=($(( (${EPOCHREALTIME/[.,]} - start) / 1000 )))
done

median=$(printf '%s\n' "${times[@]}" | sort -n | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}')
verdict=flaky
(( red == runs )) && verdict=always-red
(( green == runs )) && verdict=always-green
echo "runs=$runs red=$red green=$green verdict=$verdict median_ms=$median"
if [[ -f $out.red ]]; then
  echo "--- first red output (last 20 lines) ---"
  tail -n 20 "$out.red"
  rm -f "$out.red"
fi
rm -f "$out"
