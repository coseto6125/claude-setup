# Run: bash ~/.claude/hooks/tests/test_prune_scratchpad.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/prune-scratchpad.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
exists() { [ -e "$1" ] && echo yes || echo no; }
age() { find "$2" -exec touch -h -d "-$1 days" {} +; }   # set every entry under $2 to $1 days old
run() { SCRATCH_ROOT="$R" SCRATCH_FOREGROUND=1 CLAUDE_CODE_SESSION_ID="${SID:-none}" bash "$SCRIPT" "$@"; }
setup() { R=$(mktemp -d); }

test_old_session_is_deleted_recent_one_kept() {
  setup; mkdir -p "$R/proj/old/scratchpad" "$R/proj/new/scratchpad"
  echo x > "$R/proj/old/scratchpad/a.log"; echo y > "$R/proj/new/scratchpad/b.log"
  age 20 "$R/proj/old"; age 20 "$R/proj/new"; touch "$R/proj/new/scratchpad/b.log"
  run
  check "${FUNCNAME[0]} old" "$(exists "$R/proj/old")" no
  check "${FUNCNAME[0]} new" "$(exists "$R/proj/new/scratchpad/b.log")" yes
  rm -rf "$R"
}
test_one_recent_file_deep_inside_keeps_whole_session() {
  setup; mkdir -p "$R/proj/s/scratchpad/deep/er"; echo x > "$R/proj/s/scratchpad/deep/er/f"
  echo big > "$R/proj/s/scratchpad/old.bin"; age 30 "$R/proj/s"; touch "$R/proj/s/scratchpad/deep/er/f"
  run
  check "${FUNCNAME[0]}" "$(exists "$R/proj/s/scratchpad/old.bin")" yes
  rm -rf "$R"
}
test_new_empty_session_dir_survives() {
  setup; mkdir -p "$R/proj/fresh"; age 30 "$R/proj"; touch "$R/proj/fresh"
  run
  check "${FUNCNAME[0]}" "$(exists "$R/proj/fresh")" yes
  rm -rf "$R"
}
test_current_session_kept_even_when_old() {
  setup; mkdir -p "$R/proj/me/scratchpad"; echo x > "$R/proj/me/scratchpad/f"; age 40 "$R/proj"
  SID=me run
  check "${FUNCNAME[0]}" "$(exists "$R/proj/me/scratchpad/f")" yes
  rm -rf "$R"
}
test_emptied_old_project_removed_new_empty_project_kept() {
  setup; mkdir -p "$R/oldproj/s" "$R/newproj"; echo x > "$R/oldproj/s/f"; age 20 "$R/oldproj"
  run
  check "${FUNCNAME[0]} old" "$(exists "$R/oldproj")" no
  check "${FUNCNAME[0]} new" "$(exists "$R/newproj")" yes
  rm -rf "$R"
}
test_root_level_files_and_symlinks_untouched() {
  setup; T=$(mktemp -d); echo keep > "$T/target"
  echo x > "$R/cache-break-state.json"; mkdir -p "$R/proj"; ln -s "$T" "$R/proj/link"
  age 30 "$R"
  run
  check "${FUNCNAME[0]} root file" "$(exists "$R/cache-break-state.json")" yes
  check "${FUNCNAME[0]} link target" "$(cat "$T/target")" keep
  rm -rf "$R" "$T"
}
test_names_with_spaces_and_dashes_pruned() {
  setup; mkdir -p "$R/-home-x y/--s id/scratchpad"; echo x > "$R/-home-x y/--s id/scratchpad/f"; age 20 "$R/-home-x y"
  run
  check "${FUNCNAME[0]}" "$(exists "$R/-home-x y/--s id")" no
  rm -rf "$R"
}
test_dry_run_lists_and_deletes_nothing() {
  setup; mkdir -p "$R/proj/old"; echo x > "$R/proj/old/f"; age 20 "$R/proj"
  out=$(SCRATCH_ROOT="$R" bash "$SCRIPT" --dry-run)
  check "${FUNCNAME[0]} listed" "$(grep -c "proj/old" <<< "$out")" 1
  check "${FUNCNAME[0]} kept" "$(exists "$R/proj/old/f")" yes
  rm -rf "$R"
}
test_keep_days_override_and_bad_value() {
  setup; mkdir -p "$R/proj/s"; echo x > "$R/proj/s/f"; age 5 "$R/proj"
  SCRATCH_KEEP_DAYS=3 run
  check "${FUNCNAME[0]} 3 days prunes" "$(exists "$R/proj/s")" no
  mkdir -p "$R/proj/t"; echo x > "$R/proj/t/f"; age 50 "$R/proj"
  SCRATCH_KEEP_DAYS="1 2" run; check "${FUNCNAME[0]} list value no-op" "$(exists "$R/proj/t/f")" yes
  SCRATCH_KEEP_DAYS="" run; check "${FUNCNAME[0]} empty value uses 14" "$(exists "$R/proj/t")" no
  rm -rf "$R"
}
test_keep_days_leading_zero_read_as_decimal_keeps_recent_session() {
  setup; mkdir -p "$R/proj/fresh" "$R/proj/nine"; echo x > "$R/proj/fresh/f"; echo y > "$R/proj/nine/f"; age 9 "$R/proj/nine"
  SCRATCH_KEEP_DAYS=08 run 2>/dev/null
  check "${FUNCNAME[0]} 08 keeps fresh" "$(exists "$R/proj/fresh/f")" yes
  check "${FUNCNAME[0]} 08 prunes 9 days" "$(exists "$R/proj/nine")" no
  mkdir -p "$R/proj/nine"; echo y > "$R/proj/nine/f"; age 9 "$R/proj/nine"
  SCRATCH_KEEP_DAYS=010 run 2>/dev/null
  check "${FUNCNAME[0]} 010 is ten days" "$(exists "$R/proj/nine/f")" yes
  rm -rf "$R"
}
test_symlinked_project_dir_target_untouched() {
  setup; T=$(mktemp -d); mkdir -p "$T/session1/scratchpad"; echo keep > "$T/session1/scratchpad/important.txt"; age 30 "$T"
  ln -s "$T" "$R/proj"; touch -h -d "-30 days" "$R/proj"
  run
  check "${FUNCNAME[0]}" "$(cat "$T/session1/scratchpad/important.txt" 2>/dev/null)" keep
  rm -rf "$R" "$T"
}
test_scan_error_keeps_session() {
  setup; mkdir -p "$R/proj/s/locked"; echo x > "$R/proj/s/f"; age 30 "$R/proj"; chmod 000 "$R/proj/s/locked"
  run
  check "${FUNCNAME[0]}" "$(exists "$R/proj/s/f")" yes
  chmod 755 "$R/proj/s/locked"; rm -rf "$R"
}
test_missing_root_exits_0_silently() {
  out=$(SCRATCH_ROOT=/nonexistent/x bash "$SCRIPT" 2>&1); rc=$?
  check "${FUNCNAME[0]} rc" "$rc" 0
  check "${FUNCNAME[0]} silent" "$out" ""
}
test_hook_mode_prints_nothing_and_returns_fast() {
  setup; mkdir -p "$R/proj/old"; echo x > "$R/proj/old/f"; age 20 "$R/proj"
  out=$(SCRATCH_ROOT="$R" bash "$SCRIPT" 2>&1); rc=$?
  check "${FUNCNAME[0]} rc" "$rc" 0
  check "${FUNCNAME[0]} silent" "$out" ""
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$R/proj/old" ] || break; sleep 0.3; done
  check "${FUNCNAME[0]} background pruned" "$(exists "$R/proj/old")" no
  rm -rf "$R"
}
test_two_concurrent_runs_do_not_error() {
  setup; for i in 1 2 3 4 5; do mkdir -p "$R/p$i/s"; echo x > "$R/p$i/s/f"; done; age 20 "$R"
  out=$( { run & run; wait; } 2>&1)
  check "${FUNCNAME[0]} silent" "$out" ""
  check "${FUNCNAME[0]} all gone" "$(ls "$R" | wc -l)" 0
  rm -rf "$R"
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do "$t"; done
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
