# Run: bash ~/.claude/hooks/tests/test_auto_etoon.sh
# Tests the live Bash PreToolUse hook from settings.json: `etoon hook claude` with the cargo cap as its
# --pre rewriter. ETOON=<path> tests another etoon build. A stub `rtk` on PATH; RTK_STUB picks its
# behaviour (rewrite / none / ask / fail / fail1).
set -u
ETOON=${ETOON:-$(command -v etoon)} || { echo "etoon not on PATH"; exit 1; }
HOOK=("$ETOON" hook claude --pre "$HOME/.claude/bin/cc-auto-etoon cap")
T=$(mktemp -d "$HOME/.cache/auto-etoon-test.XXXXXX") || exit 1; mkdir "$T/bin"
cat > "$T/bin/rtk" <<'EOF'
#!/bin/bash
case "$RTK_STUB" in
    rewrite) jq -c '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecisionReason:"RTK auto-rewrite",
                 updatedInput:(.tool_input + {command:("rtk " + .tool_input.command)})}}' ;;
    none) cat >/dev/null ;;
    ask) cat >/dev/null; echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}' ;;
    fail) cat >/dev/null; echo "rtk blocked" >&2; exit 2 ;;
    fail1) cat >/dev/null; echo "rtk broke" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/bin/rtk"
pass=0; fail=0
# run MODE JSON [PATH] -> updatedInput (compact) or the raw stdout, then rc
run() {
    local out rc
    out=$(printf '%s' "$2" | RTK_STUB="$1" PATH="${3:-$T/bin:/usr/bin:/bin}" "${HOOK[@]}" 2>"$T/err"); rc=$?
    printf '%s' "$out" | jq -c '.hookSpecificOutput.updatedInput // .' 2>/dev/null || printf '%s' "$out"
    echo "rc=$rc"
}
input() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }

FULL='{"tool_input":{"command":"git status","description":"d","timeout":5000,"run_in_background":true}}'
check   test_rtk_rewrite_gets_etoon_appended      "$(run rewrite "$(input 'git status')")"   '"command":"rtk git status | etoon; __etoon_rc='
check   test_rtk_rewrite_keeps_reason             "$(printf '%s' "$(input ls)" | RTK_STUB=rewrite PATH="$T/bin:/usr/bin:/bin" "${HOOK[@]}")" 'RTK auto-rewrite'
check   test_rtk_rewrite_keeps_other_fields       "$(run rewrite "$FULL")"                   '"description":"d","timeout":5000,"run_in_background":true'
R=$(run none '{"tool_input":{"command":"python3 x.py","timeout":5000,"run_in_background":true}}')
check   test_no_rtk_rewrite_appends_etoon         "$R"                                       '"command":"python3 x.py | etoon; __etoon_rc='
check   test_no_rtk_rewrite_keeps_other_fields    "$R"                                       '"timeout":5000,"run_in_background":true'
check   test_git_diff_keeps_rtk_without_etoon     "$(run rewrite "$(input 'git diff HEAD')")" '"command":"rtk git diff HEAD"}'
check   test_trailing_ampersand_keeps_rtk_only    "$(run rewrite "$(input 'sleep 1 &')")"    '"command":"rtk sleep 1 &"}'
nocheck test_cd_builtin_no_etoon                  "$(run rewrite "$(input 'cd /x')")"        'etoon'
eq      test_heredoc_no_rewrite_no_output         "$(run none "$(input $'cat <<X\nhi\nX')")" rc=0
eq      test_already_etoon_no_output              "$(run none "$(input 'ls | etoon')")"     rc=0
eq      test_empty_command_no_output              "$(run rewrite '{"tool_input":{}}')"       rc=0
check   test_empty_stdin_exits_zero               "$(run rewrite '')"                        'rc=0'
# /usr/bin:/bin holds no rtk on this machine (rtk lives in ~/.local/bin).
check   test_rtk_absent_appends_etoon             "$(run none "$(input ls)" /usr/bin:/bin)"     '"command":"ls | etoon; __etoon_rc='
R=$(run fail "$(input ls)")
# rtk failing in any way fails open: no output, exit 0, so Claude Code runs the command unchanged.
eq      test_rtk_block_fails_open                 "$R"                                       rc=0
nocheck test_rtk_failure_adds_no_etoon            "$R"                                       'etoon'
eq      test_rtk_failure_stderr_discarded         "$(cat "$T/err")"                          ""
R=$(run ask "$(input ls)")
check   test_rtk_decision_without_rewrite_kept    "$R"                                       '"permissionDecision":"ask"'
nocheck test_rtk_decision_without_rewrite_no_etoon "$R"                                      'etoon'
check   test_trailing_newline_no_rewrite          "$(run none "$(input $'printf hello\n')")"    '"command":"printf hello | etoon; __etoon_rc='
check   test_trailing_newline_rtk_rewrite         "$(run rewrite "$(input $'printf hello\n')")" '"command":"rtk printf hello | etoon; __etoon_rc='
check   test_trailing_spaces_kept                 "$(run none "$(input 'echo a  ')")"           '"command":"echo a   | etoon; __etoon_rc='
eq      test_line_continuation_no_etoon           "$(run none "$(input $'printf %s hello\\\n')")" rc=0

# The real rtk rewrites `cat` to `rtk read`; etoon must still be appended.
if command -v rtk >/dev/null; then
    check test_real_rtk_cat_gets_both \
        "$(run real "$(input 'cat data.json')" "$(dirname "$(command -v rtk)"):/usr/bin:/bin")" '"command":"rtk read data.json | etoon; __etoon_rc='
else
    echo "skip test_real_rtk_cat_gets_both: rtk not on PATH"
fi

# The pipe into etoon must not hide the command's exit code: run the rewritten command
# with a stub etoon (cat) and compare its exit code with the original command's.
printf '#!/bin/bash\ncat\n' > "$T/bin/etoon"; chmod +x "$T/bin/etoon"
rewritten() { run none "$(input "$1")" | head -1 | jq -er '.command' 2>/dev/null || printf '%s' "$1"; }
rc_of() { PATH="$T/bin:/usr/bin:/bin" bash -c "$1" >/dev/null 2>&1; echo $?; }
for c in 'false' 'true' 'exit 3' 'false | cat' 'true | false' 'cd /tmp && false' 'false && true' 'printf x; false'; do
    eq "test_exit_code_kept[$c]" "$(rc_of "$(rewritten "$c")")" "$(rc_of "$c")"
done
eq test_exit_code_suffix_exact "$(rewritten false)" 'false | etoon; __etoon_rc=${PIPESTATUS[${#PIPESTATUS[@]}-2]}; (exit $__etoon_rc)'
eq test_cd_still_changes_cwd "$(PATH="$T/bin:/usr/bin:/bin" bash -c "$(rewritten 'cd /tmp && pwd -P')" 2>&1)" /tmp

# Test-thread cap (lib/cargo_test_cap.py): the hook adds the cap to a test run that has none, on every path.
# The cap is the one rewrite of this hook; guard-cargo-disk.sh lets such a command through.
SFX='; __etoon_rc=${PIPESTATUS[${#PIPESTATUS[@]}-2]}; (exit $__etoon_rc)'
cmd_of() { run "$1" "$(input "$2")" | head -1 | jq -er '.command' 2>/dev/null || echo "NO-COMMAND"; }
eq test_cap_plain_test_gets_cap               "$(cmd_of none 'cargo test -p x -j 2')"                  "cargo test -p x -j 2 -- --test-threads=4 | etoon$SFX"
eq test_cap_after_existing_dashdash           "$(cmd_of none 'cargo test -p x -- --nocapture')"        "cargo test -p x -- --test-threads=4 --nocapture | etoon$SFX"
eq test_cap_before_fd_redirect_and_pipe       "$(cmd_of none 'cargo test -p x 2>&1 | tail -5')"        "cargo test -p x -- --test-threads=4 2>&1 | tail -5 | etoon$SFX"
eq test_cap_two_test_segments                 "$(cmd_of none 'cargo test -p a; cargo test -p b')"      "cargo test -p a -- --test-threads=4; cargo test -p b -- --test-threads=4 | etoon$SFX"
eq test_cap_after_cd_and_and                  "$(cmd_of none 'cd dir && cargo test -p x -j 2')"        "cd dir && cargo test -p x -j 2 -- --test-threads=4 | etoon$SFX"
eq test_cap_short_alias_with_toolchain        "$(cmd_of none 'cargo +nightly t -p x')"                 "cargo +nightly t -p x -- --test-threads=4 | etoon$SFX"
eq test_cap_nextest_appends_flag              "$(cmd_of none 'cargo nextest run -p x')"                "cargo nextest run -p x --test-threads=4 | etoon$SFX"
eq test_cap_already_capped_unchanged          "$(cmd_of none 'cargo test -- --test-threads=2')"        "cargo test -- --test-threads=2 | etoon$SFX"
eq test_cap_env_var_unchanged                 "$(cmd_of none 'RUST_TEST_THREADS=2 cargo test -p x')"   "RUST_TEST_THREADS=2 cargo test -p x | etoon$SFX"
eq test_cap_no_run_unchanged                  "$(cmd_of none 'cargo test --no-run -p x')"              "cargo test --no-run -p x | etoon$SFX"
eq test_cap_nextest_jobs_unchanged            "$(cmd_of none 'cargo nextest run -j 4')"                "cargo nextest run -j 4 | etoon$SFX"
eq test_cap_testx_unchanged                   "$(cmd_of none 'cargo testx -p x')"                      "cargo testx -p x | etoon$SFX"
eq test_cap_quoted_grep_pattern_unchanged     "$(cmd_of none 'grep -rn "cargo test" docs')"            "grep -rn \"cargo test\" docs | etoon$SFX"
eq test_cap_unbalanced_quote_unchanged        "$(cmd_of none 'cargo test -p "x')"                      "cargo test -p \"x | etoon$SFX"
eq test_cap_command_substitution_unchanged    "$(cmd_of none 'cargo test -p $(echo x)')"               "cargo test -p \$(echo x) | etoon$SFX"
eq test_cap_inside_subshell_group             "$(cmd_of none '(cargo test -p x)')"                     "(cargo test -p x -- --test-threads=4) | etoon$SFX"
eq test_cap_inside_brace_group                "$(cmd_of none '{ cargo test -p x; }')"                  "{ cargo test -p x -- --test-threads=4; } | etoon$SFX"
eq test_cap_after_time_and_env_prefix         "$(cmd_of none 'FOO=1 time cargo test -p x')"            "FOO=1 time cargo test -p x -- --test-threads=4 | etoon$SFX"
eq test_cap_absolute_cargo_path               "$(cmd_of none '~/.cargo/bin/cargo test -p x')"          "~/.cargo/bin/cargo test -p x -- --test-threads=4 | etoon$SFX"
eq test_cap_quoted_dashdash_is_the_separator "$(cmd_of none 'cargo test "--" x')"                    "cargo test \"--\" --test-threads=4 x | etoon$SFX"
eq test_cap_in_bash_c_body_rewritten          "$(cmd_of none 'bash -c "cargo test -p x"')"             "bash -c \"cargo test -p x -- --test-threads=4\" | etoon$SFX"
eq test_cap_in_sh_c_single_quote_rewritten    "$(cmd_of none "sh -c 'cargo test -p x'")"               "sh -c 'cargo test -p x -- --test-threads=4' | etoon$SFX"
eq test_cap_in_bash_lc_rewritten              "$(cmd_of none 'bash -lc "cd x && cargo test"')"         "bash -lc \"cd x && cargo test -- --test-threads=4\" | etoon$SFX"
eq test_cap_in_bash_c_dashdash_rewritten      "$(cmd_of none 'bash -c -- "cargo test"')"               "bash -c -- \"cargo test -- --test-threads=4\" | etoon$SFX"
eq test_cap_in_eval_rewritten                 "$(cmd_of none 'eval "cargo test -p x"')"                "eval \"cargo test -p x -- --test-threads=4\" | etoon$SFX"
# review findings: every failure_scenario of the codex review, exact rewrite or no rewrite
eq test_cap_inserted_before_comment           "$(cmd_of none 'cargo test # hello')"                    "cargo test -- --test-threads=4 # hello | etoon$SFX"
eq test_cap_every_test_in_compound            "$(cmd_of none 'cargo build && bash -c "cargo test"')"   "cargo build && bash -c \"cargo test -- --test-threads=4\" | etoon$SFX"
eq test_cap_both_segments_with_bash_c         "$(cmd_of none 'cargo test; bash -c "cargo test"')"      "cargo test -- --test-threads=4; bash -c \"cargo test -- --test-threads=4\" | etoon$SFX"
eq test_cap_other_segment_text_is_no_cap      "$(cmd_of none 'echo --test-threads; bash -c "cargo test"')" "echo --test-threads; bash -c \"cargo test -- --test-threads=4\" | etoon$SFX"
eq test_cap_partial_rewrite_refused           "$(cmd_of none 'cargo test; bash -c $'"'"'cargo test'"'"'')" "cargo test; bash -c \$'cargo test' | etoon$SFX"
eq test_cap_second_segment_substitution_refused "$(cmd_of none 'cargo test -- --test-threads=2; cargo test -p $(echo x)')" "cargo test -- --test-threads=2; cargo test -p \$(echo x) | etoon$SFX"
eq test_cap_echo_substitution_refused         "$(cmd_of none 'cargo test && echo $(cargo test)')"      "cargo test && echo \$(cargo test) | etoon$SFX"
eq test_cap_global_option_before_subcommand   "$(cmd_of none 'cargo --offline test')"                  "cargo --offline test -- --test-threads=4 | etoon$SFX"
eq test_cap_value_global_option               "$(cmd_of none 'cargo --color always test -q')"          "cargo --color always test -q -- --test-threads=4 | etoon$SFX"
eq test_cap_quoted_cargo_word                 "$(cmd_of none '"cargo" test')"                          "\"cargo\" test -- --test-threads=4 | etoon$SFX"
eq test_cap_quoted_subcommand_word            "$(cmd_of none 'cargo "test"')"                          "cargo \"test\" -- --test-threads=4 | etoon$SFX"
eq test_cap_backslash_in_cargo_word           "$(cmd_of none 'car\go test')"                          "car\\go test -- --test-threads=4 | etoon$SFX"
eq test_cap_ansi_c_body_refused               "$(cmd_of none "bash -c \$'cargo test'")"               "bash -c \$'cargo test' | etoon$SFX"
eq test_cap_eval_split_words_refused          "$(cmd_of none 'eval "cargo" "test"')"                   "eval \"cargo\" \"test\" | etoon$SFX"
eq test_cap_unparsed_cargo_option_refused     "$(cmd_of none 'cargo --weird test')"                    "cargo --weird test | etoon$SFX"
eq test_cap_dynamic_command_word_refused      "$(cmd_of none 'c=cargo; "$c" test')"                    "c=cargo; \"\$c\" test | etoon$SFX"
eq test_cap_env_unset_undoes_env_cap          "$(cmd_of none 'RUST_TEST_THREADS=4 env -u RUST_TEST_THREADS cargo test')" "RUST_TEST_THREADS=4 env -u RUST_TEST_THREADS cargo test -- --test-threads=4 | etoon$SFX"
eq test_cap_env_cap_kept_for_libtest          "$(cmd_of none 'RUST_TEST_THREADS=4 cargo test -p x')"   "RUST_TEST_THREADS=4 cargo test -p x | etoon$SFX"
eq test_cap_env_wrapper_assignment_kept       "$(cmd_of none 'env RUST_TEST_THREADS=2 cargo test')"    "env RUST_TEST_THREADS=2 cargo test | etoon$SFX"
eq test_cap_libtest_env_is_no_nextest_cap     "$(cmd_of none 'RUST_TEST_THREADS=4 cargo nextest run')" "RUST_TEST_THREADS=4 cargo nextest run --test-threads=4 | etoon$SFX"
eq test_cap_nextest_env_kept                  "$(cmd_of none 'NEXTEST_TEST_THREADS=4 cargo nextest run')" "NEXTEST_TEST_THREADS=4 cargo nextest run | etoon$SFX"
eq test_cap_nextest_jobs_flag_kept            "$(cmd_of none 'cargo nextest run --jobs 4')"            "cargo nextest run --jobs 4 | etoon$SFX"
eq test_cap_nextest_before_filter_dashdash    "$(cmd_of none 'cargo nextest run -p x -- filt')"        "cargo nextest run -p x --test-threads=4 -- filt | etoon$SFX"
eq test_cap_nextest_list_unchanged            "$(cmd_of none 'cargo nextest list')"                    "cargo nextest list | etoon$SFX"
eq test_cap_redirect_stays_with_command       "$(cmd_of none 'cargo test >/dev/null -p x')"            "cargo test >/dev/null -p x -- --test-threads=4 | etoon$SFX"
eq test_cap_redirect_before_existing_dashdash "$(cmd_of none 'cargo test >/dev/null -- --nocapture')"  "cargo test >/dev/null -- --test-threads=4 --nocapture | etoon$SFX"
eq test_cap_echo_argument_unchanged           "$(cmd_of none 'echo cargo test')"                       "echo cargo test | etoon$SFX"
eq test_cap_for_list_unchanged                "$(cmd_of none 'for x in cargo test; do echo "$x"; done')" "for x in cargo test; do echo \"\$x\"; done | etoon$SFX"
eq test_cap_comment_text_unchanged            "$(cmd_of none 'echo ok # cargo test')"                  "echo ok # cargo test | etoon$SFX"
eq test_cap_grep_dash_c_unchanged             "$(cmd_of none 'grep -c "cargo test" README.md')"        "grep -c \"cargo test\" README.md | etoon$SFX"
eq test_cap_quoted_heredoc_text_unchanged     "$(cmd_of none $'cat <<\'EOF\'\ncargo test\nEOF')"       NO-COMMAND
eq test_cap_heredoc_as_stdin_gets_cap         "$(cmd_of none $'cargo test <<EOF\nx\nEOF')"             $'cargo test -- --test-threads=4 <<EOF\nx\nEOF'
eq test_cap_in_if_condition                   "$(cmd_of none 'if cargo test; then echo ok; fi')"       "if cargo test -- --test-threads=4; then echo ok; fi | etoon$SFX"
# exec wrappers and runners (sudo, xargs, stdbuf, ...): the command word behind them gets the cap, or the command stays and the guard blocks
eq test_cap_wrapper_sudo "$(cmd_of none 'sudo cargo test')" "sudo cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_sudo_user "$(cmd_of none 'sudo -u x cargo test -p a')" "sudo -u x cargo test -p a -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_sudo_dashdash "$(cmd_of none 'sudo -E -u x -- cargo test')" "sudo -E -u x -- cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_sudo_assignment "$(cmd_of none 'sudo FOO=1 cargo test')" "sudo FOO=1 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_sudo_nextest "$(cmd_of none 'sudo cargo nextest run')" "sudo cargo nextest run --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_doas "$(cmd_of none 'doas -u x cargo test')" "doas -u x cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_xargs "$(cmd_of none 'xargs cargo test')" "xargs cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_xargs_options "$(cmd_of none 'echo a | xargs -n1 -P 2 cargo test')" "echo a | xargs -n1 -P 2 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_stdbuf_attached "$(cmd_of none 'stdbuf -oL cargo test -p a')" "stdbuf -oL cargo test -p a -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_stdbuf_separate "$(cmd_of none 'stdbuf -o L -e0 cargo test')" "stdbuf -o L -e0 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_ionice "$(cmd_of none 'ionice -c3 cargo test')" "ionice -c3 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_ionice_values "$(cmd_of none 'ionice -c 2 -n 7 cargo test')" "ionice -c 2 -n 7 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_chrt "$(cmd_of none 'chrt -i 0 cargo test')" "chrt -i 0 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_taskset "$(cmd_of none 'taskset -c 0-3 cargo test')" "taskset -c 0-3 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_flock "$(cmd_of none 'flock /tmp/l cargo test')" "flock /tmp/l cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_flock_timeout "$(cmd_of none 'flock -w 5 /tmp/l cargo test')" "flock -w 5 /tmp/l cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_flock_c_body "$(cmd_of none 'flock /tmp/l -c "cargo test"')" "flock /tmp/l -c \"cargo test -- --test-threads=4\" | etoon""$SFX"
eq test_cap_wrapper_systemd_run "$(cmd_of none 'systemd-run --user --scope cargo test')" "systemd-run --user --scope cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_systemd_run_property "$(cmd_of none 'systemd-run -p MemoryMax=1G cargo test')" "systemd-run -p MemoryMax=1G cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_unbuffer "$(cmd_of none 'unbuffer -p cargo test')" "unbuffer -p cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_setpriv "$(cmd_of none 'setpriv --reuid 1000 --no-new-privs cargo test')" "setpriv --reuid 1000 --no-new-privs cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_firejail "$(cmd_of none 'firejail --quiet --net=none cargo test')" "firejail --quiet --net=none cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_caffeinate "$(cmd_of none 'caffeinate -t 60 cargo test')" "caffeinate -t 60 cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_command "$(cmd_of none 'command cargo test')" "command cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_exec "$(cmd_of none 'exec cargo test')" "exec cargo test -- --test-threads=4"   # exec is a builtin: etoon is skipped, the cap stays
eq test_cap_wrapper_builtin "$(cmd_of none 'builtin cargo test')" "builtin cargo test -- --test-threads=4 | etoon""$SFX"
eq test_cap_wrapper_unchanged_sudo_already_capped "$(cmd_of none 'sudo cargo test -- --test-threads=2')" "sudo cargo test -- --test-threads=2 | etoon""$SFX"
eq test_cap_wrapper_unchanged_sudo_unknown_option_test "$(cmd_of none 'sudo --weird cargo test')" "sudo --weird cargo test | etoon""$SFX"
eq test_cap_wrapper_unchanged_stdbuf_unknown_option_test "$(cmd_of none 'stdbuf -z cargo test')" "stdbuf -z cargo test | etoon""$SFX"
eq test_cap_wrapper_unchanged_sudo_unknown_option_build "$(cmd_of none 'sudo --weird cargo build')" "sudo --weird cargo build | etoon""$SFX"
eq test_cap_wrapper_unchanged_echo_sudo_argument "$(cmd_of none 'echo sudo cargo test')" "echo sudo cargo test | etoon""$SFX"
eq test_cap_wrapper_unchanged_docker_run_test "$(cmd_of none 'docker run img cargo test')" "docker run img cargo test | etoon""$SFX"
eq test_cap_wrapper_unchanged_docker_run_capped "$(cmd_of none 'docker run img cargo test -- --test-threads=2')" "docker run img cargo test -- --test-threads=2 | etoon""$SFX"
eq test_cap_wrapper_unchanged_podman_no_run "$(cmd_of none 'podman exec c cargo test --no-run')" "podman exec c cargo test --no-run | etoon""$SFX"
eq test_cap_wrapper_unchanged_ssh_quoted_test "$(cmd_of none 'ssh host "cargo test"')" "ssh host \"cargo test\" | etoon""$SFX"
eq test_cap_wrapper_unchanged_ssh_quoted_capped "$(cmd_of none 'ssh host '\''cargo test -- --test-threads=2'\''')" "ssh host 'cargo test -- --test-threads=2' | etoon""$SFX"
eq test_cap_wrapper_unchanged_ssh_build "$(cmd_of none 'ssh host cargo build')" "ssh host cargo build | etoon""$SFX"
eq test_cap_wrapper_unchanged_wsl_nextest "$(cmd_of none 'wsl cargo nextest run')" "wsl cargo nextest run | etoon""$SFX"
eq test_cap_wrapper_unchanged_sudo_docker_test "$(cmd_of none 'sudo docker run img cargo t')" "sudo docker run img cargo t | etoon""$SFX"
# rtk fails without blocking (exit 1, empty stdout): the harness would run the original command
R=$(run fail1 "$(input 'cargo test -p x')")
eq    test_cap_survives_rtk_nonblocking_failure "$R" $'{"command":"cargo test -p x -- --test-threads=4"}\nrc=0'
R=$(run fail1 "$(input 'ls')")
eq    test_rtk_nonblocking_failure_without_cap_fails_open "$R" rc=0
R=$(run fail "$(input 'cargo test -p x')")
eq    test_rtk_block_with_cap_ships_capped_command "$R" $'{"command":"cargo test -p x -- --test-threads=4"}\nrc=0'
# pipefail: the appended status suffix reads one pipeline element, so etoon is skipped
eq    test_pipefail_command_gets_no_etoon       "$(run none "$(input 'set -o pipefail; false | true')")" rc=0
eq    test_pipefail_command_keeps_cap_without_etoon "$(cmd_of none 'set -o pipefail; cargo test -p x | tail')" 'set -o pipefail; cargo test -p x -- --test-threads=4 | tail'
eq test_cap_with_rtk_rewrite                 "$(cmd_of rewrite 'cargo test -p x')"                    "rtk cargo test -p x -- --test-threads=4 | etoon$SFX"
# skip paths still carry the cap: a trailing `&` and a final `> file` skip etoon
eq test_cap_on_skip_path_without_rtk_rewrite  "$(cmd_of none 'cargo test -p x > out.txt')"             'cargo test -p x -- --test-threads=4 > out.txt'
eq test_cap_on_skip_path_with_rtk_rewrite     "$(cmd_of rewrite 'cargo test -p x &')"                  'rtk cargo test -p x -- --test-threads=4 &'
eq test_cap_skip_path_keeps_other_fields      "$(run none '{"tool_input":{"command":"cargo test -p x > o","description":"d","timeout":5000}}' | head -1)" \
    '{"command":"cargo test -p x -- --test-threads=4 > o","description":"d","timeout":5000}'
R=$(printf '%s' "$(input 'cargo test -p x')" | RTK_STUB=ask PATH="$T/bin:/usr/bin:/bin" "${HOOK[@]}")
check test_cap_kept_when_rtk_only_decides       "$R" '"permissionDecision":"ask"'
check test_cap_kept_when_rtk_only_decides_cmd   "$R" '"command":"cargo test -p x -- --test-threads=4"'
eq    test_non_cargo_command_untouched          "$(cmd_of none 'echo cargo')"                          "echo cargo | etoon$SFX"

rm -f "$T/bin/rtk" "$T/bin/etoon" "$T/err"; rmdir "$T/bin" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
