# Run: bash ~/.claude/hooks/tests/test_track_subagents.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/track-subagents.sh"
pass=0; fail=0
H=$(mktemp -d "$HOME/.cache/track-agents-test.XXXXXX"); trap 'case "$H" in "$HOME"/.cache/track-agents-test.?*) rm -rf -- "$H" ;; esac' EXIT
fire() { jq -nc --arg e "$1" --arg s "$2" --arg a "$3" --arg t "$4" '{hook_event_name:$e,session_id:$s,agent_id:$a,agent_type:$t}' | HOME=$H bash "$SCRIPT"; echo $?; }
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: got [$2] want [$3]"; fi; }
M=$H/.cache/claude-agents

check test_start_editing_agent_exit_zero        "$(fire SubagentStart s1 a1 general-purpose)" 0
check test_start_editing_agent_writes_marker    "$(cat "$M/s1/a1" 2>/dev/null)" general-purpose
fire SubagentStart s1 e1 Explore >/dev/null
check test_start_explore_writes_no_marker       "$([ -e "$M/s1/e1" ] && echo yes || echo no)" no
fire SubagentStart s1 d1 deep-review >/dev/null
check test_start_deep_review_writes_no_marker   "$([ -e "$M/s1/d1" ] && echo yes || echo no)" no
fire SubagentStart s1 f1 '' >/dev/null
check test_start_untyped_agent_writes_marker    "$(cat "$M/s1/f1" 2>/dev/null)" unknown
fire SubagentStop s1 a1 general-purpose >/dev/null
check test_stop_removes_marker                  "$([ -e "$M/s1/a1" ] && echo yes || echo no)" no
check test_stop_without_marker_exit_zero        "$(fire SubagentStop s1 zz general-purpose)" 0
fire SubagentStart '../x' a2 general-purpose >/dev/null
check test_start_unsafe_session_id_ignored      "$([ -e "$H/.cache/x" ] || [ -e "$M/../x" ] && echo yes || echo no)" no

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
