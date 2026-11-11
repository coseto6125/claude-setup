#!/usr/bin/env bash
# Watch one PR until it merges, closes, or needs action. Prints one line per state change,
# so each line is one Monitor event. Run it from inside the repo.
#
#   pr-wait.sh <pr>          watch; exit 0 on merged/closed, 1 on a line that starts with STOP
#   pr-wait.sh <pr> --once   print one snapshot line and exit
#
# Green means every check the base branch's protection requires has passed (or skipped),
# not "nothing pending": a workflow that has not registered yet is missing, not green.
# A job cancelled because no hosted runner picked it up is re-run once its run completes.
# Each change in the set of unfinished checks prints one `pending:` line, so a 30-minute
# Monitor shows progress even while one slow job runs. STALL counts from the oldest unfinished
# check's start, so a re-armed watcher does not reset it.
# Env: PR_WAIT_INTERVAL (seconds, default 45), PR_WAIT_STALL_MIN (default 50),
# PR_WAIT_MAX_TICKS (tests only).
set -uo pipefail

pr=${1:?usage: pr-wait.sh <pr> [--once]}
once=${2:-}
interval=${PR_WAIT_INTERVAL:-45}
max_ticks=${PR_WAIT_MAX_TICKS:-0}
stall_min=${PR_WAIT_STALL_MIN:-50}

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || { echo "STOP: not inside a GitHub repo"; exit 1; }
base=$(gh pr view "$pr" --json baseRefName --jq .baseRefName 2>/dev/null) || { echo "STOP: cannot read PR $pr"; exit 1; }
required=$(gh api "repos/$repo/branches/$base/protection" --jq '.required_status_checks.contexts[]' 2>/dev/null || true)

declare -A seen=() rerun_queue=() rerun_done=()
green_at=0
last_change=$(date +%s)
stalled=""
last_pending=""

emit() { echo "$1"; last_change=$(date +%s); }

unresolved_threads() {
  gh api graphql -f query="{repository(owner:\"${repo%/*}\",name:\"${repo#*/}\"){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved path line}}}}}" \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)|"\(.path):\(.line)"' 2>/dev/null
}

# Prints the names of required checks that have not passed; with no protection, every check counts.
not_green() {
  local checks=$1
  if [ -n "$required" ]; then
    while IFS= read -r ctx; do
      jq -e --arg n "$ctx" 'any(.[]; .name==$n and (.bucket=="pass" or .bucket=="skipping"))' <<<"$checks" >/dev/null || echo "$ctx"
    done <<<"$required"
  else
    jq -r 'if length==0 then "(no checks yet)" else .[]|select(.bucket!="pass" and .bucket!="skipping")|.name end' <<<"$checks"
  fi
}

tick() {
  local view state merge_state checks now
  view=$(gh pr view "$pr" --json state,mergeStateStatus,autoMergeRequest 2>/dev/null) || return 0
  state=$(jq -r .state <<<"$view")
  merge_state=$(jq -r .mergeStateStatus <<<"$view")
  if [ "$state" = MERGED ] || [ "$state" = CLOSED ]; then
    echo "PR $pr $state $(gh pr view "$pr" --json mergeCommit --jq '.mergeCommit.oid // ""' 2>/dev/null)"
    exit 0
  fi
  checks=$(gh pr checks "$pr" --json name,bucket,link,startedAt 2>/dev/null)
  [ -n "$checks" ] || checks='[]'

  if [ "$once" = --once ]; then
    echo "PR $pr $state mergeState=$merge_state not_green=[$(not_green "$checks" | paste -sd, -)] unresolved_threads=$(unresolved_threads | grep -c .)"
    exit 0
  fi

  # Cancelled and failed jobs, each reported once per job id.
  while IFS=$'\t' read -r bucket name link; do
    [ -n "$link" ] && [ -z "${seen[$link]:-}" ] || continue
    seen[$link]=1
    local run_id=${link#*/runs/}; run_id=${run_id%%/*}
    local job_id=${link##*/job/}
    if [ "$bucket" = cancel ]; then
      local why
      why=$(gh api "repos/$repo/check-runs/$job_id/annotations" --jq '.[0].message // ""' 2>/dev/null)
      if [[ "$why" == *"not acquired by Runner"* ]]; then
        if [ -n "${rerun_done[$run_id]:-}" ]; then emit "STOP: cancel again after rerun: $name ($why)"; exit 1; fi
        rerun_queue[$run_id]=1
        emit "cancel: $name (no hosted runner; rerun queued for run $run_id)"
      else
        emit "STOP: cancel: $name ${why:-$link}"; exit 1
      fi
    elif [ -z "${rerun_queue[$run_id]:-}" ]; then
      # A failed aggregate job in a run that is queued for rerun is the cancel's echo, not a new failure.
      emit "STOP: fail: $name $link"; exit 1
    fi
  done < <(jq -r '.[]|select(.bucket=="fail" or .bucket=="cancel")|[.bucket,.name,.link]|@tsv' <<<"$checks")

  local rid
  for rid in "${!rerun_queue[@]}"; do
    [ "$(gh run view "$rid" --json status --jq .status 2>/dev/null)" = completed ] || continue
    if gh run rerun "$rid" --failed >/dev/null 2>&1; then emit "rerun: run $rid failed jobs"; else emit "STOP: rerun of run $rid refused"; exit 1; fi
    unset "rerun_queue[$rid]"; rerun_done[$rid]=1
  done

  local pending
  pending=$(jq -r '[.[]|select(.bucket=="pending")|.name]|sort|join(", ")' <<<"$checks")
  [ -n "$pending" ] && [ "$pending" != "$last_pending" ] && emit "pending: $pending"
  last_pending=$pending

  now=$(date +%s)
  if [ -z "$(not_green "$checks")" ]; then
    if [ "$green_at" = 0 ]; then
      green_at=$now
      local threads; threads=$(unresolved_threads)
      if [ -n "$threads" ]; then
        emit "STOP: required checks green but $(grep -c . <<<"$threads") unresolved review threads block merge:"
        sed 's/^/  /' <<<"$threads"; exit 1
      fi
      emit "green: required checks passed; mergeState=$merge_state auto-merge=$(jq -r 'if .autoMergeRequest then "on" else "off" end' <<<"$view")"
    elif [ $((now - green_at)) -gt 300 ] && [ -z "$stalled" ]; then
      stalled=1; emit "STALL: green 5 min and not merged; mergeState=$merge_state"
    fi
  elif [ -z "$stalled" ]; then
    local oldest
    oldest=$(jq -r '[.[]|select(.bucket=="pending" and ((.startedAt // "")|startswith("20")))
      |{n:.name,m:((now-(.startedAt|fromdateiso8601))/60|floor)}]|max_by(.m) // empty|"\(.m) \(.n)"' <<<"$checks")
    if [ -n "$oldest" ] && [ "${oldest%% *}" -ge "$stall_min" ]; then
      stalled=1; emit "STALL: ${oldest#* } running ${oldest%% *} min"
    elif [ $((now - last_change)) -gt 2400 ]; then
      stalled=1; emit "STALL: no change for 40 min; waiting on: $(not_green "$checks" | paste -sd, -)"
    fi
  fi
}

ticks=0
while true; do
  tick
  ticks=$((ticks + 1))
  [ "$max_ticks" -gt 0 ] && [ "$ticks" -ge "$max_ticks" ] && exit 0
  sleep "$interval"
done
