# shellcheck shell=bash
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/review-hook-edit.sh"
pass=0; fail=0
T=$(mktemp -d "${TMPDIR:-/tmp}/hook-review-test.XXXXXX")   # the system tmp cleaner removes it
run() {   # $1 session, $2 file_path: prints the injected context, or nothing
  jq -nc --arg s "$1" --arg f "$2" '{session_id:$s,tool_input:{file_path:$f}}' \
    | HOME="$T" bash "$SCRIPT" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: got [$2] want [$3]"; fi; }
said() { [ -n "$1" ] && echo yes || echo no; }

check test_hook_edit_first_time_reminds        "$(said "$(run s1 /x/.claude/hooks/guard.sh)")" yes
check test_hook_edit_second_time_silent        "$(said "$(run s1 /x/.claude/hooks/guard.sh)")" no
check test_hook_edit_other_session_reminds     "$(said "$(run s2 /x/.claude/hooks/guard.sh)")" yes
check test_hook_edit_other_file_reminds        "$(said "$(run s1 /x/.claude/hooks/other.py)")" yes
check test_hook_test_file_silent               "$(said "$(run s1 /x/.claude/hooks/tests/test_guard.sh)")" no
check test_non_hook_file_silent                "$(said "$(run s1 /x/src/hooks/guard.sh)")" no
check test_empty_file_path_silent              "$(said "$(run s1 '')")" no
check test_no_session_id_reminds_every_time    "$(said "$(run '' /x/.claude/hooks/guard.sh)")" yes
ro=$(mktemp -d "${TMPDIR:-/tmp}/hook-review-ro.XXXXXX"); chmod 500 "$ro"
check test_unwritable_home_silent_exit0 "$(jq -nc '{session_id:"s9",tool_input:{file_path:"/x/.claude/hooks/g.sh"}}' | HOME="$ro" bash "$SCRIPT" >/dev/null 2>&1; echo $?)" 0
par=$( { run s4 /x/.claude/hooks/p.sh & run s4 /x/.claude/hooks/p.sh & run s4 /x/.claude/hooks/p.sh & wait; } | grep -c 'You changed the hook')
check test_parallel_edits_remind_once "$par" 1
msg=$(run s3 /x/.claude/hooks/guard.sh)
for w in /x/.claude/hooks/guard.sh /simplify codex 'rung 14'; do
  check "test_reminder_names_${w//[^a-z0-9]/_}" "$(grep -qF -- "$w" <<<"$msg" && echo yes || echo no)" yes
done
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
