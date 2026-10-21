# Run: bash ~/.claude/hooks/tests/test_sweep_merged_worktrees.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/skill_script/sweep-merged-worktrees.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
exists() { [ -e "$1" ] && echo yes || echo no; }
registered() { git -C "$T/proj/repo" worktree list --porcelain | grep -qx "worktree $1" && echo yes || echo no; }
age() { find "$1" -path "$1/.git" -prune -o -exec touch -h -d '2 days ago' {} +; }
g() { git -c user.email=t@t -c user.name=t "$@"; }

# A fake HOME with ~/.cache, a bare remote, a project root that holds the repo in a subdirectory, and a gh stub.
setup() {
  T=$(mktemp -d "$HOME/.cache/sweep-test.XXXXXX")
  export FAKE_HOME="$T/home"; mkdir -p "$FAKE_HOME/.cache" "$T/bin" "$T/proj"
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/gh"; chmod +x "$T/bin/gh"
  g init -q --bare "$T/remote.git"
  g clone -q "$T/remote.git" "$T/proj/repo" 2>/dev/null
  (cd "$T/proj/repo" && echo a > a && g add a && g commit -qm a && g push -q origin HEAD:main 2>/dev/null)
}
run() { (cd "$T/proj" && HOME="$FAKE_HOME" XDG_CACHE_HOME="$FAKE_HOME/.cache" PATH="$T/bin:$PATH" bash "$SCRIPT" "$@" >/dev/null 2>&1); }
wt() { g -C "$T/proj/repo" worktree add -q --detach "$1" HEAD 2>/dev/null; }
# Delete only the temp dir setup() created.
cleanup() { case "$T" in "$HOME"/.cache/sweep-test.?*) rm -rf -- "$T" ;; esac; }

test_pushed_clean_idle_scratch_is_removed() {
  setup; W="$FAKE_HOME/.cache/x/wt-a"; wt "$W"; age "$W"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" no
  cleanup
}
test_local_only_commit_is_kept() {
  setup; W="$FAKE_HOME/.cache/x/wt-b"; wt "$W"
  (cd "$W" && echo b > b && g add b && g commit -qm b); age "$W"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_dirty_scratch_is_kept() {
  setup; W="$FAKE_HOME/.cache/x/wt-c"; wt "$W"; echo dirty > "$W/a"; age "$W"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_recent_edit_is_kept() {
  setup; W="$FAKE_HOME/.cache/x/wt-d"; wt "$W"; age "$W"; touch "$W/a"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_worktree_outside_cache_is_untouched() {
  setup; W="$T/elsewhere/wt-e"; wt "$W"; age "$W"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_stale_registration_is_pruned() {
  setup; W="$FAKE_HOME/.cache/x/wt-f"; wt "$W"; mv "$W" "$T/moved-away"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" no
  cleanup
}
test_dry_run_removes_nothing() {
  setup; W="$FAKE_HOME/.cache/x/wt-g"; wt "$W"; age "$W"
  run --dry-run
  check "${FUNCNAME[0]} registered" "$(registered "$W")" yes
  check "${FUNCNAME[0]} dir" "$(exists "$W/a")" yes
  cleanup
}
SID=0123abcd-0000-4000-8000-00000000beef
test_scratchpad_of_active_session_is_kept() {
  setup; W="$FAKE_HOME/.cache/claude-tmp/claude-1000/proj/$SID/scratchpad/wt-i"; wt "$W"; age "$W"
  mkdir -p "$FAKE_HOME/.claude/projects/proj"; touch "$FAKE_HOME/.claude/projects/proj/$SID.jsonl"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_scratchpad_of_old_session_is_removed() {
  setup; W="$FAKE_HOME/.cache/claude-tmp/claude-1000/proj/$SID/scratchpad/wt-j"; wt "$W"; age "$W"
  mkdir -p "$FAKE_HOME/.claude/projects/proj"; touch -d '2 days ago' "$FAKE_HOME/.claude/projects/proj/$SID.jsonl"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" no
  cleanup
}
test_idle_under_a_day_is_kept() {
  setup; W="$FAKE_HOME/.cache/x/wt-k"; wt "$W"; find "$W" -path "$W/.git" -prune -o -exec touch -h -d '3 hours ago' {} +
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_throttle_skips_second_run() {
  setup; run; W="$FAKE_HOME/.cache/x/wt-h"; wt "$W"; age "$W"
  run
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  cleanup
}
test_worktree_in_use_by_process_is_kept() {
  setup; W="$FAKE_HOME/.cache/x/wt-k"; wt "$W"; age "$W"
  (cd "$W" && exec sleep 30) & local pid=$!
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" yes
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  cleanup
}
test_gh_failure_leaves_throttle_open() {
  setup; printf '#!/bin/sh\nexit 1\n' > "$T/bin/gh"; run
  W="$FAKE_HOME/.cache/x/wt-i"; wt "$W"; age "$W"; printf '#!/bin/sh\nexit 0\n' > "$T/bin/gh"
  run
  check "${FUNCNAME[0]}" "$(registered "$W")" no
  cleanup
}
test_gh_failure_still_sweeps_scratch() {
  setup; printf '#!/bin/sh\nexit 1\n' > "$T/bin/gh"; W="$FAKE_HOME/.cache/x/wt-j"; wt "$W"; age "$W"
  run --force
  check "${FUNCNAME[0]}" "$(registered "$W")" no
  cleanup
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do "$t"; done
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
