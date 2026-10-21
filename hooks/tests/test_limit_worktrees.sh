# Run: bash ~/.claude/hooks/tests/test_limit_worktrees.sh
# Runs a copy of the hook with THRESHOLD=1, inside a throwaway repo that has one worktree (its main).
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)/limit-worktrees.sh"
T=$(mktemp -d "$HOME/.cache/limit-wt-test.XXXXXX")
sed 's/^THRESHOLD=200$/THRESHOLD=1/' "$SRC" > "$T/hook.sh"
git init -q "$T/repo"
pass=0; fail=0
run() { (cd "$T/repo" && jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$T/hook.sh" >/dev/null 2>&1; echo $?); }
check() { if [ "$(run "$2")" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: [$2] want rc=$3"; fi; }

# Over the limit: blocked (rc=2).
check test_worktree_add_blocked              'git worktree add /y'                                    2
check test_git_dash_c_dir_blocked            "git -C $T/repo worktree add /y -b z"                    2
check test_git_config_and_dir_blocked        "git -c a=b -C $T/repo worktree add /y"                  2

# Bypass anywhere in the command, and other commands: allowed (rc=0).
check test_bypass_prefix_allowed             'CLAUDE_ALLOW_WORKTREE_ADD=1 git worktree add /y'        0
check test_bypass_after_cd_allowed           'cd /x && CLAUDE_ALLOW_WORKTREE_ADD=1 git -C /x worktree add /y' 0
check test_worktree_list_allowed             'git worktree list'                                      0
check test_worktree_remove_allowed           'git -C /x worktree remove /y'                           0
check test_echo_text_allowed                 'echo worktree add'                                      0
check test_commit_message_text_allowed      "git commit -m 'document worktree add usage'"            0

# git -C counts the worktrees of the target repo, not of the cwd.
git init -q "$T/small"
run_in() { (cd "$1" && jq -nc --arg c "$2" '{tool_input:{command:$c}}' | bash "$T/hook.sh" >/dev/null 2>&1; echo $?); }
sed 's/^THRESHOLD=200$/THRESHOLD=2/' "$SRC" > "$T/hook.sh"
git -C "$T/repo" commit -q --allow-empty -m a; git -C "$T/repo" worktree add -q "$T/wt2" 2>/dev/null
r=$(run_in "$T/small" "git -C $T/repo worktree add /y")
if [ "$r" = 2 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL test_git_dash_c_counts_target_repo_blocked: got rc=$r want rc=2"; fi
r=$(run_in "$T/small" "git --no-pager -C $T/repo worktree add /y")
if [ "$r" = 2 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL test_git_option_before_dash_c_counts_target_blocked: got rc=$r want rc=2"; fi
r=$(run_in "$T/small" "git -C \"$T/repo\" worktree add /y")
if [ "$r" = 2 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL test_git_dash_c_quoted_target_blocked: got rc=$r want rc=2"; fi

case "$T" in "$HOME"/.cache/limit-wt-test.?*) rm -rf -- "$T" ;; esac
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
