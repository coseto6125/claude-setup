#!/usr/bin/env bash
#
# pr-finalize.sh — once a PR is pushed, clean up the local worktree + branch.
# Does NOT merge: merge is left to auto-merge / manual. The remote branch and
# PR stay; only the local worktree + local branch are removed (recoverable
# from the remote if needed).
#
# Usage: pr-finalize.sh [PR#]      # PR# omitted → auto-detect from cwd
#
# Exit: 0 ok · 1 user/state error · 2 bad arg

set -euo pipefail

PR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^#\s\?//'; exit 0 ;;
        [0-9]*)    PR="$1"; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

command -v gh  >/dev/null || { echo "missing gh CLI" >&2; exit 1; }
command -v git >/dev/null || { echo "missing git"   >&2; exit 1; }

[[ -n "$PR" ]] || PR=$(gh pr view --json number --jq .number 2>/dev/null) || {
    echo "no PR for current branch; pass PR# explicitly." >&2; exit 1; }

read -r HEAD_REF URL STATE HEAD_OID < <(gh pr view "$PR" --json headRefName,url,state,headRefOid --jq '"\(.headRefName) \(.url) \(.state) \(.headRefOid)"')
echo "→ cleaning up local worktree + branch for PR #$PR ($HEAD_REF, $STATE)"

# Refuse to drop local work that isn't on the remote yet — unless the PR is
# MERGED: auto-merge deletes the remote branch after merging, and the work is
# already safe in main, which is exactly the case this skill exists to clean.
if [[ "$STATE" != "MERGED" ]]; then
    git ls-remote --exit-code --heads origin "$HEAD_REF" >/dev/null 2>&1 || {
        echo "✗ remote branch origin/$HEAD_REF not found — push before finalizing." >&2; exit 1; }
fi

REPO_ROOT=$(git rev-parse --show-toplevel)

# Find the worktree on HEAD_REF: direct branch match, else upstream-tracking
# match (EnterWorktree renames the local branch, e.g. worktree-fix+x → fix/x).
# awk must consume ALL input (no early exit): under pipefail, awk exiting while
# git is still writing a long worktree list turns the pipeline into SIGPIPE 141.
WT_PATH=$(git -C "$REPO_ROOT" worktree list --porcelain | awk -v b="refs/heads/$HEAD_REF" '
    $1=="worktree"{p=$2} $1=="branch"&&$2==b&&!f{print p;f=1}')
WT_BRANCH="$HEAD_REF"
if [[ -z "$WT_PATH" ]]; then
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) wt="${line#worktree }" ;;
            "branch "*)
                lb="${line#branch refs/heads/}"
                [[ "$(git -C "$wt" config branch."$lb".merge 2>/dev/null)" == "refs/heads/$HEAD_REF" ]] \
                    && { WT_PATH="$wt"; WT_BRANCH="$lb"; break; } ;;
        esac
    done < <(git -C "$REPO_ROOT" worktree list --porcelain)
fi

# Refuse to delete commits the PR never received. HEAD_OID is the last push
# GitHub saw; refs/pull/N/head keeps it fetchable after auto-merge deletes the
# remote branch. Runs before the worktree removal, so a refusal leaves both.
if git show-ref --verify --quiet "refs/heads/$WT_BRANCH"; then
    git cat-file -e "$HEAD_OID^{commit}" 2>/dev/null \
        || git fetch -q origin "refs/pull/$PR/head" 2>/dev/null || true
    git cat-file -e "$HEAD_OID^{commit}" 2>/dev/null || {
        echo "✗ cannot fetch the PR head $HEAD_OID — kept worktree + branch." >&2; exit 1; }
    if [[ -n "$(git rev-list "$HEAD_OID..refs/heads/$WT_BRANCH")" ]]; then
        echo "✗ $WT_BRANCH has commits the PR does not have — push them first:" >&2
        git log --oneline "$HEAD_OID..refs/heads/$WT_BRANCH" >&2
        exit 1
    fi
fi

# Refuse if the caller's cwd is inside the very worktree we're about to remove:
# this subprocess can cd out for itself, but it can't fix the PARENT shell's cwd,
# so after we exit the caller lands on a deleted dir and the next getcwd fails
# (looks like an error even though cleanup succeeded). Fail fast and tell the
# caller to step out first — root cause, not a post-hoc warning.
# Compare with a trailing slash so a sibling worktree sharing a name prefix
# (e.g. .../dependabot vs .../dependabot-v2) isn't mistaken for "inside".
CWD=$(pwd -P)
if [[ -n "$WT_PATH" && ( "$CWD" == "$WT_PATH" || "$CWD" == "$WT_PATH"/* ) ]]; then
    MAIN_REPO=$(cd "$(git -C "$REPO_ROOT" rev-parse --git-common-dir)/.." && pwd -P)
    echo "✗ your cwd is inside the worktree to be removed ($WT_PATH)." >&2
    echo "  cd out first, then re-run:  cd $MAIN_REPO && bash $0 $PR" >&2
    exit 1
fi

if [[ -n "$WT_PATH" ]]; then
    # Decide on a dirty tree before touching it. The shared-env links do not count as dirt.
    force=""
    if [[ -n "$(git -C "$WT_PATH" status --porcelain -- . ':(exclude)*node_modules' ':(exclude)*.venv' 2>/dev/null)" ]]; then
        [[ -t 0 ]] || { echo "✗ worktree dirty at $WT_PATH; re-run in a terminal to force-remove it." >&2; exit 1; }
        read -r -p "  worktree dirty at $WT_PATH — force-remove? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "  → kept worktree + branch."; exit 0; }
        force=--force
    fi

    # Unlink shared-env symlinks (.venv, frontend/node_modules) BEFORE removal:
    # `git worktree remove --force` can traverse them and delete the MAIN
    # repo's real install (node_modules incident 2026-06-10). Deleting the
    # symlink itself never touches its target.
    find "$WT_PATH" -maxdepth 2 -type l \( -name node_modules -o -name .venv \) -print -delete 2>/dev/null || true

    git worktree remove ${force:+"$force"} "$WT_PATH"
    echo "  ✓ worktree removed: $WT_PATH"
fi

git show-ref --verify --quiet "refs/heads/$WT_BRANCH" && git branch -D "$WT_BRANCH"

echo "✓ done. PR: $URL"
exit 0
