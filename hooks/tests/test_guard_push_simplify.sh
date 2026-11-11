# Run: bash ~/.claude/hooks/tests/test_guard_push_simplify.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/guard-push-simplify.sh"
pass=0; fail=0
run() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$SCRIPT" >/dev/null 2>&1; echo $?; }
check() { if [ "$(run "$2")" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: [$2] want rc=$3"; fi; }

# Recursive rm on a variable, glob or xargs input: blocked (rc=2).
check test_rm_rf_variable_blocked             'rm -rf $S'                                  2
check test_rm_rf_quoted_variable_blocked      'rm -rf "$S/fonts-old2" 2>/dev/null'         2
check test_rm_rf_braced_variable_blocked      'cd /tmp && rm -rf ${D}'                     2
check test_rm_r_glob_blocked                  'rm -r /tmp/build-*'                         2
check test_rm_upper_r_blocked                 'rm -Rf $x'                                  2
check test_rm_fr_order_blocked                'rm -fr $x'                                  2
check test_rm_long_recursive_blocked          'rm --recursive $x'                          2
check test_rm_after_double_dash_blocked       'rm -rf -- $x'                               2
check test_rm_command_substitution_blocked    'rm -rf $(mktemp -d)'                        2
check test_rm_sudo_prefix_blocked             'sudo rm -rf $x'                             2
check test_rm_env_assignment_prefix_blocked   'X=1 rm -rf $X'                              2
check test_rm_xargs_input_blocked             'find . -name tmp | xargs rm -rf'            2
check test_rm_second_segment_blocked          'S=/tmp/a; rm -rf $S; mkdir -p $S'           2

# Allowed (rc=0).
check test_rm_rf_literal_absolute_allowed     'rm -rf /home/user/x/literal-dir'            0
check test_rm_rf_literal_relative_allowed     'rm -rf ./build'                             0
check test_rm_f_variable_not_recursive_allowed 'rm -f "$T/count"'                          0
check test_rm_variable_no_flag_allowed        'rm $F'                                      0
check test_echo_of_rm_text_allowed            'echo "rm -rf $x"'                           0
check test_grep_recursive_variable_allowed    'grep -r foo $DIR'                           0
check test_empty_command_allowed              ''                                           0
check test_rmdir_variable_allowed             'rmdir $T'                                   0

# Known limit: a separator inside a quoted string splits the segment, so this text trips the guard.
check test_quoted_separator_known_false_positive 'git commit -m "x; rm -rf $y"'            2

# A leading sleep of 10 s or more, or of a length the guard cannot read: blocked (rc=2).
run_bg() { jq -nc --arg c "$1" '{tool_input:{command:$c,run_in_background:true}}' | bash "$SCRIPT" >/dev/null 2>&1; echo $?; }
check test_command_sleep_long_blocked         'command sleep 110; cat /tmp/x.output'       2
check test_plain_sleep_long_blocked           'sleep 30'                                   2
check test_env_sleep_long_blocked             'env sleep 60'                               2
check test_backslash_sleep_long_blocked       '\sleep 20'                                  2
check test_absolute_sleep_long_blocked        '/bin/sleep 15'                              2
check test_sleep_variable_length_blocked      'command sleep $W; curl -s x'                2
check test_sleep_minutes_suffix_blocked       'sleep 2m'                                   2
check test_cd_then_command_sleep_blocked      'cd /tmp; command sleep 60; cat x.output'    2
check test_quoted_variable_length_blocked     'command sleep "$W"'                         2
check test_sleep_in_loop_body_allowed         'for i in 1 2; do command sleep 15; done'    0
check test_mid_command_fixed_wait_allowed     'orca-ide reload; sleep 10; orca-ide eval x' 0
check test_quoted_until_loop_allowed          'timeout 100 bash -c "until grep -q x f; do sleep 2; done"' 0
check test_sleep_in_substitution_blocked      'x=$(sleep 30; echo done)'                   2
check test_sleep_short_allowed                'sleep 2; curl -s localhost:8000'            0
check test_sleep_nine_seconds_allowed         'sleep 9'                                    0
check test_sleep_fraction_allowed             'sleep 0.5'                                  0
check test_sleep_with_redirect_allowed        'sleep 1 >/dev/null'                         0
check test_sleep_text_in_grep_allowed         'grep -n "sleep 60" run.sh'                  0
check test_sleep_in_data_heredoc_allowed      $'cat > /tmp/x.sh <<\'EOF\'\nsleep 60\nEOF'  0
if [ "$(run_bg 'sleep 2720 && curl -s x')" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL test_sleep_background_call_allowed"; fi

# pgrep -f / pkill -f with a pattern that matches the hook's own shell: blocked (rc=2).
check test_pkill_f_plain_pattern_blocked      'pkill -f "sleep 205"'                       2
check test_pgrep_f_in_substitution_blocked    'kill -0 $(pgrep -f "viberank" | head -1)'   2
check test_pgrep_combined_f_flag_blocked      'pgrep -fa node'                             2
check test_pkill_signal_then_f_blocked        'pkill -9 -f viberank'                       2
check test_pgrep_full_long_flag_blocked       'pgrep --full server.py'                     2
check test_pgrep_value_option_then_f_blocked  'pgrep -u user -f node'                      2
check test_pkill_f_bracket_pattern_allowed    'pkill -f "[v]iberank"'                      0
check test_pgrep_exact_name_allowed           'pgrep -x node'                              0
check test_pkill_name_allowed                 'pkill viberank'                             0
check test_pgrep_text_in_echo_allowed         'echo "pgrep -f x"'                          0
check test_pgrep_in_grep_alternation_allowed  'grep -n "^#\|pgrep -f" notes.md'            0
check test_sleep_in_grep_alternation_allowed  'grep -n "a\|sleep 60" run.sh'               0
check test_quoted_pipe_then_real_pgrep_blocked 'grep "a|b" f; pgrep -f node'               2
msg=$(jq -nc --arg c 'command sleep 110; cat x' '{tool_input:{command:$c}}' | bash "$SCRIPT" 2>&1 >/dev/null)
if [[ "$msg" == *'  command sleep 110'* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL test_sleep_message_names_the_command: $msg"; fi

# Push guard: the review is bound to file content through review-mark.sh. Each
# case runs in a fresh repo with a bare remote; the hook reads the repo from cwd.
# The sibling review-mark.sh, so a mirror checkout tests its own copy, not the installed one.
export REVIEW_MARK; REVIEW_MARK="$(cd "$(dirname "$0")/../../skills/simplify" && pwd)/review-mark.sh"; MARK=$REVIEW_MARK
T=$(mktemp -d /tmp/guard-test.XXXXXX)
g() { git -c user.email=t@t -c user.name=t "$@"; }
sync_origin() {   # Populate the fixture refs without executing git push.
  local origin
  origin=$(g -C "$1" remote get-url origin) || return
  g -C "$origin" fetch -q "$1" +refs/heads/main:refs/heads/main &&
    g -C "$1" fetch -q origin
}
repo() {   # a repo whose main matches a bare origin; prints its path
  local r o; r=$(mktemp -d "$T/r.XXXXXX"); o=$(mktemp -d "$T/o.XXXXXX")
  {
    git init -q --bare "$o"; git init -q -b main "$r"
    printf 'a\n' > "$r/a.txt"; g -C "$r" add a.txt; g -C "$r" commit -q -m a
    g -C "$r" remote add origin "$o"; sync_origin "$r"
  } >/dev/null 2>&1
  printf '%s' "$r"
}
edit() { printf '%s\n' "${3:-b}" >> "$1/${2:-a.txt}"; }
commit() { g -C "$1" add -A >/dev/null; g -C "$1" commit -q -m "${2:-c}" >/dev/null; }
push_rc() {   # $1 cwd, $2 command
  jq -nc --arg c "$2" --arg d "$1" '{tool_input:{command:$c},cwd:$d,transcript_path:""}' \
    | HOME="$HOME" bash "$SCRIPT" >/dev/null 2>&1; echo $?
}
pcheck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: got rc=$2 want rc=$3"; fi; }

# Core flow.
r=$(repo); edit "$r"; commit "$r"
pcheck test_push_unreviewed_commit_blocked            "$(push_rc "$r" 'git push origin main')" 2
pcheck test_push_dry_run_allowed                      "$(push_rc "$r" 'git push --dry-run origin main')" 0
pcheck test_push_dry_run_short_allowed                "$(push_rc "$r" 'git push -n')" 0
pcheck test_push_skip_prefix_allowed                  "$(push_rc "$r" 'CLAUDE_SKIP_SIMPLIFY=1 git push origin x')" 0
"$MARK" mark "$r" >/dev/null
pcheck test_push_reviewed_commit_allowed              "$(push_rc "$r" 'git push')" 0

r=$(repo); edit "$r"; "$MARK" mark "$r" >/dev/null; commit "$r"
pcheck test_push_review_then_commit_allowed           "$(push_rc "$r" 'git push')" 0
edit "$r" a.txt c; commit "$r"
pcheck test_push_edit_after_review_blocked            "$(push_rc "$r" 'git push')" 2

r=$(repo); pcheck test_push_nothing_unpushed_allowed  "$(push_rc "$r" 'git push')" 0

# Finding 2: untracked files the push does not carry never block it.
r=$(repo); printf 'junk\n' > "$r/scratch.log"; edit "$r"; commit "$r" >/dev/null
g -C "$r" rm -q --cached scratch.log >/dev/null; g -C "$r" commit -q --amend -m c >/dev/null; printf 'more\n' >> "$r/scratch.log"
"$MARK" mark "$r" >/dev/null
pcheck test_push_untracked_noise_does_not_block       "$(push_rc "$r" 'git push')" 0

# Finding 3: a large untracked file is never hashed into .git/objects.
r=$(repo); edit "$r"; head -c 6000000 /dev/zero > "$r/big.bin"; before=$(find "$r/.git/objects" -type f | wc -l)
"$MARK" mark "$r" >/dev/null; after=$(find "$r/.git/objects" -type f | wc -l)
pcheck test_mark_writes_no_objects                    "$((after - before))" 0

# Finding 7: a partial commit pushes only reviewed content; an unreviewed new file blocks.
r=$(repo); edit "$r"; printf 'n\n' > "$r/new.txt"; "$MARK" mark "$r" >/dev/null
g -C "$r" commit -q -m partial -- a.txt >/dev/null
pcheck test_push_partial_commit_of_reviewed_allowed   "$(push_rc "$r" 'git push')" 0
r=$(repo); "$MARK" mark "$r" >/dev/null; printf 'n\n' > "$r/new.txt"; commit "$r"
pcheck test_push_new_unreviewed_file_blocked          "$(push_rc "$r" 'git push')" 2

# Commit and push in one command.
r=$(repo); edit "$r"; "$MARK" mark "$r" >/dev/null
pcheck test_commit_and_push_reviewed_allowed          "$(push_rc "$r" 'git commit -am x && git push')" 0
r=$(repo); "$MARK" mark "$r" >/dev/null; edit "$r"
pcheck test_commit_and_push_unreviewed_blocked        "$(push_rc "$r" 'git commit -am x && git push')" 2

# Finding 1: forms the parser cannot follow fail closed.
r=$(repo); edit "$r"; commit "$r"; o=$(mktemp -d "$T/x.XXXXXX")
pcheck test_cd_literal_then_push_blocked              "$(push_rc "$o" "cd $r && git push")" 2
pcheck test_cd_variable_then_push_blocked             "$(push_rc "$o" 'cd $U && git push')" 2
pcheck test_subshell_push_blocked                     "$(push_rc "$r" '(git push)')" 2
pcheck test_bash_c_push_blocked                       "$(push_rc "$r" "bash -c 'git push'")" 2
pcheck test_dash_c_tilde_unreviewed_blocked           "$(push_rc "$o" "git -C ~/../../${r#/} push")" 2
pcheck test_dash_c_variable_blocked                   "$(push_rc "$o" 'git -C $HOME/x push')" 2
pcheck test_dash_c_quoted_unreviewed_blocked          "$(push_rc "$o" "git -C \"$r\" push")" 2
pcheck test_git_dir_env_blocked                       "$(push_rc "$o" "GIT_DIR=$r/.git git push")" 2
pcheck test_git_dir_flag_blocked                      "$(push_rc "$o" "git --git-dir=$r/.git push")" 2
"$MARK" mark "$r" >/dev/null
b=$(repo); edit "$b"; commit "$b"   # unreviewed; $r is reviewed from here on
pcheck test_dash_c_braced_var_blocked                 "$(push_rc "$r" 'git -C "${U}" push')" 2
pcheck test_dash_c_braced_default_var_blocked         "$(push_rc "$r" "git -C \${U:-$b} push")" 2
# A leading literal assignment resolves; every other spelling of the variable fails closed.
pcheck test_leading_var_dash_c_reviewed_allowed       "$(push_rc "$o" "W=$r; git -C \$W push")" 0
pcheck test_leading_var_dash_c_unreviewed_blocked     "$(push_rc "$o" "W=$b; git -C \$W push")" 2
pcheck test_leading_var_cd_reviewed_allowed           "$(push_rc "$o" "W=$r; cd \$W && git push")" 0
pcheck test_leading_var_cd_unreviewed_blocked         "$(push_rc "$o" "W=$b; cd \$W && git push")" 2
pcheck test_leading_var_chain_reviewed_allowed        "$(push_rc "$o" "S=${r%/*}; W=\$S/${r##*/}; git -C \$W push")" 0
pcheck test_leading_var_quoted_braced_allowed         "$(push_rc "$o" "W=\"$r\" && git -C \"\${W}\" push")" 0
pcheck test_leading_var_export_blocked                "$(push_rc "$o" "export W=$r; git -C \$W push")" 2
pcheck test_leading_var_reassigned_blocked            "$(push_rc "$o" "W=$r; W=$b; git -C \$W push")" 2
pcheck test_leading_var_reassigned_dynamic_blocked    "$(push_rc "$o" "W=$r; W=\$(pwd); git -C \$W push")" 2
pcheck test_leading_var_for_loop_blocked              "$(push_rc "$o" "W=$r; for W in $b; do :; done; git -C \$W push")" 2
pcheck test_leading_var_read_blocked                  "$(push_rc "$o" "W=$r; IFS= read -r W < /dev/null; git -C \$W push")" 2
pcheck test_leading_var_printf_v_blocked              "$(push_rc "$o" "W=$r; printf -v W %s $b; git -C \$W push")" 2
pcheck test_leading_var_unset_blocked                 "$(push_rc "$o" "W=$r; unset W; git -C \$W push")" 2
pcheck test_var_after_command_blocked                 "$(push_rc "$o" "true; W=$r; git -C \$W push")" 2
pcheck test_var_conditional_blocked                   "$(push_rc "$o" "false || W=$r; git -C \$W push")" 2
pcheck test_var_in_pipe_blocked                       "$(push_rc "$o" "W=$r | true; git -C \$W push")" 2
pcheck test_var_in_background_blocked                 "$(push_rc "$o" "W=$r & git -C \$W push")" 2
pcheck test_var_in_subshell_blocked                   "$(push_rc "$o" "(W=$r); git -C \$W push")" 2
pcheck test_var_in_if_blocked                         "$(push_rc "$o" "if true; then W=$r; fi; git -C \$W push")" 2
pcheck test_var_env_prefix_blocked                    "$(push_rc "$o" "W=$r git -C \$W push")" 2
pcheck test_var_relative_value_blocked                "$(push_rc "${r%/*}" "W=${r##*/}; git -C \$W push")" 2
pcheck test_var_with_tail_dynamic_blocked             "$(push_rc "$o" "W=$r\$X; git -C \$W push")" 2
pcheck test_var_default_form_blocked                  "$(push_rc "$o" "W=$r; git -C \${W:-$b} push")" 2
pcheck test_var_quoted_space_blocked                  "$(push_rc "$o" "W=\"$r push\"; git -C \$W")" 2
pcheck test_var_ifs_anywhere_blocked                  "$(push_rc "$o" "W=$r; IFS=/; git -C \$W push")" 2
pcheck test_var_prefix_name_not_matched_blocked       "$(push_rc "$o" "W=$r; git -C \$WX push")" 2
pcheck test_group_push_reviewed_allowed               "$(push_rc "$o" "{ git -C $r push; }")" 0
pcheck test_group_cd_unreviewed_blocked               "$(push_rc "$r" "{ cd $b; git push; }")" 2
pcheck test_group_cd_variable_blocked                 "$(push_rc "$r" '{ cd $X; git push; }')" 2
pcheck test_then_cd_blocked                           "$(push_rc "$r" "if true; then cd $b; fi; git push")" 2
pcheck test_cd_inside_if_block_blocked                "$(push_rc "$b" "if false; then echo a; cd $r; fi; git push")" 2
pcheck test_builtin_cd_unreviewed_blocked             "$(push_rc "$r" "builtin cd $b && git push")" 2
pcheck test_builtin_cd_reviewed_allowed               "$(push_rc "$o" "builtin cd $r && git push")" 0
pcheck test_push_inside_loop_blocked                  "$(push_rc "$r" 'for i in 1 2; do git push; done')" 2
pcheck test_push_in_function_blocked                  "$(push_rc "$r" 'f() { git push; }; f')" 2
pcheck test_push_inside_if_reviewed_allowed           "$(push_rc "$r" 'if git diff --quiet; then git push; fi')" 0
pcheck test_loop_before_push_reviewed_allowed         "$(push_rc "$r" 'for f in a b; do echo $f; done; git push')" 0
pcheck test_quoted_subcommand_blocked                "$(push_rc "$b" 'git "push"')" 2
pcheck test_dash_c_quoted_space_var_blocked           "$(push_rc "$b" 'git -C "${W:-a b}" push')" 2
pcheck test_ifs_split_push_blocked                    "$(push_rc "$r" "W=$b:push; IFS=:; git -C \$W")" 2
pcheck test_dynamic_command_word_push_blocked         "$(push_rc "$b" 'G=git; P=push; $G $P')" 2
pcheck test_dynamic_word_then_plain_push_allowed      "$(push_rc "$r" '$EDITOR x; git push')" 0
pcheck test_push_in_substitution_of_git_blocked       "$(push_rc "$b" 'git status $(git push)')" 2
pcheck test_bash_c_cd_then_push_blocked               "$(push_rc "$r" "bash -c 'cd $b; git push'")" 2
pcheck test_multiline_subshell_cd_blocked             "$(push_rc "$b" "(
cd $r;
); git push")" 2
pcheck test_eval_cd_blocked                           "$(push_rc "$r" "eval \"cd $b\"; git push")" 2
pcheck test_heredoc_wrapper_option_shell_blocked      "$(push_rc "$b" "command -p bash <<'EOF'
git push
EOF")" 2
pcheck test_apostrophe_in_double_quotes_allowed     "$(push_rc "$r" 'echo "remote'"'"'s tree"; git push')" 0
pcheck test_escaped_quote_then_push_allowed           "$(push_rc "$r" 'echo \'"'"'x; git push')" 0
pcheck test_stash_push_allowed                        "$(push_rc "$b" 'git stash push')" 0
pcheck test_push_word_in_git_argument_allowed         "$(push_rc "$b" 'git log --grep push')" 0
pcheck test_cd_literal_reviewed_allowed               "$(push_rc "$o" "cd $r && git push")" 0
pcheck test_dash_c_absolute_reviewed_allowed          "$(push_rc "$o" "git -C $r push")" 0

# Finding 4: the pushed source ref is checked, not HEAD.
r=$(repo); g -C "$r" checkout -q -b feat; edit "$r"; commit "$r"; g -C "$r" checkout -q main
pcheck test_push_named_unreviewed_branch_blocked      "$(push_rc "$r" 'git push origin feat')" 2
pcheck test_push_refspec_unreviewed_blocked           "$(push_rc "$r" 'git push origin +feat:main')" 2
pcheck test_push_all_blocked                          "$(push_rc "$r" 'git push --all')" 2
pcheck test_checkout_then_push_blocked                "$(push_rc "$r" 'git checkout feat && git push')" 2
pcheck test_push_delete_allowed                       "$(push_rc "$r" 'git push origin --delete feat')" 0
pcheck test_push_delete_refspec_allowed               "$(push_rc "$r" 'git push origin :feat')" 0

# Finding 6: --dry-run counts only inside the push segment.
r=$(repo); edit "$r"
pcheck test_dry_run_in_commit_message_blocked         "$(push_rc "$r" "git commit -am 'add --dry-run flag' && git push")" 2

# Finding 5: an error inside the guard blocks instead of letting the push through.
r=$(mktemp -d "$T/empty.XXXXXX"); git init -q "$r"
pcheck test_push_repo_without_commits_handled         "$(push_rc "$r" 'git push')" 0
r=$(repo); edit "$r"; "$MARK" mark "$r" >/dev/null; chmod 000 "$r/a.txt"
pcheck test_commit_and_push_unreadable_file_blocked   "$(push_rc "$r" 'git commit -am x && git push')" 2
chmod 644 "$r/a.txt"

# Finding 8: concurrent marks keep every record.
r=$(repo); for i in $(seq 1 8); do printf '%s\n' "$i" > "$r/f$i.txt"; done
for i in $(seq 1 8); do "$MARK" mark "$r" >/dev/null & done; wait
commit "$r"
pcheck test_concurrent_marks_keep_records             "$(push_rc "$r" 'git push')" 0

# Re-review round 2.
r=$(repo); edit "$r"; commit "$r"
pcheck test_two_pushes_with_dry_run_blocked           "$(push_rc "$r" 'git push origin main && git push --dry-run origin main')" 2
pcheck test_two_pushes_with_delete_blocked            "$(push_rc "$r" 'git push origin main; git push origin :old')" 2
pcheck test_stash_push_not_a_push_allowed             "$(push_rc "$r" 'git stash push -m wip')" 0
pcheck test_commit_message_naming_push_allowed        "$(push_rc "$r" "git commit -am 'fix push guard'")" 0
pcheck test_config_push_default_allowed               "$(push_rc "$r" 'git config push.default current')" 0
pcheck test_echo_git_push_text_blocked                "$(push_rc "$r" "echo 'run git push later'")" 2
pcheck test_subshell_cd_then_push_blocked             "$(push_rc "$T" "(cd $r && git status) ; git push origin main")" 2
for s in stash pull rebase reset merge; do
  pcheck "test_${s}_before_push_blocked"              "$(push_rc "$r" "git $s && git push")" 2
done

r=$(repo); g -C "$r" checkout -q -b side; edit "$r" s.txt s; commit "$r"; g -C "$r" checkout -q main
g -C "$r" merge -q --no-ff -m m side >/dev/null; "$MARK" mark "$r" >/dev/null
pcheck test_reviewed_merge_allowed                    "$(push_rc "$r" 'git push origin main')" 0
edit "$r" a.txt evil; g -C "$r" add a.txt; g -C "$r" commit -q --amend --no-edit >/dev/null
pcheck test_merge_amended_with_unreviewed_edit_blocked "$(push_rc "$r" 'git push origin main')" 2

r=$(repo); s=$(repo); g -C "$s" commit -q --allow-empty -m s2 >/dev/null
g -C "$r" -c protocol.file.allow=always submodule add -q "$s" sub >/dev/null 2>&1; commit "$r"
"$MARK" mark "$r" >/dev/null
pcheck test_reviewed_submodule_bump_allowed           "$(push_rc "$r" 'git push origin main')" 0

r=$(repo); edit "$r"; "$MARK" mark "$r" >/dev/null; head -c 6000000 /dev/zero > "$r/big.js"
pcheck test_add_all_with_oversize_untracked_blocked   "$(push_rc "$r" 'git add -A && git commit -m x && git push origin main')" 2
pcheck test_commit_am_ignores_oversize_untracked      "$(push_rc "$r" 'git commit -am x && git push origin main')" 0

r=$(repo); head -c 6000000 /dev/zero > "$r/data.bin"; commit "$r"; sync_origin "$r" >/dev/null 2>&1
printf 'x' >> "$r/data.bin"; "$MARK" mark "$r" >/dev/null; commit "$r"
pcheck test_tracked_large_file_edit_reviewed_allowed  "$(push_rc "$r" 'git push origin main')" 0

r=$(repo); for i in $(seq 1 12); do printf '%s\n' "$i" > "$r/c$i.txt"; done
for i in $(seq 1 12); do "$MARK" mark "$r" >/dev/null & done; wait; commit "$r"
pcheck test_concurrent_marks_twelve_keep_records      "$(push_rc "$r" 'git push origin main')" 0

pcheck test_push_outside_git_repo_denied              "$(push_rc "$T" 'git push')" 2
pcheck test_non_push_git_allowed                      "$(push_rc "$T" 'git status && git log')" 0

# rm forms where rm is not the first word of its segment.
check test_rm_xargs_null_input_blocked        'find . -print0 | xargs -0 rm -rf'           2
check test_rm_xargs_replace_blocked           'xargs -I{} rm -rf {}'                       2
check test_rm_absolute_binary_blocked         '/bin/rm -rf $x'                             2
check test_rm_backslash_alias_bypass_blocked  '\rm -rf $x'                                 2
check test_rm_sudo_with_option_blocked        'sudo -u root rm -rf $x'                     2
check test_rm_nice_with_option_blocked        'nice -n 5 rm -rf $x'                        2
check test_rm_env_with_option_blocked         'env -i rm -rf $x'                           2
check test_rm_after_background_amp_blocked    'true & rm -rf $x'                           2
check test_rm_in_for_loop_blocked             'for d in a b; do rm -rf $d; done'           2
check test_rm_in_if_then_blocked              'if true; then rm -rf $x; fi'                2
check test_rm_in_subshell_blocked             '(rm -rf $x)'                                2
check test_rm_in_group_blocked                '{ rm -rf $x; }'                             2
check test_rm_backtick_substitution_blocked   'rm -rf `mktemp -d`'                         2
check test_rm_find_exec_blocked               'find /tmp -name "b*" -exec rm -rf {} +'     2
check test_git_rm_recursive_variable_allowed  'git rm -r --cached $x'                      0
check test_env_printf_rm_text_allowed         'env printf "%s\n" rm -rf "$x"'              0
check test_sudo_echo_rm_text_allowed          'sudo -u root echo rm -rf $x'                0
check test_rm_xargs_replace_spaced_blocked    'xargs -I {} rm -rf {}'                      2
check test_rm_find_exec_spaced_braces_blocked 'find . -name x -exec rm -rf {} \;'          2
check test_rm_after_nohup_blocked             'nohup rm -rf $x'                            2
check test_rm_after_sudo_flag_without_value_blocked 'sudo -n rm -rf "$x"'                  2
check test_rm_after_command_p_blocked         'command -p rm -r "$x"'                      2
check test_rm_after_timeout_duration_blocked  'timeout 5 rm -rf $x'                        2
check test_rm_after_timeout_signal_option_blocked 'timeout -s KILL 5 rm -rf $x'            2
check test_rm_after_sudo_user_value_blocked   'sudo -u root rm -rf $x'                     2
check test_rm_after_timeout_variable_duration_blocked 'timeout "$limit" rm -r "$x"'       2
check test_rm_after_timeout_fraction_duration_blocked 'timeout .5 rm -r "$x"'             2
check test_rm_after_chrt_variable_priority_blocked 'chrt "$p" rm -r "$x"'                  2
check test_rm_after_doas_user_value_blocked   'doas -u root rm -r "$x"'                    2
check test_rm_after_timeout_long_option_value_blocked 'timeout --kill-after 5 10 rm -r "$x"' 2
check test_rm_after_nice_value_blocked        'nice -n 5 rm -r $x'                         2
check test_nice_value_named_rm_not_command_allowed 'nice -n 5 ls rm -r $x'                 0
check test_rm_in_if_condition_blocked         'if rm -rf $x; then :; fi'                   2
check test_rm_in_while_condition_blocked      'while rm -rf $x; do :; done'                2
check test_rm_in_command_substitution_blocked 'echo $(rm -rf $x)'                          2
check test_rm_in_backtick_substitution_blocked 'echo `rm -rf $x`'                          2
check test_git_rm_in_loop_allowed             'for d in a b; do git rm -r $d; done'        0
check test_xargs_git_rm_allowed               'git ls-files | xargs git rm -r --cached'    0
check test_aws_s3_rm_allowed                  'env AWS_PROFILE=x aws s3 rm --recursive s3://$B/old/' 0
check test_redirect_amp_not_rm_allowed        'ls 2>&1 | grep rm'                          0

# A push whose source ref the guard cannot resolve, or whose repo it cannot find, is blocked.
r=$(repo); "$MARK" mark "$r" >/dev/null; g -C "$r" switch -q -c feat; edit "$r"; commit "$r"; g -C "$r" switch -q main
pcheck test_push_double_quoted_ref_blocked            "$(push_rc "$r" 'git push origin "feat"')" 2
pcheck test_push_single_quoted_ref_blocked            "$(push_rc "$r" "git push origin 'feat'")" 2
pcheck test_push_variable_ref_blocked                 "$(push_rc "$r" 'git push origin $BR')" 2
pcheck test_push_upstream_shorthand_blocked           "$(push_rc "$r" 'git push origin HEAD@{u}')" 2
pcheck test_push_git_dir_separate_value_blocked       "$(push_rc "$r" "git --git-dir $r/.git push origin feat")" 2
pcheck test_push_quoted_reviewed_ref_allowed          "$(push_rc "$r" 'git push origin "main"')" 0
pcheck test_push_spaced_redirect_allowed              "$(push_rc "$r" "git push origin main > $T/out.log")" 0
pcheck test_push_stderr_append_redirect_allowed       "$(push_rc "$r" "git push origin main 2>> $T/err.log")" 0
pcheck test_push_escaped_gt_in_ref_not_redirect_blocked "$(push_rc "$r" 'git push origin HEAD:topic\> feat')" 2
pcheck test_push_joined_redirect_allowed              "$(push_rc "$r" "git push origin main >$T/out.log")" 0
pcheck test_push_joined_redirect_then_feat_blocked    "$(push_rc "$r" "git push origin main 2>$T/err.log feat")" 2
g -C "$r" tag v1.2.3 main
pcheck test_push_tag_shorthand_allowed                "$(push_rc "$r" 'git push origin tag v1.2.3')" 0
g -C "$r" tag v9 feat
pcheck test_push_tag_shorthand_unreviewed_blocked     "$(push_rc "$r" 'git push origin tag v9')" 2
r=$(repo); edit "$r"; commit "$r"
pcheck test_push_after_pushd_blocked                  "$(push_rc "$T" "pushd $r && git push")" 2
pcheck test_push_after_cd_double_dash_blocked         "$(push_rc "$T" "cd -- $r && git push")" 2
pcheck test_push_after_cd_to_missing_dir_blocked      "$(push_rc "$T" "cd $T/no-such-dir && git push")" 2

r=$(repo); edit "$r"; commit "$r"
pcheck test_push_after_background_amp_blocked         "$(push_rc "$r" 'git status & git push origin HEAD')" 2
pcheck test_push_comment_dry_run_text_blocked         "$(push_rc "$r" 'git push origin HEAD # --dry-run')" 2
r=$(repo); g -C "$r" switch -q -c feature; edit "$r"; commit "$r"; g -C "$r" switch -q main   # HEAD clean, feature unreviewed
pcheck test_push_head_clean_allowed                   "$(push_rc "$r" 'git push')" 0
pcheck test_push_repo_option_positional_wins_blocked  "$(push_rc "$r" 'git push --repo=ignored origin feature')" 2
pcheck test_push_quoted_full_refspec_allowed          "$(push_rc "$r" 'git push origin "HEAD:refs/heads/topic"')" 0
pcheck test_push_quoted_forced_refspec_allowed        "$(push_rc "$r" "git push origin '+HEAD:refs/heads/topic'")" 0
pcheck test_push_quoted_unreviewed_refspec_blocked    "$(push_rc "$r" 'git push origin "feature:main"')" 2
g -C "$r" config remote.pushDefault probe; g -C "$r" config remote.probe.push feature
pcheck test_push_push_default_remote_config_blocked   "$(push_rc "$r" 'git push')" 2
g -C "$r" config --unset remote.pushDefault; g -C "$r" config branch.main.pushRemote probe
pcheck test_push_branch_push_remote_config_blocked    "$(push_rc "$r" 'git push')" 2
g -C "$r" config --unset branch.main.pushRemote; g -C "$r" config --unset remote.probe.push
pcheck test_push_matching_default_option_blocked      "$(push_rc "$r" 'git -c push.default=matching push')" 2
g -C "$r" config push.default matching
pcheck test_push_matching_config_blocked              "$(push_rc "$r" 'git push')" 2

# review-mark.sh: a failing git command blocks instead of reading as "nothing to review".
r=$(repo); edit "$r"; commit "$r"; mkdir -p "$r/.git/refs/remotes/origin"
printf '%040d\n' 1 > "$r/.git/refs/remotes/origin/bad"
pcheck test_push_with_corrupt_remote_ref_blocked      "$(push_rc "$r" 'git push')" 2
"$MARK" mark "$r" >/dev/null 2>&1
"$MARK" check-worktree "$r" >/dev/null 2>&1
pcheck test_check_worktree_with_corrupt_remote_ref_errors "$?" 2
r=$(repo); printf 'f\n' > "$r/becomesdir"; commit "$r"; sync_origin "$r" >/dev/null 2>&1
g -C "$r" rm -q becomesdir; mkdir "$r/becomesdir"; printf 'n\n' > "$r/becomesdir/new"; commit "$r"; "$MARK" mark "$r" >/dev/null
pcheck test_push_file_replaced_by_dir_reviewed_allowed "$(push_rc "$r" 'git push origin main')" 0
r=$(repo); printf 'x\n' > "$r/tab"$'\t'"name"; "$MARK" mark "$r" >/dev/null 2>&1
pcheck test_mark_failure_leaves_no_temp_file          "$(find "$r/.git" -maxdepth 1 -name 'claude-reviewed-content.*' ! -name '*.lock' | wc -l)" 0

# A quoted-delimiter heredoc feeds data, not commands, to a consumer that is no shell:
# its body never pushes. The repo holds an unreviewed commit, so a push it misreads is rc=2.
r=$(repo); edit "$r"; commit "$r"
pcheck test_cat_heredoc_body_mentions_git_push_allowed      "$(push_rc "$r" $'cat > /tmp/shim <<\'EOF\'\n# route git push origin to the clean URL\nEOF')" 0
pcheck test_python_heredoc_body_mentions_stash_push_allowed "$(push_rc "$r" $'python3 - <<\'EOF\'\nprint("then git stash push -u")\nEOF')" 0
pcheck test_dash_heredoc_body_mentions_git_push_allowed     "$(push_rc "$r" $'cat <<-"EOF"\n\tgit push origin main\n\tEOF')" 0
pcheck test_git_commit_heredoc_message_mentions_push_allowed "$(push_rc "$r" $'git commit -F - <<\'EOF\'\nfix: git push no longer races\nEOF')" 0
pcheck test_unquoted_heredoc_substitution_push_blocked      "$(push_rc "$r" $'cat <<EOF\n$(git push origin main)\nEOF')" 2
pcheck test_bash_heredoc_body_push_blocked                  "$(push_rc "$r" $'bash <<\'EOF\'\ngit push origin main\nEOF')" 2
pcheck test_push_after_data_heredoc_blocked                 "$(push_rc "$r" $'cat > /tmp/x <<\'EOF\'\nnotes\nEOF\ngit push origin main')" 2
# `git` inside a path (.github, /git/) is no git command.
pcheck test_github_path_then_push_word_allowed              "$(push_rc "$r" "grep -n if: .github/workflows/a.yml; sed -i 's/do not push before it/ok/' /tmp/notes.md")" 0
pcheck test_absolute_git_path_push_blocked                  "$(push_rc "$r" '/usr/bin/git push origin main')" 2

# Review cases 1-7: each command targets an unreviewed repository in Bash.
r=$(repo); edit "$r"; commit "$r"
pcheck test_push_array_reassignment_denied "$(push_rc "$r" "W=/tmp; W[0]=$r; git -C \$W push")" 2
pcheck test_push_append_reassignment_denied "$(push_rc "$r" "W=${r%/*}; W+=/${r##*/}; git -C \$W push")" 2
pcheck test_push_relative_reassignment_denied "$(push_rc "$r" 'W=/tmp; W=.; git -C $W push')" 2
pcheck test_push_quoted_export_denied "$(push_rc "$r" "W=/tmp; export \"W=$r\"; git -C \$W push")" 2
pcheck test_push_quoted_declare_denied "$(push_rc "$r" "W=/tmp; declare \"W=$r\"; git -C \$W push")" 2
pcheck test_push_read_array_denied "$(push_rc "$r" "W=/tmp; read -r \"W[0]\" <<< $r; git -C \$W push")" 2
pcheck test_push_printf_array_denied "$(push_rc "$r" "W=/tmp; printf -v W[0] %s $r; git -C \$W push")" 2
pcheck test_push_read_attached_redirection_denied "$(push_rc "$r" "W=/tmp; read W<<< $r; git -C \$W push")" 2
pcheck test_push_escaped_read_denied "$(push_rc "$r" "W=/tmp; \\read W <<< $r; git -C \$W push")" 2
pcheck test_push_quoted_read_denied "$(push_rc "$r" "W=/tmp; \"read\" W <<< $r; git -C \$W push")" 2
pcheck test_push_background_and_list_denied "$(W="$r" push_rc "$r" 'W=/tmp && : & git -C "$W" push')" 2
pcheck test_push_comment_cd_denied "$(push_rc "$r" $'W=/tmp; # comment ; cd $W\ngit push')" 2
pcheck test_push_unquoted_heredoc_cd_denied "$(push_rc "$r" $'W=/tmp; cat <<EOF\ncd $W\nEOF\ngit push')" 2
pcheck test_push_alias_reassignment_denied "$(push_rc "$r" "W=/tmp; shopt -s expand_aliases
alias change='W=$r'
change
git -C \$W push")" 2
pcheck test_push_special_underscore_denied "$(push_rc "$r" "_=/tmp; : $r; git -C \$_ push")" 2
pcheck test_push_special_pwd_denied "$(push_rc "$r" "PWD=/tmp; cd $r; git -C \$PWD push")" 2
pcheck test_push_special_oldpwd_denied "$(push_rc "$r" 'OLDPWD=/tmp; cd /; git -C $OLDPWD push')" 2
# The literal directory named $W contains an actual unreviewed repository.
g clone -q "$r" "$r/\$W"; edit "$r/\$W"; commit "$r/\$W"
pcheck test_push_single_quoted_path_denied "$(push_rc "$r" "W=/tmp; git -C '\$W' push")" 2
pcheck test_push_single_quoted_assignment_denied "$(push_rc "$r" "W=/tmp; W='\$W'; git -C \$W push")" 2

# Inject dependency failure and nounset failure through the actual input reader.
test_guard_internal_error_denied() {
  local body=$1 result rc input
  input=$(jq -nc --arg cwd "${3:-/tmp}" '{tool_input:{command:"git push"},cwd:$cwd}')
  result=$(bash -c "$body; source \"\$1\"" guard-test "$SCRIPT" 2>&1 <<< "$input"); rc=$?
  pcheck "test_guard_${2}_denied" "$rc" 2
  if [[ "$result" == *'Blocked: push guard internal error; command denied.'* || "$result" == *'Blocked: the push guard failed at line '* ]]; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL test_guard_${2}_reason: $result"
  fi
}
test_guard_internal_error_denied 'cat() { return 73; }' dependency_error
test_guard_internal_error_denied 'cat() { local missing; unset missing; printf "%s" "$missing"; }' unbound_variable
test_guard_internal_error_denied 'cat() { return 2; }' dependency_exit_two
test_guard_internal_error_denied 'awk() { return 73; }' segment_producer_error
test_guard_internal_error_denied 'sed() { return 73; }' segment_filter_error
test_guard_internal_error_denied 'readonly special_var' assignment_error
test_guard_internal_error_denied 'readonly known_vars' array_initialization_error
test_guard_internal_error_denied 'jq() { if [[ "$*" == *run_in_background* ]]; then return 73; fi; command jq "$@"; }' background_query_error
test_guard_internal_error_denied 'git() { return 73; }' git_lookup_error
test_guard_internal_error_denied 'git() { if [[ "$*" == *config* ]]; then return 73; fi; command git "$@"; }' git_config_error "$r"
test_guard_internal_error_denied 'git() { if [[ "$*" == *"HEAD^{commit}"* ]]; then return 73; fi; command git "$@"; }' git_head_error "$r"
g -C "$r" config remote.origin.push ''
pcheck test_push_empty_remote_refspec_denied "$(push_rc "$r" 'git push')" 2

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
