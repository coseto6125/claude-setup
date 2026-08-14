#!/usr/bin/env bash
# Cross-model A/B harness for prompt rules.
# usage: ab.sh <scenario-file> <ask-file> <scorer.py> <n> <arm-name>=<arm-file|EMPTY> ...
# Runs every arm on opus, sonnet and haiku, n trials each, in parallel.
# Isolation: empty cwd + --setting-sources project, per the validate-prompt-rules skill.
set -u
SCN_F="$1"; ASK_F="$2"; SCORER="$3"; N="$4"; shift 4
SCN=$(cat "$SCN_F"); ASK=$(cat "$ASK_F")
WORK=$(mktemp -d)
cp "$SCORER" "$WORK/score.py"

# canary: prove the user CLAUDE.md is not leaking into any arm
CAN=$(cd "$WORK" && claude -p "One sentence, no tools: do you have a global instruction preferring 'ecp' over grep? Yes or no." \
  --model haiku --setting-sources project 2>/dev/null | head -1)
case "$CAN" in
  [Nn]o*) echo "canary OK: $CAN";;
  *) echo "CANARY FAILED, isolation is contaminated: $CAN"; exit 1;;
esac

JOBS="$WORK/jobs"; : > "$JOBS"
for spec in "$@"; do
  arm="${spec%%=*}"; f="${spec#*=}"
  for model in ${MODELS:-opus sonnet haiku}; do
    for i in $(seq 1 "$N"); do
      printf '%s\t%s\t%s\t%s\n' "$arm" "$model" "$f" "$i" >> "$JOBS"
    done
  done
done

run_one() {
  IFS=$'\t' read -r arm model f i <<< "$1"
  local out rc
  if [ "$f" = "EMPTY" ]; then
    out=$(cd "$WORK" && claude -p "SITUATION: $SCN

$ASK" --model "$model" --setting-sources project 2>"$WORK/err.$$"); rc=$?
  else
    out=$(cd "$WORK" && claude -p "SITUATION: $SCN

$ASK" --model "$model" --setting-sources project --append-system-prompt "$(cat "$f")" 2>"$WORK/err.$$"); rc=$?
  fi
  # A failed or empty call is NOT a miss. Report it so a blip cannot read as "the rule stopped working".
  if [ $rc -ne 0 ] || [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
    printf '%s\t%s\tERR(rc=%s)\n' "$arm" "$model" "$rc"
    rm -f "$WORK/err.$$"; return
  fi
  rm -f "$WORK/err.$$"
  printf '%s\t%s\t%s\n' "$arm" "$model" "$(printf '%s' "$out" | python3 "$WORK/score.py")"
}
export -f run_one; export WORK SCN ASK

parallel_n=3
cat "$JOBS" | xargs -d '\n' -P "$parallel_n" -I{} bash -c 'run_one "$@"' _ {} | sort
rm -rf "$WORK"
