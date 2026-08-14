#!/usr/bin/env bash
# Isolated A/B validation of prompt rules against a clean no-rule baseline.
# Each probe = an isolated `claude -p` process with --setting-sources project, run from its
# OWN empty temp dir, so no user/project CLAUDE.md leaks into any arm. Arms are labeled —
# isolation, not blinding, is the guarantee.
#
# Usage: edit the spawn calls below, then:  bash -n validate.sh && bash validate.sh
#        The `-n` matters: bash parses this file incrementally, so a syntax error inside your
#        edited spawn block surfaces only AFTER the canary gate has run and probes have started
#        — burning trials and leaving no results file.
#
# ── TWO WAYS TO SUPPLY AN ARM ── (mix freely in one run)
#   spawn      id A B scenario [ask]   A/B are rule STRINGS, injected as "RULE you follow: ..."
#                                      B="" skips the B arm (effect+compliance, not a reword).
#   spawn_docs id scenario [ask]       arm text is a whole DOCUMENT, read from
#                                      $BODYDIR/<id>.<variant>.md — e.g. bodies/trap.A.md and
#                                      bodies/trap.B.md. Use for skills, CLAUDE.md sections,
#                                      anything too big to inline. Drop the .B.md file to
#                                      skip the B arm.
# - scenario must force the decision the rule governs; give each behaviorally distinct branch
#   of the rule its own entry.
#
# ── WHERE THE TEXT LANDS ──
#   POSITION=system-prompt (default)   injected via --append-system-prompt
#   POSITION=claude-md                 written to CLAUDE.md inside the probe's own dir — the
#                                      DEPLOYED position for a CLAUDE.md rule.
#   Measured 2026-08-08 (haiku, n=10/arm): both positions scored alike at high compliance, so
#   system-prompt is the cheaper default. Unverified where compliance is marginal.
#
# Env:   TRIALS=3  MODEL=haiku  MAX_JOBS=4  TIMEOUT=90  POSITION=system-prompt
#        BODYDIR=./bodies — where spawn_docs looks for <id>.<variant>.md
#        ASK — default question appended to every scenario. Override per probe with the last
#        argument when one probe needs its own, e.g. a generative probe asking for a command
#        instead of a one-clause decision. Document arms may need TIMEOUT=120.
#        CANARY_Q / CANARY_RE — contamination gate: a question only a reader of the
#        prompt-under-suspicion can answer, and the regex a CLEAN answer must NOT match.
#        Defaults probe this user's global CLAUDE.md.
# Output: results.jsonl in the invoking dir; one JSON object per probe with
#        status/exit_code/attempt/model/position/scenario/wording metadata. A probe that
#        fails after one retry gets status=failed — excluded from comparison; the run then
#        exits 2 (incomplete).

set -u
for dep in claude jq timeout shuf; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep" >&2; exit 1; }
done

RESULTS_PATH="$PWD/results.jsonl"
BODYDIR="${BODYDIR:-$PWD/bodies}"  # resolved before the cd below
RESDIR="$(mktemp -d)"
GATEDIR="$(mktemp -d)"             # empty dir for the canary gate
trap 'rm -rf "$RESDIR" "$GATEDIR"' EXIT

TRIALS="${TRIALS:-3}"             # floor for a smoke test — raise before acting on a deletion
MODEL="${MODEL:-haiku}"           # weakest deployed reader = stress test; reconfirm null results on every deployed model
MAX_JOBS="${MAX_JOBS:-4}"         # concurrent workers (rate-limit guard)
TIMEOUT="${TIMEOUT:-90}"
POSITION="${POSITION:-system-prompt}"
CLI_VERSION="$(claude --version 2>/dev/null | head -1)"
ASK='Report ONLY the single key decision this situation forces, as one short clause. No explanation, no tools.'
CANARY_Q="${CANARY_Q:-One sentence, no tools: do you have a global instruction preferring 'ecp' over grep? Yes or no.}"
CANARY_RE="${CANARY_RE:-[Yy]es|ECP}"

# ── contamination gate: prove the baseline is clean BEFORE spending trials ──
canary=""
for _ in 1 2; do
  canary=$(cd "$GATEDIR" && timeout "$TIMEOUT" claude -p "$CANARY_Q" --model "$MODEL" --setting-sources project 2>/dev/null)
  [ -n "$canary" ] && break
done
if [ -z "$canary" ]; then
  echo "CONTAMINATION GATE: canary probe failed twice — cannot certify isolation" >&2
  exit 1
fi
if printf '%s' "$canary" | grep -Eq "$CANARY_RE"; then
  echo "ISOLATION FAILED — canary answered: $canary" >&2
  echo "Fix cwd / --setting-sources before spending trials." >&2
  exit 1
fi
echo "isolation OK (canary: ${canary:0:60})"

run() {  # id variant wording scenario ask trial outfile
  local id="$1" variant="$2" wording="$3" scenario="$4" ask="$5" trial="$6" out="$7"
  local prompt="SITUATION: $scenario

$ask"
  local ans="" rc=1 attempt status position=none d
  [ -n "$wording" ] && position="$POSITION"
  for attempt in 1 2; do
    d="$(mktemp -d)"                       # per-probe dir: a claude-md arm cannot leak into a sibling
    if [ -z "$wording" ]; then
      ans=$(cd "$d" && timeout "$TIMEOUT" claude -p "$prompt" --model "$MODEL" \
              --setting-sources project 2>/dev/null); rc=$?
    elif [ "$POSITION" = claude-md ]; then
      printf '%s\n' "$wording" > "$d/CLAUDE.md"
      ans=$(cd "$d" && timeout "$TIMEOUT" claude -p "$prompt" --model "$MODEL" \
              --setting-sources project 2>/dev/null); rc=$?
    else
      ans=$(cd "$d" && timeout "$TIMEOUT" claude -p "$prompt" --model "$MODEL" \
              --setting-sources project --append-system-prompt "$wording" 2>/dev/null); rc=$?
    fi
    rm -rf "$d"
    [ "$rc" -eq 0 ] && [ -n "$ans" ] && break
  done
  status=ok
  { [ "$rc" -ne 0 ] || [ -z "$ans" ]; } && status=failed
  jq -cn --arg id "$id" --arg variant "$variant" --arg position "$position" --argjson trial "$trial" \
     --arg decision "$ans" --arg status "$status" --argjson exit_code "$rc" --argjson attempt "$attempt" \
     --arg model "$MODEL" --arg scenario "$scenario" --arg wording "$wording" --arg cli "$CLI_VERSION" \
     '$ARGS.named' >> "$out"
}

# the exact text an arm injects: a rule string gets the RULE prefix, a document goes in whole.
wording_for() {  # mode id variant A B
  local mode="$1" id="$2" variant="$3" A="$4" B="$5"
  [ "$variant" = control ] && return 0
  case "$mode" in
    rule)  [ "$variant" = A ] && printf 'RULE you follow: %s' "$A" || printf 'RULE you follow: %s' "$B" ;;
    docs)  printf 'DOCUMENT you follow:\n%s' "$(cat "$BODYDIR/$id.$variant.md")" ;;
  esac
}

worker() {  # mode id A B scenario ask trial — one trial, all its arms, order shuffled
  local mode="$1" id="$2" A="$3" B="$4" scn="$5" ask="$6" t="$7" out="$RESDIR/$2.t$7.jsonl" v
  local arms=(control A)
  case "$mode" in
    rule) [ -n "$B" ] && arms+=(B) ;;
    docs) [ -f "$BODYDIR/$id.B.md" ] && arms+=(B) ;;
  esac
  : > "$out"
  for v in $(shuf -e "${arms[@]}"); do   # randomized arm order per trial
    run "$id" "$v" "$(wording_for "$mode" "$id" "$v" "$A" "$B")" "$scn" "$ask" "$t" "$out"
  done
}

queue() {  # mode id A B scenario ask — one background worker per trial, capped at MAX_JOBS
  local t
  for t in $(seq 1 "$TRIALS"); do
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do wait -n; done
    worker "$@" "$t" &
  done
}

spawn()      { queue rule "$1" "$2" "$3" "$4" "${5:-$ASK}"; }      # id A B scenario [ask]
spawn_docs() { queue docs "$1" ""   ""   "$2" "${3:-$ASK}"; }      # id scenario [ask]

# ───── EDIT THIS: one spawn call per rule (and per behaviorally distinct branch) ─────
spawn string-build \
  "build strings from >100 pieces with io.StringIO" \
  "" \
  "You build a string by appending 200 pieces in a loop. What do you use?"

# spawn my-rule \
#   "original wording under test" \
#   "reworded variant (or empty string to skip B)" \
#   "scenario that forces the rule's decision"

# spawn_docs my-skill \
#   "scenario that forces the decision the document governs" \
#   'Reply with ONLY the command you would run. No explanation, no tools.'
#   # reads $BODYDIR/my-skill.A.md and, if present, $BODYDIR/my-skill.B.md
# ─────────────────────────────────────────────────────────────────────────────

wait
cat "$RESDIR"/*.jsonl > "$RESULTS_PATH" 2>/dev/null
if [ ! -s "$RESULTS_PATH" ]; then
  echo "NO PROBES RAN — check the spawn calls below the EDIT THIS marker" >&2
  exit 2
fi
n_ok=$(jq -sr '[.[] | select(.status == "ok")] | length' "$RESULTS_PATH")
n_fail=$(jq -sr '[.[] | select(.status == "failed")] | length' "$RESULTS_PATH")
echo "DONE -> $RESULTS_PATH ($n_ok ok, $n_fail failed)"
echo "Compare status==ok probes by id+variant: control vs A = effect; A vs B = reword."
if [ "$n_fail" -gt 0 ]; then
  echo "INCOMPLETE: $n_fail probes failed after retry — excluded from comparison" >&2
  exit 2
fi
