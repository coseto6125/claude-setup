#!/usr/bin/env bash
# WorktreeCreate hook: mirror dev-env artifacts into a freshly created worktree.
#
# New worktrees lack gitignored build artifacts (.venv, node_modules, generated
# files) that the main working tree has. Symlinking them back saves a full
# reinstall per worktree. Fully defensive: every step is best-effort, the hook
# never fails the worktree creation (always exits 0).
#
# Contract: receives a JSON blob on stdin; we read the new worktree path from
# whichever common key the harness provides. The main working tree is resolved
# via `git worktree list` (first entry = primary), so links point at real
# sources, not a guessed path.

set -uo pipefail   # no -e: a failed link must not abort the hook

payload="$(cat 2>/dev/null || true)"

# Pull the worktree path out of the payload without requiring jq.
read_field() {
  printf '%s' "$payload" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in ('worktree_path','worktreePath','path','cwd','worktree'):
    v=d.get(k)
    if isinstance(v,str) and v:
        print(v); break
" 2>/dev/null
}

wt="$(read_field)"
[ -n "${wt:-}" ] || exit 0
[ -d "$wt" ] || exit 0

# Primary working tree = first line of `git worktree list` run inside the wt.
main="$(git -C "$wt" worktree list 2>/dev/null | head -1 | awk '{print $1}')"
[ -n "${main:-}" ] && [ -d "$main" ] || exit 0
[ "$main" != "$wt" ] || exit 0   # the wt *is* the primary — nothing to mirror

# Relative paths (from repo root) to mirror when the source exists in `main`
# and the destination doesn't already exist in the worktree.
targets=(
  ".venv"
  "node_modules"
  "frontend/node_modules"
  "frontend/src/routeTree.gen.ts"
)

linked=()
for rel in "${targets[@]}"; do
  src="$main/$rel"
  dst="$wt/$rel"
  [ -e "$src" ] || continue        #防呆: 來源不存在就跳過
  [ -e "$dst" ] && continue        # 防呆: 目的已存在(實檔或既有 link)就不覆蓋
  mkdir -p "$(dirname "$dst")" 2>/dev/null || continue
  if ln -s "$src" "$dst" 2>/dev/null; then
    linked+=("$rel")
  fi
done

[ ${#linked[@]} -gt 0 ] && printf 'worktree-symlinks: linked %s\n' "${linked[*]}" >&2
exit 0
