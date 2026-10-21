# Run: bash ~/.claude/hooks/tests/test_ecp_graph_nudge.sh
# Runs the hook with a stub `ecp` (ECP_BIN) that reports, as a graph hit, the cwd it was handed.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ecp-graph-nudge.sh"
T=$(mktemp -d "$HOME/.cache/ecp-nudge-test.XXXXXX") || exit 1
mkdir "$T/repo" "$T/session" "$T/repo with space" "$T/it's"
cat > "$T/ecp" <<'EOF'
#!/bin/bash
cwd=$(jq -r '.cwd // ""')
case "$ECP_STUB" in
    hit)  jq -cn --arg c "ecp graph hits:
  UploadFile (cwd=$cwd) [Class]
" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}' ;;
    none) : ;;
    fail) exit 3 ;;
esac
EOF
chmod +x "$T/ecp"
pass=0; fail=0
# run STUB COMMAND [CWD] -> additionalContext, or the raw stdout when there is none
run() {
    local out
    out=$(jq -cn --arg c "$2" --arg w "${3:-$T/session}" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$w}' \
        | ECP_STUB="$1" ECP_BIN="$T/ecp" bash "$SCRIPT" 2>"$T/err")
    printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || printf '%s' "$out"
}
check()   { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }
eq()      { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }

# No cd: the session cwd goes to ecp unchanged, and the nudge keeps --repo .
out=$(run hit 'grep -rn "UploadFile::" app')
check   test_no_cd_keeps_session_cwd              "$out" "cwd=$T/session)"
check   test_no_cd_nudge_uses_repo_dot            "$out" "ecp impact --target UploadFile --direction upstream --repo ."
nocheck test_no_cd_nudge_has_no_cd_prefix         "$out" "&& ecp impact"

# A literal cd into another repo: ecp is asked about that repo, and the nudge cds there too.
out=$(run hit "cd $T/repo && grep -rn UploadFile:: app")
check   test_cd_and_and_uses_cd_target            "$out" "cwd=$T/repo)"
check   test_cd_nudge_prefixes_cd_target          "$out" "cd $T/repo && ecp impact --target UploadFile"
check   test_cd_semicolon_uses_cd_target          "$(run hit "cd $T/repo; grep -rn UploadFile:: app")" "cwd=$T/repo)"
check   test_cd_double_quoted_with_space          "$(run hit "cd \"$T/repo with space\" && grep UploadFile:: .")" "cwd=$T/repo with space)"
check   test_cd_single_quoted_path                "$(run hit "cd '$T/repo' && grep UploadFile:: .")" "cwd=$T/repo)"
check   test_cd_relative_resolves_against_cwd     "$(run hit 'cd ../repo && grep UploadFile:: .')" "cwd=$T/repo)"
check   test_cd_after_assignment_uses_cd_target   "$(run hit "X=1; cd $T/repo && grep UploadFile:: .")" "cwd=$T/repo)"
check   test_first_literal_cd_wins                "$(run hit "cd $T/repo && grep UploadFile:: . ; cd $T/session")" "cwd=$T/repo)"
check   test_unquoted_tilde_expands               "$(run hit "cd ~ && grep UploadFile:: .")" "cwd=$HOME)"
out=$(run hit "cd \"$T/it's\" && grep UploadFile:: .")
check   test_cd_single_quote_in_path_uses_target  "$out" "cwd=$T/it's)"
check   test_cd_single_quote_in_path_nudge_quoted "$out" "cd $(printf '%q' "$T/it's") && ecp impact"

# A cd that does not set the cwd of the commands after it: fall back to the session cwd.
check   test_cd_after_command_falls_back          "$(run hit "grep cd $T/session && cd $T/repo && grep UploadFile:: .")" "cwd=$T/session)"
check   test_cd_after_or_falls_back               "$(run hit "true || cd $T/repo; grep UploadFile:: .")" "cwd=$T/session)"
check   test_cd_in_subshell_falls_back            "$(run hit "(cd $T/repo && make); grep UploadFile:: .")" "cwd=$T/session)"
check   test_cd_extra_arg_falls_back              "$(run hit "cd $T/repo extra; grep UploadFile:: .")" "cwd=$T/session)"
check   test_cd_piped_falls_back                  "$(run hit "cd $T/repo | grep UploadFile:: .")" "cwd=$T/session)"
check   test_quoted_tilde_falls_back              "$(run hit 'cd "~" && grep UploadFile:: .')" "cwd=$T/session)"
check   test_quoted_tilde_later_does_not_block    "$(run hit "cd ~ && grep 'cd \"~\"' UploadFile:: .")" "cwd=$HOME)"

# A cd target the hook cannot know or that does not exist: fall back to the session cwd.
check   test_cd_variable_falls_back               "$(run hit 'B=/x; cd "$B" && grep UploadFile:: .')" "cwd=$T/session)"
check   test_cd_missing_dir_falls_back            "$(run hit "cd $T/nope && grep UploadFile:: .")" "cwd=$T/session)"
check   test_cd_inside_quoted_string_ignored      "$(run hit "echo 'cd $T/repo' && grep UploadFile:: .")" "cwd=$T/session)"
check   test_unbalanced_quote_falls_back          "$(run hit "cd $T/repo && grep \"UploadFile:: .")" "cwd=$T/session)"
check   test_bare_cd_at_end_falls_back            "$(run hit 'grep UploadFile:: . && cd')" "cwd=$T/session)"

# The symbol gate still applies, and ecp failures stay silent.
eq      test_symbol_not_in_command_no_output      "$(run hit "cd $T/repo && grep -rn foo app")" ""
eq      test_ecp_no_hits_no_output                "$(run none "cd $T/repo && grep UploadFile:: .")" ""
eq      test_ecp_failure_no_output                "$(run fail "cd $T/repo && grep UploadFile:: .")" ""
eq      test_missing_ecp_binary_no_output         "$(jq -cn '{tool_input:{command:"grep UploadFile:: ."},cwd:"/"}' | ECP_BIN="$T/absent" bash "$SCRIPT")" ""

rm -f "$T/ecp" "$T/err"; rmdir "$T/repo" "$T/session" "$T/repo with space" "$T/it's" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
