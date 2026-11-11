# Run: bash ~/.claude/hooks/tests/test_guard_cargo_disk.sh
# CARGO_MIN_FREE_GB=1000000 makes every disk "low"; 0 makes every disk "enough".
# Every run uses a scratch HOME and a scratch non-git cwd, so the target/ size cache of the real
# repo never reaches a test; the disk-minimum section builds its own git repo with worktrees.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/guard-cargo-disk.sh"
pass=0; fail=0
H=$(mktemp -d "$HOME/.cache/cargo-guard-test.XXXXXX"); trap 'case "$H" in "$HOME"/.cache/cargo-guard-test.?*) rm -rf -- "$H" ;; esac' EXIT
mkdir "$H/plain"
run() { jq -nc --arg c "$1" --arg d "$H/plain" '{tool_input:{command:$c},cwd:$d}' | HOME=$H CARGO_MIN_FREE_GB=$2 bash "$SCRIPT" >/dev/null 2>&1; echo $?; }
check() { if [ "$(run "$2" "$3")" = "$4" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: [$2] min=$3 want rc=$4"; fi; }
low=1000000

# Low disk, compiling command: blocked (rc=2).
check test_cargo_test_low_disk_blocked            'cargo test -j 4 -p x --tests -- --test-threads=4' $low 2
check test_cargo_build_low_disk_blocked           'cargo build -p x --bin ecp --release'           $low 2
check test_cargo_clippy_low_disk_blocked          'cargo clippy -j 4 -p x --tests'                 $low 2
check test_cargo_check_short_alias_blocked        'cargo c'                                        $low 2
check test_cargo_nextest_low_disk_blocked         'cargo nextest run -p x --test-threads=4'         $low 2
check test_cargo_toolchain_prefix_blocked         'cargo +nightly build'                           $low 2
check test_cargo_after_cd_blocked                 'cd /tmp && cargo test'                          $low 2
check test_cargo_absolute_path_blocked            '~/.cargo/bin/cargo build'                       $low 2
check test_cargo_in_bash_c_blocked                'bash -c "cargo test"'                           $low 2
check test_cargo_after_semicolon_blocked          'git status;cargo build'                         $low 2
check test_cargo_global_option_blocked            'cargo --offline build'                          $low 2
check test_cargo_quoted_word_blocked              '"cargo" build'                                  $low 2
check test_cargo_backslash_word_blocked           'car\go build'                                   $low 2
check test_cargo_build_after_env_prefix_blocked   'FOO=1 env BAR=2 cargo build'                    $low 2
check test_cargo_in_subshell_blocked              '(cargo build)'                                  $low 2
check test_cargo_in_brace_group_blocked           '{ cargo build; }'                               $low 2
check test_cargo_in_command_substitution_blocked  'echo $(cargo build)'                            $low 2
check test_cargo_after_time_blocked               'time cargo build'                               $low 2
check test_cargo_in_eval_body_blocked             'eval "cd x && cargo build"'                     $low 2
check test_cargo_in_bash_lc_blocked               'bash -lc "cargo build"'                         $low 2
check test_cargo_in_if_condition_blocked          'if cargo check; then echo ok; fi'               $low 2

# Low disk, command that frees space or does not compile, or a cargo word that is not a command: allowed.
check test_cargo_clean_low_disk_allowed           'cargo clean --manifest-path /x/Cargo.toml'      $low 0
check test_cargo_fmt_low_disk_allowed             'cargo fmt --check'                              $low 0
check test_cargo_metadata_low_disk_allowed        'cargo metadata --format-version 1'              $low 0
check test_cargo_version_low_disk_allowed         'cargo --version'                                $low 0
check test_cargo_word_in_text_allowed             'grep -n "cargo test" CLAUDE.md'                 $low 0
check test_no_cargo_allowed                       'ls -la'                                         $low 0
check test_cargo_subcommand_prefix_allowed        'cargo tree -p x'                                $low 0
check test_echo_cargo_build_allowed               'echo cargo build'                               $low 0
check test_comment_cargo_build_allowed            'echo ok # cargo build'                          $low 0
check test_quoted_heredoc_cargo_build_allowed     $'cat <<\'EOF\'\ncargo build\nEOF'                $low 0
check test_grep_dash_c_pattern_allowed            'grep -c "cargo test" README.md'                 $low 0
check test_for_list_cargo_test_allowed            'for x in cargo test; do echo "$x"; done'        $low 0
check test_quoted_text_in_mpm_add_allowed         'mpm add --next "compare cargo test --list and cargo build times"' $low 0
check test_single_quoted_cargo_build_allowed      "echo 'cargo build' | cat"                       $low 0
check test_unquoted_heredoc_with_substitution_blocked $'cat <<EOF\n$(cargo build)\nEOF'            $low 2

# Enough disk: allowed.
check test_cargo_test_enough_disk_allowed         'cargo test -j 4 -- --test-threads=4'            0    0

# cargo test must cap its test threads: -j caps only the compile jobs. lib/cargo_test_cap.py is the
# one authority. A command it rewrites passes (the Bash hook adds the cap, see test_auto_etoon.sh for
# the exact text); a test invocation it cannot cap blocks, wherever it sits in the command.
check test_cargo_test_rewritable_allowed          'cargo test -j 4 -p x --tests'                   0    0
check test_cargo_test_short_alias_rewritable_allowed 'cd /tmp && cargo t'                          0    0
check test_cargo_test_nocapture_rewritable_allowed 'cargo test -p x -- --nocapture'                0    0
check test_cargo_test_pipe_rewritable_allowed     'cargo test -p x -j 2 2>&1 | tail -5'            0    0
check test_cargo_test_two_segments_rewritable_allowed 'cargo test -p a; cargo test -p b'           0    0
check test_cargo_nextest_rewritable_allowed       'cargo nextest run -p x'                         0    0
check test_cargo_nextest_with_threads_allowed     'cargo nextest run -p x --test-threads=4'        0    0
check test_cargo_test_env_threads_allowed         'RUST_TEST_THREADS=4 cargo test -j 4'            0    0
check test_cargo_test_no_run_allowed              'cargo test --no-run -j 4'                       0    0
check test_cargo_build_needs_no_threads_allowed   'cargo build -j 4 -p x'                          0    0
check test_cargo_nextest_list_needs_no_threads_allowed 'cargo nextest list'                        0    0
check test_cargo_testx_allowed                    'cargo testx -p x'                               0    0
check test_cargo_test_heredoc_stdin_rewritable_allowed $'cargo test <<EOF\nx\nEOF'                 0    0
check test_cargo_test_unbalanced_quote_blocked    'cargo test -p "x'                               0    2
check test_cargo_test_command_substitution_blocked 'cargo test -p $(echo x)'                       0    2
check test_cargo_test_backtick_blocked            'cargo test -p `echo x`'                         0    2
check test_cargo_in_bash_c_body_rewritable_allowed 'bash -c "cargo test -p x"'                     0    0
check test_cargo_in_sh_c_single_quote_rewritable_allowed "sh -c 'cargo test -p x'"                 0    0

# One finding per case of the codex review of these hooks (failure_scenario strings).
check test_comment_gets_cap_before_hash           'cargo test # hello'                             0    0
check test_cap_of_other_segment_does_not_cover_substitution 'cargo test -- --test-threads=2; cargo test -p $(echo x)' 0 2
check test_echo_word_is_no_cap_for_bash_c         'echo --test-threads; bash -c "cargo test"'      0    0
check test_build_first_does_not_hide_later_test   'cargo build && bash -c $'"'"'cargo test'"'"''   0    2
check test_partial_rewrite_is_no_pass             'cargo test; bash -c $'"'"'cargo test'"'"''      0    2
check test_substitution_after_capped_test_blocked 'cargo test -- --test-threads=2 && echo $(cargo test)' 0 2
check test_global_option_before_subcommand_allowed 'cargo --offline test'                          0    0
check test_quoted_cargo_word_rewritable_allowed   '"cargo" test'                                   0    0
check test_quoted_subcommand_rewritable_allowed   'cargo "test"'                                   0    0
check test_backslash_cargo_word_rewritable_allowed 'car\go test'                                   0    0
check test_bash_c_dashdash_body_rewritable_allowed 'bash -c -- "cargo test"'                       0    0
check test_bash_c_ansi_c_body_blocked             "bash -c \$'cargo test'"                         0    2
check test_eval_split_words_blocked               'eval "cargo" "test"'                            0    2
check test_unparsed_cargo_option_blocked          'cargo --weird test'                             0    2
check test_dynamic_command_word_blocked           'c=cargo; "$c" test'                             0    2
check test_env_unset_does_not_keep_cap_rewritable_allowed 'RUST_TEST_THREADS=4 env -u RUST_TEST_THREADS cargo test' 0 0
check test_env_unset_ansi_body_blocked            "RUST_TEST_THREADS=4 env -u RUST_TEST_THREADS bash -c \$'cargo test'" 0 2
check test_libtest_env_for_nextest_rewritable_allowed 'RUST_TEST_THREADS=4 cargo nextest run'      0    0
check test_redirect_before_args_rewritable_allowed 'cargo test >/dev/null -p x'                    0    0
check test_ansi_hex_command_word_blocked          "\$'\\x63argo' test"                             0    2

# A sub-agent that edits files (a marker under ~/.cache/claude-agents/<session>/) blocks
# every compiling cargo command of that session, the agent's own included.
arun() { jq -nc --arg c "$1" --arg d "$H/plain" --arg s "$2" '{tool_input:{command:$c},cwd:$d,session_id:$s}' | HOME=$H CARGO_MIN_FREE_GB=0 bash "$SCRIPT" >/dev/null 2>&1; echo $?; }
acheck() { if [ "$(arun "$2" "$3")" = "$4" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: [$2] session=$3 want rc=$4"; fi; }
mkdir -p "$H/.cache/claude-agents/s1" "$H/.cache/claude-agents/s2"
printf 'general-purpose\n' > "$H/.cache/claude-agents/s1/a1"
printf 'general-purpose\n' > "$H/.cache/claude-agents/s2/old"; touch -d '100 minutes ago' "$H/.cache/claude-agents/s2/old"
acheck test_cargo_build_while_agent_edits_blocked     'cargo build -j 4 -p x'                     s1 2
acheck test_cargo_clippy_while_agent_edits_blocked    'cargo clippy -j 4 -p x --tests'            s1 2
acheck test_cargo_fmt_while_agent_edits_allowed       'cargo fmt --check'                         s1 0
acheck test_cargo_build_other_session_agent_allowed   'cargo build -j 4 -p x'                     s3 0
acheck test_cargo_build_stale_marker_allowed          'cargo build -j 4 -p x'                     s2 0
acheck test_cargo_build_no_session_id_allowed         'cargo build -j 4 -p x'                     ''  0

# A cargo word that is only text never meets check 1.
MPM='cd /repo && mpm add --category build --next "Per crate: compare cargo test --list counts before/after and cargo build times"'
acheck test_quoted_cargo_text_in_mpm_add_allowed      "$MPM"                                      s1 0
acheck test_quoted_cargo_in_single_quotes_allowed     "echo 'cargo build'"                        s1 0
acheck test_quoted_cargo_in_double_quotes_allowed     'echo "cargo build -p x"'                   s1 0
acheck test_echo_cargo_test_allowed                   'echo cargo test'                           s1 0
acheck test_grep_dash_c_cargo_pattern_allowed         'grep -c "cargo test" README.md'            s1 0
acheck test_comment_with_cargo_allowed                'echo ok # cargo build'                     s1 0
acheck test_quoted_text_then_real_cargo_blocked       "echo 'cargo build' && cargo build -p x"    s1 2
acheck test_bash_c_double_quote_blocked               'bash -c "cargo test -p x"'                 s1 2
acheck test_sh_c_single_quote_blocked                 "sh -c 'cargo build'"                       s1 2
acheck test_bash_lc_cluster_blocked                   'bash -lc "cargo build -p x"'               s1 2
acheck test_eval_quoted_blocked                       'eval "cargo build -p x"'                   s1 2
acheck test_bash_c_compound_body_blocked              'bash -c "cd x && cargo build"'             s1 2
acheck test_command_substitution_in_quotes_blocked    'echo "$(cargo build -p x)"'                s1 2
acheck test_backtick_in_double_quotes_blocked         'echo "`cargo build -p x`"'                 s1 2
acheck test_bare_command_substitution_blocked         'echo $(cargo build -p x)'                  s1 2
acheck test_subshell_group_blocked                    '(cargo build -p x)'                        s1 2
acheck test_env_prefix_blocked                        'FOO=1 cargo build -p x'                    s1 2
acheck test_unbalanced_quote_keeps_old_match_blocked  'echo "x" && cargo build "y'               s1 2

# exec wrappers: sudo, xargs, stdbuf and the like run a command behind their options
check test_wrapper_sudo_rewritable_allowed 'sudo cargo test' 0 0
check test_wrapper_sudo_user_rewritable_allowed 'sudo -u x cargo test -p a' 0 0
check test_wrapper_sudo_dashdash_rewritable_allowed 'sudo -E -u x -- cargo test' 0 0
check test_wrapper_sudo_assignment_rewritable_allowed 'sudo FOO=1 cargo test' 0 0
check test_wrapper_sudo_nextest_rewritable_allowed 'sudo cargo nextest run' 0 0
check test_wrapper_doas_rewritable_allowed 'doas -u x cargo test' 0 0
check test_wrapper_xargs_rewritable_allowed 'xargs cargo test' 0 0
check test_wrapper_xargs_options_rewritable_allowed 'echo a | xargs -n1 -P 2 cargo test' 0 0
check test_wrapper_stdbuf_attached_rewritable_allowed 'stdbuf -oL cargo test -p a' 0 0
check test_wrapper_stdbuf_separate_rewritable_allowed 'stdbuf -o L -e0 cargo test' 0 0
check test_wrapper_ionice_rewritable_allowed 'ionice -c3 cargo test' 0 0
check test_wrapper_ionice_values_rewritable_allowed 'ionice -c 2 -n 7 cargo test' 0 0
check test_wrapper_chrt_rewritable_allowed 'chrt -i 0 cargo test' 0 0
check test_wrapper_taskset_rewritable_allowed 'taskset -c 0-3 cargo test' 0 0
check test_wrapper_flock_rewritable_allowed 'flock /tmp/l cargo test' 0 0
check test_wrapper_flock_timeout_rewritable_allowed 'flock -w 5 /tmp/l cargo test' 0 0
check test_wrapper_flock_c_body_rewritable_allowed 'flock /tmp/l -c "cargo test"' 0 0
check test_wrapper_systemd_run_rewritable_allowed 'systemd-run --user --scope cargo test' 0 0
check test_wrapper_systemd_run_property_rewritable_allowed 'systemd-run -p MemoryMax=1G cargo test' 0 0
check test_wrapper_unbuffer_rewritable_allowed 'unbuffer -p cargo test' 0 0
check test_wrapper_setpriv_rewritable_allowed 'setpriv --reuid 1000 --no-new-privs cargo test' 0 0
check test_wrapper_firejail_rewritable_allowed 'firejail --quiet --net=none cargo test' 0 0
check test_wrapper_caffeinate_rewritable_allowed 'caffeinate -t 60 cargo test' 0 0
check test_wrapper_command_rewritable_allowed 'command cargo test' 0 0
check test_wrapper_exec_rewritable_allowed 'exec cargo test' 0 0
check test_wrapper_builtin_rewritable_allowed 'builtin cargo test' 0 0
check test_wrapper_sudo_build_low_disk_blocked 'sudo -u x cargo build' $low 2
check test_wrapper_xargs_build_low_disk_blocked 'xargs cargo build' $low 2
check test_wrapper_stdbuf_test_low_disk_blocked 'stdbuf -oL cargo test -p a' $low 2
check test_wrapper_flock_c_build_low_disk_blocked 'flock /tmp/l -c "cargo build"' $low 2
check test_wrapper_taskset_build_low_disk_blocked 'taskset -c 0 cargo build' $low 2
check test_wrapper_echo_sudo_test_low_disk_allowed 'echo sudo cargo test' $low 0
check test_wrapper_ssh_build_low_disk_allowed 'ssh host cargo build' $low 0
check test_wrapper_echo_xargs_low_disk_allowed 'echo xargs cargo build' $low 0
check test_wrapper_sudo_unknown_option_test_blocked 'sudo --weird cargo test' 0 2
check test_wrapper_stdbuf_unknown_option_test_blocked 'stdbuf -z cargo test' 0 2
check test_wrapper_docker_run_test_blocked 'docker run img cargo test' 0 2
check test_wrapper_podman_nextest_blocked 'podman exec c cargo nextest run' 0 2
check test_wrapper_ssh_quoted_test_blocked 'ssh host "cargo test"' 0 2
check test_wrapper_wsl_test_blocked 'wsl cargo test' 0 2
check test_wrapper_sudo_docker_test_blocked 'sudo docker run img cargo t' 0 2
check test_wrapper_sudo_unknown_option_build_allowed 'sudo --weird cargo build' 0 0
check test_wrapper_docker_run_capped_allowed 'docker run img cargo test -- --test-threads=2' 0 0
check test_wrapper_podman_no_run_allowed 'podman exec c cargo test --no-run' 0 0
check test_wrapper_ssh_quoted_capped_allowed 'ssh host '\''cargo test -- --test-threads=2'\''' 0 0
check test_wrapper_sudo_already_capped_allowed 'sudo cargo test -- --test-threads=2' 0 0
acheck test_wrapper_sudo_build_while_agent_edits_blocked 'sudo -u x cargo build' s1 2
acheck test_wrapper_xargs_test_while_agent_edits_blocked 'xargs cargo test' s1 2
acheck test_wrapper_echo_sudo_while_agent_edits_allowed 'echo sudo cargo test' s1 0

# Disk minimum = max(CARGO_MIN_FREE_GB or 20, largest worktree target/ - this worktree's target/), in bytes.
# The sizes come from ~/.cache/claude-cargo-disk/<hash of the repo common dir>.tsv, fresh for 6 hours.
GIB=1073741824
G="$H/repo"
git init -q "$G" && git -C "$G" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init &&
    git -C "$G" worktree add -q "$H/wt2" -b wt2 && mkdir "$G/target" "$H/wt2/target"
CACHE="$H/.cache/claude-cargo-disk/$(printf '%s' "$(git -C "$G" rev-parse --path-format=absolute --git-common-dir)" | sha1sum | cut -c1-16).tsv"
mkdir -p "$H/.cache/claude-cargo-disk" "$H/stub"
# stub du: prints 1 GiB for each dir and records that it ran; STUB_DU_FAIL=1 makes it fail.
cat > "$H/stub/du" <<'EOF'
#!/bin/bash
echo ran >> "$STUB_DU_LOG"
[ "${STUB_DU_FAIL:-}" = 1 ] && exit 1
for a in "${@:3}"; do printf '1073741824\t%s\n' "$a"; done
EOF
# stub df: STUB_DF_AVAIL (bytes) replaces the free space; without it the real df runs.
cat > "$H/stub/df" <<'EOF'
#!/bin/bash
# Without -B1 the stub answers in rounded-up GiB, as `df -BG` does.
[ -n "${STUB_DF_AVAIL:-}" ] && { echo Avail; case "$*" in *-B1*) echo "$STUB_DF_AVAIL" ;; *) echo "$(( (STUB_DF_AVAIL + 1073741823) / 1073741824 ))G" ;; esac; exit 0; }
exec /usr/bin/df "$@"
EOF
chmod +x "$H/stub/du" "$H/stub/df"
# dsetup "<GB>\t<path>\n..." AGE: the cache holds those sizes (GB converted to bytes) at that age
dsetup() { printf '%b' "$1" | awk -F'\t' -v g=$GIB '{printf "%.0f\t%s\n", $1 * g, $2}' > "$CACHE"; touch -d "$2" "$CACHE"; : > "$H/du.log"; }
# drun CMD MIN [FAIL] [AVAIL_BYTES] -> rc on the first line, stderr after it
drun() { local rc; jq -nc --arg c "$1" --arg d "$G" '{tool_input:{command:$c},cwd:$d}' |
    HOME=$H PATH="$H/stub:$PATH" STUB_DU_LOG="$H/du.log" STUB_DU_FAIL="${3:-}" STUB_DF_AVAIL="${4:-}" CARGO_MIN_FREE_GB=$2 bash "$SCRIPT" 2>"$H/err" >/dev/null; rc=$?
    echo "$rc"; cat "$H/err"; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
has() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
BUILD='cargo build -p x'

dsetup "5\t$G/target\n" now
eq  test_disk_floor_applies_without_other_worktree     "$(drun "$BUILD" 0 | head -1)"        0
has test_disk_floor_blocks_when_free_below_floor       "$(drun "$BUILD" $low)"               'Minimum 1000000.0G = CARGO_MIN_FREE_GB or the default 20'
dsetup "100000\t$H/wt2/target\n1\t$G/target\n" now
R=$(drun "$BUILD" 0)
eq  test_disk_derived_minimum_blocks_with_zero_floor   "$(head -1 <<<"$R")"                  2
has test_disk_derived_minimum_message_names_derivation "$R" "Minimum 99999.0G = largest worktree target/ 100000.0G ($H/wt2/target) minus this worktree's 1.0G; the floor is 0G"
has test_disk_message_lists_cached_largest_dirs        "$R" "100000.0G  $H/wt2/target"
dsetup "1\t$H/wt2/target\n100000\t$G/target\n" now
eq  test_disk_own_target_largest_falls_back_to_floor   "$(drun "$BUILD" 0 | head -1)"        0
dsetup "100000\t$H/wt2/target\n" now
eq  test_disk_fresh_cache_runs_no_du                   "$(drun "$BUILD" 0 | head -1; wc -c < "$H/du.log")" $'2\n0'
dsetup "100000\t$H/wt2/target\n" '7 hours ago'
eq  test_disk_stale_cache_refreshed_by_du              "$(drun "$BUILD" 0 | head -1; grep -c ran "$H/du.log"; cut -f1 "$CACHE" | sort -u)" $'0\n1\n1073741824'
# a failed refresh keeps the last sizes (and renews their age); it never writes an empty cache over them
dsetup "100000\t$H/wt2/target\n" '7 hours ago'
eq  test_disk_du_failure_keeps_last_sizes              "$(drun "$BUILD" 0 1 | head -1; cut -f1 "$CACHE"; find "$CACHE" -mmin -1 | wc -l)" $'2\n107374182400000\n1'
rm -f "$CACHE"
eq  test_disk_du_failure_without_sizes_falls_back_to_floor "$(drun "$BUILD" 0 1 | head -1; wc -c < "$CACHE")" $'0\n0'
rm -f "$CACHE"
eq  test_disk_missing_cache_built_with_du              "$(drun "$BUILD" 0 | head -1; test -s "$CACHE" && echo cached)" $'0\ncached'
eq  test_disk_non_numeric_floor_uses_default           "$(drun "$BUILD" ' ' | head -1)"      0
# bytes, not rounded GiB: 20 GiB minus 1 byte is under a 20G floor, 20 GiB is not
dsetup "1\t$G/target\n" now
eq  test_disk_one_byte_under_floor_blocks              "$(drun "$BUILD" 20 '' $((20 * GIB - 1)) | head -1)" 2
eq  test_disk_exact_floor_passes                       "$(drun "$BUILD" 20 '' $((20 * GIB)) | head -1)"     0
has test_disk_message_shows_gib_with_one_decimal       "$(drun "$BUILD" 20 '' $((19 * GIB + GIB / 10)))"    'only 19.1G free'
# a refresh waits for the lock and then finds the sizes another session wrote: no second du
dsetup "100000\t$H/wt2/target\n" '7 hours ago'
exec 8>"$CACHE.lock"; flock 8
drun "$BUILD" 0 > "$H/lockrun.out" &
lockpid=$!
sleep 1
printf '%s\t%s\n' "$GIB" "$H/wt2/target" > "$CACHE"; touch "$CACHE"
exec 8>&-
wait "$lockpid"
eq  test_disk_waiting_refresh_reuses_fresh_cache       "$(head -1 "$H/lockrun.out"; wc -c < "$H/du.log")" $'0\n0'

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
