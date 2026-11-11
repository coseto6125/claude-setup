# Run: bash ~/.claude/hooks/tests/test_ecp_graph_nudge.sh
# Runs the hook with a stub `ecp` (ECP_BIN) that reports, as a graph hit, the cwd it was handed.
# ecp >= 0.16 resolves a leading cd itself and names the repo in its header; the stub
# prints that header when ECP_STUB_DIR is set. The cd parsing is tested in ecp's own suite.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ecp-graph-nudge.sh"
T=$(mktemp -d "$HOME/.cache/ecp-nudge-test.XXXXXX") || exit 1
mkdir "$T/repo" "$T/session" "$T/repo with space" "$T/it's"
cat > "$T/ecp" <<'EOF'
#!/bin/bash
cwd=$(jq -r '.cwd // ""')
head="ecp graph hits:"
[ -n "${ECP_STUB_DIR:-}" ] && head="ecp graph hits in $ECP_STUB_DIR:"
case "$ECP_STUB" in
    hit)  jq -cn --arg c "$head
  UploadFile (cwd=$cwd) [Class]
" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}' ;;
    none) : ;;
    fail) exit 3 ;;
esac
EOF
chmod +x "$T/ecp"
pass=0; fail=0
# run STUB COMMAND [HEADER_DIR] -> additionalContext, or the raw stdout when there is none
run() {
    local out
    out=$(jq -cn --arg c "$2" --arg w "$T/session" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$w}' \
        | ECP_STUB="$1" ECP_STUB_DIR="${3:-}" ECP_BIN="$T/ecp" bash "$SCRIPT" 2>"$T/err")
    printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || printf '%s' "$out"
}
check()   { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }
eq()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }

# No cd: the plain header keeps --repo . with no cd prefix.
out=$(run hit 'grep -rn "UploadFile::" app')
check   test_no_cd_keeps_session_cwd              "$out" "cwd=$T/session)"
check   test_no_cd_nudge_uses_repo_dot            "$out" "ecp impact --target UploadFile --direction upstream --repo ."
nocheck test_no_cd_nudge_has_no_cd_prefix         "$out" "&& ecp impact"

# The hook hands ecp the envelope unchanged: ecp resolves the cd.
out=$(run hit "cd $T/repo && grep -rn UploadFile:: app" "$T/repo")
check   test_cd_envelope_cwd_unchanged            "$out" "cwd=$T/session)"
check   test_cd_header_kept                       "$out" "ecp graph hits in $T/repo:"
check   test_cd_nudge_prefixes_header_dir         "$out" "cd $T/repo && ecp impact --target UploadFile"
check   test_cd_space_in_dir_nudge_quoted         "$(run hit "cd \"$T/repo with space\" && grep UploadFile:: ." "$T/repo with space")" "cd $(printf '%q' "$T/repo with space") && ecp impact"
check   test_cd_single_quote_in_dir_nudge_quoted  "$(run hit "cd \"$T/it's\" && grep UploadFile:: ." "$T/it's")" "cd $(printf '%q' "$T/it's") && ecp impact"

# The symbol gate still applies, and ecp failures stay silent.
eq      test_symbol_not_in_command_no_output      "$(run hit "cd $T/repo && grep -rn foo app" "$T/repo")" ""
eq      test_ecp_no_hits_no_output                "$(run none "cd $T/repo && grep UploadFile:: .")" ""
eq      test_ecp_failure_no_output                "$(run fail "cd $T/repo && grep UploadFile:: .")" ""
eq      test_missing_ecp_binary_no_output         "$(jq -cn '{tool_input:{command:"grep UploadFile:: ."},cwd:"/"}' | ECP_BIN="$T/absent" bash "$SCRIPT")" ""

rm -f "$T/ecp" "$T/err"; rmdir "$T/repo" "$T/session" "$T/repo with space" "$T/it's" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
