#!/usr/bin/env bash
# Record and look up the file contents a /simplify review covered, for the push guard
# (~/.claude/hooks/guard-push-simplify.sh). A record is one "<blob>\t<path>" line;
# blob "-" means the review saw the path deleted.
#
#   review-mark.sh mark [dir]             record every changed path's reviewed content
#   review-mark.sh check <ref> [dir]      exit 0 when every path <ref> pushes was recorded
#   review-mark.sh check-worktree [dir]   the same for the working tree (commit and push in one command)
#
# Changed paths: commits that no remote branch holds, tracked edits, and untracked
# files up to REVIEW_MARK_MAX_BYTES (5 MiB). A larger untracked file is never hashed.
# Exit 1 names the first unreviewed path; any other non-zero exit is an error.
set -euo pipefail
MAX_BYTES=${REVIEW_MARK_MAX_BYTES:-5242880}

usage() { echo "usage: review-mark.sh mark [dir] | check <ref> [dir] | check-worktree [dir]" >&2; exit 64; }
cmd=${1:-}
case "$cmd" in
  mark|check-worktree) dir=${2:-.} ;;
  check) [ -n "${2:-}" ] || usage; ref=$2; dir=${3:-.} ;;
  *) usage ;;
esac

top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "not a git work tree: $dir" >&2; exit 2; }
cd "$top"
store="$(git rev-parse --path-format=absolute --git-common-dir)/claude-reviewed-content"
has_head() { git rev-parse -q --verify 'HEAD^{commit}' >/dev/null; }

unpushed_paths() {   # $1 ref: NUL-separated paths changed by commits no remote branch holds
  git rev-parse -q --verify "$1^{commit}" >/dev/null || { echo "not a commit: $1" >&2; return 2; }
  # combined: a merge lists the paths that differ from every parent (its own edits)
  git log --format= --name-only -z --no-renames --diff-merges=combined "$1" --not --remotes
}

changed_paths() {    # NUL-separated, unsorted, may repeat; each producer's failure is returned
  if has_head; then
    unpushed_paths HEAD || return
    git diff --name-only -z --no-renames HEAD || return
  else
    git ls-files -z || return
  fi
  git ls-files -o --exclude-standard -z | while IFS= read -r -d '' p; do
    # A nested repository lists as "dir/"; its content is not this repo's to push.
    if [ -f "$p" ] || [ -L "$p" ]; then
      if [ "$(stat -c %s -- "$p")" -le "$MAX_BYTES" ]; then printf '%s\0' "$p"
      elif [ -n "${REVIEW_MARK_STRICT:-}" ]; then printf '%s\0' "$p"; fi   # an `add` may commit it
    fi
  done
}

# Reads NUL-separated paths into the array `paths`; a failing producer is an error,
# not an empty list (a process substitution's status is otherwise lost).
read_paths() { mapfile -d '' -t paths < <("$@" | sort -zu); wait $! || exit 2; }

worktree_records() {   # "<blob>\t<path>" for every changed path, from the files on disk
  local p paths regular=()
  read_paths changed_paths
  for p in "${paths[@]}"; do
    case "$p" in *$'\n'*|*$'\t'*) echo "unsupported path: $p" >&2; exit 2 ;; esac
    if [ -L "$p" ]; then
      printf '%s\t%s\n' "$(printf '%s' "$(readlink -- "$p")" | git hash-object --stdin)" "$p"
    elif [ -f "$p" ] && [ "$(stat -c %s -- "$p")" -gt "$MAX_BYTES" ] \
         && ! git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      printf '!\t%s\n' "$p"                      # oversize untracked: never hashed, never matches
    elif [ -f "$p" ]; then
      regular+=("$p")
    elif [ -e "$p/.git" ]; then                  # a submodule: its gitlink is the checked-out commit
      printf '%s\t%s\n' "$(git -C "$p" rev-parse HEAD)" "$p"
    else                                         # gone, or a plain directory that replaced a file
      printf -- '-\t%s\n' "$p"
    fi
  done
  [ ${#regular[@]} -eq 0 ] && return 0
  paste <(printf '%s\n' "${regular[@]}" | git hash-object --stdin-paths) <(printf '%s\n' "${regular[@]}")
}

ref_records() {   # "<blob>\t<path>" for every path $1 pushes, from the commit
  local p meta paths
  local -A obj=()
  read_paths unpushed_paths "$1"
  [ ${#paths[@]} -eq 0 ] && return 0
  # One ls-tree for every path; a path the commit lacks is a deletion.
  # A tree entry is a directory that replaced a file: the file is gone, its new files list on their own.
  while IFS=$'\t' read -r -d '' meta p; do [[ $meta == 040000* ]] || obj[$p]=${meta##* }; done \
    < <(git --literal-pathspecs ls-tree -z --full-tree "$1" -- "${paths[@]}")
  wait $! || exit 2
  for p in "${paths[@]}"; do printf '%s\t%s\n' "${obj[$p]:--}" "$p"; done
}

missing() {   # stdin: records; prints the records the store lacks
  if [ -f "$store" ]; then grep -vxFf "$store" || true; else cat; fi
}

case "$cmd" in
  mark)
    exec 9>"$store.lock"; flock 9               # serialise read-modify-write across concurrent marks
    tmp=$(mktemp "$store.XXXXXX"); trap 'rm -f -- "$tmp"' EXIT
    { [ -f "$store" ] && cat "$store"; worktree_records; } | sort -u > "$tmp"
    mv -f "$tmp" "$store"
    ;;
  check|check-worktree)
    if [ "$cmd" = check ]; then out=$(ref_records "$ref" | missing); else out=$(worktree_records | missing); fi
    [ -z "$out" ] && exit 0
    first=${out%%$'\n'*}
    printf 'unreviewed: %s\n' "${first#*$'\t'}"
    exit 1
    ;;
esac
