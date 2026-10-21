# Run: bash ~/.claude/hooks/tests/test_auto_etoon.sh
# Runs the hook with a stub `rtk` on PATH; RTK_STUB picks its behaviour (rewrite / none / ask / fail).
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/auto-etoon.sh"
T=$(mktemp -d "$HOME/.cache/auto-etoon-test.XXXXXX") || exit 1; mkdir "$T/bin"
cat > "$T/bin/rtk" <<'EOF'
#!/bin/bash
case "$RTK_STUB" in
    rewrite) jq -c '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecisionReason:"RTK auto-rewrite",
                 updatedInput:(.tool_input + {command:("rtk " + .tool_input.command)})}}' ;;
    none) cat >/dev/null ;;
    ask) cat >/dev/null; echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}' ;;
    fail) cat >/dev/null; echo "rtk blocked" >&2; exit 2 ;;
esac
EOF
chmod +x "$T/bin/rtk"
pass=0; fail=0
# run MODE JSON [PATH] -> updatedInput (compact) or the raw stdout, then rc
run() {
    local out rc
    out=$(printf '%s' "$2" | RTK_STUB="$1" PATH="${3:-$T/bin:/usr/bin:/bin}" bash "$SCRIPT" 2>"$T/err"); rc=$?
    printf '%s' "$out" | jq -c '.hookSpecificOutput.updatedInput // .' 2>/dev/null || printf '%s' "$out"
    echo "rc=$rc"
}
input() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }

FULL='{"tool_input":{"command":"git status","description":"d","timeout":5000,"run_in_background":true}}'
check   test_rtk_rewrite_gets_etoon_appended      "$(run rewrite "$(input 'git status')")"   '"command":"rtk git status | etoon"'
check   test_rtk_rewrite_keeps_reason             "$(printf '%s' "$(input ls)" | RTK_STUB=rewrite PATH="$T/bin:/usr/bin:/bin" bash "$SCRIPT")" 'RTK auto-rewrite'
check   test_rtk_rewrite_keeps_other_fields       "$(run rewrite "$FULL")"                   '"description":"d","timeout":5000,"run_in_background":true'
R=$(run none '{"tool_input":{"command":"python3 x.py","timeout":5000,"run_in_background":true}}')
check   test_no_rtk_rewrite_appends_etoon         "$R"                                       '"command":"python3 x.py | etoon"'
check   test_no_rtk_rewrite_keeps_other_fields    "$R"                                       '"timeout":5000,"run_in_background":true'
check   test_git_diff_keeps_rtk_without_etoon     "$(run rewrite "$(input 'git diff HEAD')")" '"command":"rtk git diff HEAD"}'
check   test_trailing_ampersand_keeps_rtk_only    "$(run rewrite "$(input 'sleep 1 &')")"    '"command":"rtk sleep 1 &"}'
nocheck test_cd_builtin_no_etoon                  "$(run rewrite "$(input 'cd /x')")"        'etoon'
eq      test_heredoc_no_rewrite_no_output         "$(run none "$(input $'cat <<X\nhi\nX')")" rc=0
eq      test_already_etoon_no_output              "$(run none "$(input 'ls | etoon')")"     rc=0
eq      test_empty_command_no_output              "$(run rewrite '{"tool_input":{}}')"       rc=0
check   test_empty_stdin_exits_zero               "$(run rewrite '')"                        'rc=0'
# /usr/bin:/bin holds no rtk on this machine (rtk lives in ~/.local/bin).
check   test_rtk_absent_appends_etoon             "$(run none "$(input ls)" /usr/bin:/bin)"     '"command":"ls | etoon"'
R=$(run fail "$(input ls)")
check   test_rtk_failure_passes_its_exit_code     "$R"                                       'rc=2'
nocheck test_rtk_failure_adds_no_etoon            "$R"                                       'etoon'
check   test_rtk_failure_passes_its_stderr        "$(cat "$T/err")"                          'rtk blocked'
R=$(run ask "$(input ls)")
check   test_rtk_decision_without_rewrite_kept    "$R"                                       '"permissionDecision":"ask"'
nocheck test_rtk_decision_without_rewrite_no_etoon "$R"                                      'etoon'
check   test_trailing_newline_no_rewrite          "$(run none "$(input $'printf hello\n')")"    '"command":"printf hello | etoon"'
check   test_trailing_newline_rtk_rewrite         "$(run rewrite "$(input $'printf hello\n')")" '"command":"rtk printf hello | etoon"'
check   test_trailing_spaces_kept                 "$(run none "$(input 'echo a  ')")"           '"command":"echo a   | etoon"'
eq      test_line_continuation_no_etoon           "$(run none "$(input $'printf %s hello\\\n')")" rc=0

# The real rtk rewrites `cat` to `rtk read`; etoon must still be appended.
if command -v rtk >/dev/null; then
    check test_real_rtk_cat_gets_both \
        "$(run real "$(input 'cat data.json')" "$(dirname "$(command -v rtk)"):/usr/bin:/bin")" '"command":"rtk read data.json | etoon"'
else
    echo "skip test_real_rtk_cat_gets_both: rtk not on PATH"
fi

rm -f "$T/bin/rtk" "$T/err"; rmdir "$T/bin" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
