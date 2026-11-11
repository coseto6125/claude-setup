# Run: bash ~/.claude/skills/simplify/tests/test_gemini_review.sh
# A fake `agy` on PATH plays each case; FAKE_MODE picks the behaviour.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/gemini-review.sh"
T=$(mktemp -d); trap 'pkill -f "[f]ake-agy-$$" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/agy" <<EOF
#!/usr/bin/env bash
# fake-agy-$$
printf '%s\n' "\$@" > "$T/args.seen"
log=/dev/null
while [ \$# -gt 0 ]; do
  case "\$1" in
    -p) printf '%s' "\$2" > "$T/prompt.seen"; shift ;;
    --log-file) log=\$2; shift ;;
  esac
  shift
done
echo 'Skill conflict detected: "ecp"' >&2
case "\$FAKE_MODE" in
  finish)    printf 'FINDING one\nFINDING two\n' ;;
  auth)      echo "Authentication required. Please visit the URL to log in:"; exec -a "fake-agy-$$-auth" sleep 300 ;;
  quota)     echo "E1022 run.go:371] calling model: RESOURCE_EXHAUSTED (code 429): Individual quota reached. Please upgrade your subscription to increase your limits. Resets in 167h8m15s." > "\$log"; echo "error: calling model" >&2; exit 1 ;;
  ptimeout)  echo "PARTIAL line"; echo "[agy] print timeout after 3s with turn in progress; returning partial output" >&2 ;;
  denied)    echo 'jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.' ;;
  die)       echo "boom" >&2; exit 1 ;;
  empty)     : ;;
  hang)      exec -a "fake-agy-$$-hang" sleep 300 ;;
esac
EOF
chmod +x "$T/bin/agy"
printf 'Review the diff. It said "hi" & $HOME\nline two\n' > "$T/brief.md"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }
run() { (cd "$T" && PATH="$T/bin:$PATH" FAKE_MODE="$1" timeout 40 bash "$SCRIPT" "${@:2}" 2> "$T/stderr"); echo $?; }
FINDINGS=$(printf 'FINDING one\nFINDING two')

test_finish_exits_0_writes_stdout_only_and_removes_logs() {
  rc=$(run finish brief.md out.md)
  check "${FUNCNAME[0]} rc" "$rc" 0
  check "${FUNCNAME[0]} report" "$(cat "$T/out.md")" "$FINDINGS"
  check "${FUNCNAME[0]} logs removed" "$(compgen -G "$T/out.md.*" | wc -l)" 0
}
test_brief_with_quotes_newlines_passes_verbatim() {
  run finish brief.md out.md >/dev/null
  check "${FUNCNAME[0]}" "$(cat "$T/prompt.seen")" "$(cat "$T/brief.md")"
}
test_default_model_is_gemini_and_agy_model_overrides() {
  run finish brief.md out.md >/dev/null
  check "${FUNCNAME[0]} default" "$(grep -A1 -x -- --model "$T/args.seen" | tail -1)" gemini-3.8-flash-high
  (cd "$T" && PATH="$T/bin:$PATH" FAKE_MODE=finish AGY_MODEL=gemini-3.8-flash-low bash "$SCRIPT" brief.md out.md 2>/dev/null)
  check "${FUNCNAME[0]} override" "$(grep -A1 -x -- --model "$T/args.seen" | tail -1)" gemini-3.8-flash-low
}
test_run_stays_headless_without_permission_bypass_or_plan_mode() {
  run finish brief.md out.md >/dev/null
  check "${FUNCNAME[0]} no bypass" "$(grep -c -- '--dangerously-skip-permissions' "$T/args.seen")" 0
  check "${FUNCNAME[0]} no mode" "$(grep -cx -- '--mode' "$T/args.seen")" 0
  check "${FUNCNAME[0]} sandbox" "$(grep -cx -- '--sandbox' "$T/args.seen")" 1
}
settings_seen() { grep -A1 -x -- --settings "$T/args.seen" | tail -1; }
# usage: run_home <home> <brief> <cwd>
run_home() { (cd "$3" && HOME="$1" PATH="$T/bin:$PATH" FAKE_MODE=finish bash "$SCRIPT" "$2" out.md 2>/dev/null); }
# usage: user_settings <json>; prints a new HOME that holds it
user_settings() { h=$(mktemp -d "$T/home.XXXXXX"); mkdir -p "$h/.gemini/antigravity-cli"; printf '%s' "$1" > "$h/.gemini/antigravity-cli/settings.json"; echo "$h"; }
test_settings_allow_read_file_for_brief_dir_and_repo() {
  mkdir -p "$T/repo"
  run_home "$(mktemp -d "$T/home.XXXXXX")" "$T/brief.md" "$T/repo"
  check "${FUNCNAME[0]}" "$(settings_seen)" "{\"permissions\": {\"allow\": [\"read_file($T)\", \"read_file($T/repo)\"]}}"
}
test_settings_keep_user_allow_rules() {
  mkdir -p "$T/repo"
  run_home "$(user_settings '{"permissions":{"allow":["command(ls)","command(grep)"]},"other":1}')" "$T/brief.md" "$T/repo"
  check "${FUNCNAME[0]}" "$(settings_seen)" "{\"permissions\": {\"allow\": [\"command(ls)\", \"command(grep)\", \"read_file($T)\", \"read_file($T/repo)\"]}}"
}
test_settings_broken_user_file_still_allows_read_file() {
  mkdir -p "$T/repo"
  run_home "$(user_settings '{"permissions": [')" "$T/brief.md" "$T/repo"
  check "${FUNCNAME[0]}" "$(settings_seen)" "{\"permissions\": {\"allow\": [\"read_file($T)\", \"read_file($T/repo)\"]}}"
}
test_settings_relative_brief_and_quoted_dir_are_absolute_json() {
  d="$T/a \"q\" dir"; mkdir -p "$d"; cp "$T/brief.md" "$d/brief.md"
  run_home "$(mktemp -d "$T/home.XXXXXX")" brief.md "$d"
  want=$(python3 -I -c 'import json,sys; print(json.dumps({"permissions": {"allow": ["read_file(%s)" % sys.argv[1]] * 2}}))' "$d")
  check "${FUNCNAME[0]}" "$(settings_seen)" "$want"
}
test_print_timeout_follows_limit() {
  run finish brief.md out.md 90 >/dev/null
  check "${FUNCNAME[0]}" "$(grep -A1 -x -- --print-timeout "$T/args.seen" | tail -1)" 90s
}
test_quota_exits_5_names_reset_and_empties_old_report() {
  printf 'OLD report\n' > "$T/q.md"
  rc=$(run quota brief.md q.md)
  check "${FUNCNAME[0]} rc" "$rc" 5
  check "${FUNCNAME[0]} reset named" "$(grep -c 'Resets in 167h8m15s' "$T/stderr")" 1
  check "${FUNCNAME[0]} emptied" "$(cat "$T/q.md")" ""
}
test_auth_prompt_exits_4_fast_and_kills_agy() {
  start=$SECONDS; rc=$(run auth brief.md auth.md)
  check "${FUNCNAME[0]} rc" "$rc" 4
  check "${FUNCNAME[0]} fast" "$(( SECONDS - start < 10 ))" 1
  sleep 1; check "${FUNCNAME[0]} killed" "$(pgrep -fc "[f]ake-agy-$$-auth")" 0
}
test_print_timeout_partial_exits_3_and_keeps_partial_in_log() {
  rc=$(run ptimeout brief.md pt.md)
  check "${FUNCNAME[0]} rc" "$rc" 3
  check "${FUNCNAME[0]} report empty" "$(cat "$T/pt.md")" ""
  check "${FUNCNAME[0]} partial in log" "$(grep -c 'PARTIAL line' "$T/pt.md.log")" 1
}
test_denied_tool_exits_2() {
  check "${FUNCNAME[0]}" "$(run denied brief.md dn.md)" 2
}
test_die_exits_2_and_keeps_log() {
  rc=$(run die brief.md die.md)
  check "${FUNCNAME[0]} rc" "$rc" 2
  check "${FUNCNAME[0]} names log" "$(grep -c 'die.md.log' "$T/stderr")" 1
  check "${FUNCNAME[0]} log kept" "$(grep -c boom "$T/die.md.log")" 1
}
test_empty_output_exits_2() {
  check "${FUNCNAME[0]}" "$(run empty brief.md empty.md)" 2
}
test_hang_past_timeout_exits_3_and_kills_agy() {
  rc=$(run hang brief.md hang.md 3)
  check "${FUNCNAME[0]} rc" "$rc" 3
  sleep 1; check "${FUNCNAME[0]} killed" "$(pgrep -fc "[f]ake-agy-$$-hang")" 0
}
test_agy_missing_exits_4() {
  rc=$( (cd "$T" && PATH="/usr/bin:/bin" bash "$SCRIPT" brief.md miss.md 2>/dev/null); echo $?)
  check "${FUNCNAME[0]}" "$rc" 4
}
test_usage_errors_exit_64() {
  : > "$T/blank.md"
  check "${FUNCNAME[0]} no args" "$(run finish)" 64
  check "${FUNCNAME[0]} missing brief" "$(run finish nope.md out.md)" 64
  check "${FUNCNAME[0]} empty brief" "$(run finish blank.md out.md)" 64
  check "${FUNCNAME[0]} bad timeout" "$(run finish brief.md out.md 0)" 64
  check "${FUNCNAME[0]} list timeout" "$(run finish brief.md out.md '5 6')" 64
}
test_brief_over_argv_limit_exits_64() {
  head -c 140000 /dev/zero | tr '\0' x > "$T/big.md"
  check "${FUNCNAME[0]} rc" "$(run finish big.md big.out)" 64
  check "${FUNCNAME[0]} reason" "$(grep -c 'KiB' "$T/stderr")" 1
}
test_unwritable_existing_report_exits_64_and_keeps_old_content() {
  printf 'OLD report\n' > "$T/ro.md"; chmod 444 "$T/ro.md"
  rc=$(run finish brief.md ro.md)
  check "${FUNCNAME[0]} rc" "$rc" 64
  check "${FUNCNAME[0]} old kept" "$(cat "$T/ro.md")" "OLD report"
  chmod 644 "$T/ro.md"
}
test_parallel_runs_keep_separate_reports() {
  a=$(run finish brief.md pa.md) & b=$(run finish brief.md pb.md); wait
  check "${FUNCNAME[0]} a" "$(cat "$T/pa.md")" "$FINDINGS"
  check "${FUNCNAME[0]} b" "$(cat "$T/pb.md")" "$FINDINGS"
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do "$t"; done
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
