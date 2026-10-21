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

# Push guard: the review is bound to file content through review-mark.sh. Each
# case runs in a fresh repo with a bare remote; the hook reads the repo from cwd.
# The sibling review-mark.sh, so a mirror checkout tests its own copy, not the installed one.
export REVIEW_MARK; REVIEW_MARK="$(cd "$(dirname "$0")/../../skills/simplify" && pwd)/review-mark.sh"; MARK=$REVIEW_MARK
mkdir -p "$HOME/.cache"; T=$(mktemp -d "$HOME/.cache/guard-test.XXXXXX"); trap 'case "$T" in "$HOME"/.cache/guard-test.?*) rm -rf -- "$T" ;; esac' EXIT   # under $HOME so `~` paths resolve
g() { git -c user.email=t@t -c user.name=t "$@"; }
repo() {   # a repo whose main is pushed to a bare origin; prints its path
  local r o; r=$(mktemp -d "$T/r.XXXXXX"); o=$(mktemp -d "$T/o.XXXXXX")
  {
    git init -q --bare "$o"; git init -q -b main "$r"
    printf 'a\n' > "$r/a.txt"; g -C "$r" add a.txt; g -C "$r" commit -q -m a
    g -C "$r" remote add origin "$o"; g -C "$r" push -q origin main
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
pcheck test_dash_c_tilde_unreviewed_blocked           "$(push_rc "$o" "git -C ~${r#"$HOME"} push")" 2
pcheck test_dash_c_variable_blocked                   "$(push_rc "$o" 'git -C $HOME/x push')" 2
pcheck test_dash_c_quoted_unreviewed_blocked          "$(push_rc "$o" "git -C \"$r\" push")" 2
pcheck test_git_dir_env_blocked                       "$(push_rc "$o" "GIT_DIR=$r/.git git push")" 2
pcheck test_git_dir_flag_blocked                      "$(push_rc "$o" "git --git-dir=$r/.git push")" 2
"$MARK" mark "$r" >/dev/null
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

r=$(repo); head -c 6000000 /dev/zero > "$r/data.bin"; commit "$r"; g -C "$r" push -q origin main >/dev/null 2>&1
printf 'x' >> "$r/data.bin"; "$MARK" mark "$r" >/dev/null; commit "$r"
pcheck test_tracked_large_file_edit_reviewed_allowed  "$(push_rc "$r" 'git push origin main')" 0

r=$(repo); for i in $(seq 1 12); do printf '%s\n' "$i" > "$r/c$i.txt"; done
for i in $(seq 1 12); do "$MARK" mark "$r" >/dev/null & done; wait; commit "$r"
pcheck test_concurrent_marks_twelve_keep_records      "$(push_rc "$r" 'git push origin main')" 0

pcheck test_push_outside_git_repo_allowed             "$(push_rc "$T" 'git push')" 0
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
r=$(repo); printf 'f\n' > "$r/becomesdir"; commit "$r"; g -C "$r" push -q origin main >/dev/null 2>&1
g -C "$r" rm -q becomesdir; mkdir "$r/becomesdir"; printf 'n\n' > "$r/becomesdir/new"; commit "$r"; "$MARK" mark "$r" >/dev/null
pcheck test_push_file_replaced_by_dir_reviewed_allowed "$(push_rc "$r" 'git push origin main')" 0
r=$(repo); printf 'x\n' > "$r/tab"$'\t'"name"; "$MARK" mark "$r" >/dev/null 2>&1
pcheck test_mark_failure_leaves_no_temp_file          "$(find "$r/.git" -maxdepth 1 -name 'claude-reviewed-content.*' ! -name '*.lock' | wc -l)" 0

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
