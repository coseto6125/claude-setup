# Tests for scripts/loop.sh. Run: bash ~/.claude/skills/diagnose/tests/test_loop.sh
set -u
L=$(dirname "$0")/../scripts/loop.sh
T=$(mktemp -d)
fail=0

check() { # name, expected substring, actual output
  if [[ $3 == *"$2"* ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2' in: $3"; fail=1; fi
}

test_loop_no_args_exits_2() { bash "$L" >/dev/null 2>&1; check "${FUNCNAME[0]}" "rc=2" "rc=$?"; }
test_loop_zero_runs_exits_2() { bash "$L" 0 true >/dev/null 2>&1; check "${FUNCNAME[0]}" "rc=2" "rc=$?"; }
test_loop_non_numeric_runs_exits_2() { bash "$L" abc true >/dev/null 2>&1; check "${FUNCNAME[0]}" "rc=2" "rc=$?"; }
test_loop_missing_command_exits_2() { bash "$L" 3 >/dev/null 2>&1; check "${FUNCNAME[0]}" "rc=2" "rc=$?"; }
test_loop_passing_command_always_green() { check "${FUNCNAME[0]}" "red=0 green=3 verdict=always-green" "$(bash "$L" 3 true)"; }
test_loop_failing_command_always_red() { check "${FUNCNAME[0]}" "red=3 green=0 verdict=always-red" "$(bash "$L" 3 false)"; }
test_loop_failing_command_shows_symptom() { check "${FUNCNAME[0]}" "boom" "$(bash "$L" 2 sh -c 'echo boom; exit 1')"; }
test_loop_alternating_command_flaky() {
  local c=$T/count; echo 0 >"$c"
  local out; out=$(bash "$L" 4 sh -c 'n=$(cat "$1"); echo $((n+1)) >"$1"; [ $((n % 2)) -eq 0 ]' _ "$c")
  check "${FUNCNAME[0]}" "red=2 green=2 verdict=flaky" "$out"
}
test_loop_unknown_command_counts_red() { check "${FUNCNAME[0]}" "verdict=always-red" "$(bash "$L" 2 no-such-command-xyz)"; }
test_loop_argument_with_spaces_kept_whole() { check "${FUNCNAME[0]}" "verdict=always-green" "$(bash "$L" 1 test "a b" = "a b")"; }
test_loop_reports_median_ms() { check "${FUNCNAME[0]}" "median_ms=" "$(bash "$L" 1 true)"; }

for t in $(compgen -A function test_); do "$t"; done
rm -f "$T/count"; rmdir "$T"
exit $fail
