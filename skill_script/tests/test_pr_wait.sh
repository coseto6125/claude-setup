# Tests for pr-wait.sh. Run: bash ~/.claude/skill_script/tests/test_pr_wait.sh
# A fake `gh` on PATH answers from JSON fixtures and applies --jq with the real jq.
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pr-wait.sh"
FAILS=0
PROTECTION='{"required_status_checks":{"contexts":["Test (all platforms)","CodeRabbit"]}}'
NO_THREADS='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":true,"path":"a.rs","line":1}]}}}}}'

setup() {  # leaves fixtures in $F and the fake gh first on PATH
    F=$(mktemp -d); export F
    mkdir -p "$F/bin"
    cat > "$F/bin/gh" <<'GH'
#!/usr/bin/env bash
jqx=""; prev=""
for a in "$@"; do [ "$prev" = --jq ] && jqx=$a; prev=$a; done
out() { [ -f "$F/$1" ] || exit 1; if [ -n "$jqx" ]; then jq -r "$jqx" "$F/$1"; else cat "$F/$1"; fi; }
case "$*" in
  "repo view"*) echo o/r ;;
  "pr view"*) out pr.json ;;
  "pr checks"*) out checks.json ;;
  "api repos/o/r/branches/"*) out protection.json ;;
  "api graphql"*) out threads.json ;;
  "api repos/o/r/check-runs/"*) out annotations.json ;;
  "run view"*) out run.json ;;
  "run rerun"*) echo "$*" >> "$F/calls" ;;
esac
GH
    chmod +x "$F/bin/gh"
    export PATH="$F/bin:$PATH" PR_WAIT_INTERVAL=0
    echo '{"state":"OPEN","baseRefName":"main","mergeStateStatus":"BLOCKED","autoMergeRequest":{"m":1}}' > "$F/pr.json"
    echo "$PROTECTION" > "$F/protection.json"
    echo "$NO_THREADS" > "$F/threads.json"
}
check() {  # $1 = name, $2 = expected exit, $3 = actual exit, $4 = output, $5 = required substring, $6 = forbidden substring
    if [[ $3 -eq $2 && "$4" == *"$5"* && ( -z "${6:-}" || "$4" != *"$6"* ) ]]; then echo "ok   $1"
    else echo "FAIL $1 (exit $3)"; sed 's/^/     /' <<<"$4"; FAILS=$((FAILS+1)); fi
}

test_pr_wait_merged_prints_commit_exits_zero() {
    setup
    echo '{"state":"MERGED","baseRefName":"main","mergeCommit":{"oid":"abc123"}}' > "$F/pr.json"
    out=$(bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "PR 7 MERGED abc123"
}

test_pr_wait_required_check_not_registered_not_green() {
    setup
    echo '[{"name":"CodeRabbit","bucket":"pass","link":""}]' > "$F/checks.json"
    out=$(bash "$SCRIPT" 7 --once 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "not_green=[Test (all platforms)]"
}

test_pr_wait_green_with_unresolved_threads_stops() {
    setup
    echo '[{"name":"CodeRabbit","bucket":"pass","link":""},{"name":"Test (all platforms)","bucket":"pass","link":"https://x/runs/1/job/9"}]' > "$F/checks.json"
    echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"path":"a.rs","line":400},{"isResolved":false,"path":"a.rs","line":907}]}}}}}' > "$F/threads.json"
    out=$(PR_WAIT_MAX_TICKS=3 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 1 $? "$out" "2 unresolved review threads block merge:
  a.rs:400"
}

test_pr_wait_runner_capacity_cancel_reruns_without_stop() {
    setup
    cat > "$F/checks.json" <<'J'
[{"name":"Test on macos-latest","bucket":"cancel","link":"https://x/runs/100/job/1"},
 {"name":"Test (all platforms)","bucket":"fail","link":"https://x/runs/100/job/2"},
 {"name":"CodeRabbit","bucket":"pass","link":""}]
J
    echo '[{"message":"The job was not acquired by Runner of type hosted even after multiple attempts"}]' > "$F/annotations.json"
    echo '{"status":"completed"}' > "$F/run.json"
    out=$(PR_WAIT_MAX_TICKS=3 bash "$SCRIPT" 7 2>&1); rc=$?
    out="$out
calls: $(cat "$F/calls" 2>/dev/null)"
    check "${FUNCNAME[0]}" 0 $rc "$out" "rerun: run 100 failed jobs
calls: run rerun 100 --failed" "STOP"
}

test_pr_wait_cancel_for_other_reason_stops() {
    setup
    echo '[{"name":"Test on macos-latest","bucket":"cancel","link":"https://x/runs/100/job/1"}]' > "$F/checks.json"
    echo '[{"message":"Canceling since a higher priority waiting request exists"}]' > "$F/annotations.json"
    out=$(PR_WAIT_MAX_TICKS=3 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 1 $? "$out" "STOP: cancel: Test on macos-latest Canceling"
}

test_pr_wait_real_failure_stops() {
    setup
    echo '[{"name":"Test on ubuntu-latest","bucket":"fail","link":"https://x/runs/5/job/6"}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=3 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 1 $? "$out" "STOP: fail: Test on ubuntu-latest"
}

test_pr_wait_no_branch_protection_all_checks_count() {
    setup
    rm -f -- "$F/protection.json"
    echo '[{"name":"lint","bucket":"pass","link":""},{"name":"CodeQL","bucket":"skipping","link":""}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=1 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "green: required checks passed; mergeState=BLOCKED auto-merge=on"
}

test_pr_wait_no_checks_yet_not_green_without_protection() {
    setup
    rm -f -- "$F/protection.json"
    echo '[]' > "$F/checks.json"
    out=$(bash "$SCRIPT" 7 --once 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "not_green=[(no checks yet)]"
}

test_pr_wait_pending_checks_printed_once_per_change() {
    setup
    echo '[{"name":"Test on windows-latest","bucket":"pending","link":"","startedAt":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"},{"name":"CodeRabbit","bucket":"pass","link":""}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=3 bash "$SCRIPT" 7 2>&1); rc=$?
    [ "$(grep -c '^pending:' <<<"$out")" = 1 ] || out="$out
(pending printed more than once)"
    check "${FUNCNAME[0]}" 0 $rc "$out" "pending: Test on windows-latest" "more than once"
}

test_pr_wait_check_running_past_stall_min_stalls() {
    setup
    echo '[{"name":"Test on windows-latest","bucket":"pending","link":"","startedAt":"'"$(date -u -d '-61 min' +%Y-%m-%dT%H:%M:%SZ)"'"}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=1 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "STALL: Test on windows-latest running 61 min"
}

test_pr_wait_check_within_stall_min_no_stall() {
    setup
    echo '[{"name":"Test on windows-latest","bucket":"pending","link":"","startedAt":"'"$(date -u -d '-35 min' +%Y-%m-%dT%H:%M:%SZ)"'"}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=2 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "pending: Test on windows-latest" "STALL"
}

test_pr_wait_queued_check_without_start_no_stall() {
    setup
    echo '[{"name":"Test on windows-latest","bucket":"pending","link":"","startedAt":"0001-01-01T00:00:00Z"}]' > "$F/checks.json"
    out=$(PR_WAIT_MAX_TICKS=1 bash "$SCRIPT" 7 2>&1); check "${FUNCNAME[0]}" 0 $? "$out" "pending: Test on windows-latest" "STALL"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do "$t"; done
echo "failures: $FAILS"
[[ $FAILS -eq 0 ]]
