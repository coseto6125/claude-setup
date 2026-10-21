# Tests for pr-finalize.sh. Run: bash ~/.claude/skill_script/tests/test_pr_finalize.sh
# A fake `gh` on PATH stands in for GitHub; a bare repo stands in for origin.
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pr-finalize.sh"
FAILS=0

setup() {  # $1 = PR state; leaves cwd at the main clone, branch feat/x in a worktree
    T=$(mktemp -d); export T
    git init -q --bare "$T/origin.git"
    git clone -q "$T/origin.git" "$T/main" 2>/dev/null
    cd "$T/main"
    git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    git push -q origin HEAD:main 2>/dev/null
    git worktree add -q -b feat/x "$T/wt" 2>/dev/null
    git -C "$T/wt" -c user.name=t -c user.email=t@t commit -q --allow-empty -m pushed
    git -C "$T/wt" push -q origin feat/x 2>/dev/null
    PR_OID=$(git -C "$T/wt" rev-parse HEAD)
    mkdir -p "$T/bin"
    cat > "$T/bin/gh" <<GH
#!/usr/bin/env bash
case "\$*" in
  *number*) echo 7 ;;
  *) echo "feat/x https://example.test/pr/7 $1 $PR_OID" ;;
esac
GH
    chmod +x "$T/bin/gh"
    export PATH="$T/bin:$PATH"
}
check() {  # $1 = name, $2 = expected exit, $3 = expect branch kept (1) or gone (0)
    local rc=$4 kept=0
    git -C "$T/main" show-ref --verify --quiet refs/heads/feat/x && kept=1
    if [[ $rc -eq $2 && $kept -eq $3 ]]; then echo "ok   $1"; else echo "FAIL $1 (exit $rc, branch kept=$kept)"; FAILS=$((FAILS+1)); fi
    case "$T" in "${TMPDIR:-/tmp}"/tmp.?*) rm -rf -- "$T" ;; esac
}

test_pr_finalize_unpushed_commit_open_pr_refuses() {
    setup OPEN
    git -C "$T/wt" -c user.name=t -c user.email=t@t commit -q --allow-empty -m unpushed
    bash "$SCRIPT" 7 </dev/null >/dev/null 2>&1; check "${FUNCNAME[0]}" 1 1 $?
}
test_pr_finalize_unpushed_commit_merged_pr_refuses() {
    setup MERGED
    git -C "$T/wt" -c user.name=t -c user.email=t@t commit -q --allow-empty -m unpushed
    git -C "$T/main" push -q origin --delete feat/x 2>/dev/null
    bash "$SCRIPT" 7 </dev/null >/dev/null 2>&1; check "${FUNCNAME[0]}" 1 1 $?
}
test_pr_finalize_fully_pushed_open_pr_deletes_branch() {
    setup OPEN
    bash "$SCRIPT" 7 </dev/null >/dev/null 2>&1; check "${FUNCNAME[0]}" 0 0 $?
}
test_pr_finalize_merged_remote_deleted_deletes_branch() {
    setup MERGED
    git -C "$T/main" push -q origin --delete feat/x 2>/dev/null
    bash "$SCRIPT" 7 </dev/null >/dev/null 2>&1; check "${FUNCNAME[0]}" 0 0 $?
}
test_pr_finalize_pr_head_unfetchable_refuses() {
    setup MERGED
    git -C "$T/main" push -q origin --delete feat/x 2>/dev/null
    sed -i "s/$PR_OID/0123456789abcdef0123456789abcdef01234567/" "$T/bin/gh"
    bash "$SCRIPT" 7 </dev/null >/dev/null 2>&1; check "${FUNCNAME[0]}" 1 1 $?
}
test_pr_finalize_dirty_worktree_no_tty_refuses_and_keeps_links() {
    setup OPEN
    mkdir "$T/env"; ln -s "$T/env" "$T/wt/.venv"; printf 'x\n' > "$T/wt/untracked.txt"
    local out rc
    out=$(bash "$SCRIPT" 7 </dev/null 2>&1); rc=$?
    if [[ -L "$T/wt/.venv" && "$out" == *dirty* ]]; then check "${FUNCNAME[0]}" 1 1 $rc
    else echo "FAIL ${FUNCNAME[0]} (.venv link kept: $([[ -L $T/wt/.venv ]] && echo y || echo n); output: $out)"; FAILS=$((FAILS+1)); fi
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do "$t"; done
echo "$FAILS failed"
(( FAILS == 0 ))
