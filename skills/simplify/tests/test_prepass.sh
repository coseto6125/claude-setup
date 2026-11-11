# Run: bash ~/.claude/skills/simplify/tests/test_prepass.sh
# Runs prepass.sh with a stub `ecp` on PATH; ECP_STUB picks its behaviour (ok / fail / text).
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/prepass.sh"
T=$(mktemp -d "$HOME/.cache/prepass-test.XXXXXX") || exit 1; mkdir "$T/bin"
cat > "$T/bin/ecp" <<'EOF'
#!/bin/bash
echo "l2.note stub" >&2
case "$ECP_STUB" in
    ok) cat <<'JSON'
{"baseline":"b","changed_paths":["a.rs","b.rs"],
 "changed_symbols":[{"change_type":"modified","filePath":"a.rs","kind":"Function","line":1,"name":"f"},
                    {"change_type":"added","filePath":"a.rs","kind":"Function","line":9,"name":"g"},
                    {"change_type":"modified","filePath":"b.rs","kind":"Struct","line":3,"name":"S"},
                    {"change_type":"removed","filePath":"b.rs","kind":"Function","line":30,"name":"gone"}],
 "impact_by_symbol":[
  {"symbol":"f","filePath":"a.rs","impact":[{"depth":0,"uid":"0","kind":"Function","line":1,"test":false},
     {"depth":1,"uid":"1","test":false},{"depth":1,"uid":"2","test":true},{"depth":2,"uid":"3","test":false}]},
  {"symbol":"S","filePath":"b.rs","impact":[{"depth":0,"uid":"9","kind":"Struct","line":3,"test":false},
     {"depth":1,"uid":"1","test":false}]},
  {"symbol":"g","filePath":"a.rs","impact":[{"depth":0,"uid":"8","kind":"Function","line":9,"test":false}]}],
 "result":"results may be incomplete","status":"success"}
JSON
    ;;
    text) echo "not json" ;;
    fail) echo "Command failed: boom" >&2; exit 3 ;;
esac
EOF
chmod +x "$T/bin/ecp"
pass=0; fail=0
# run VAR=VALUE... -> stdout, then "rc=N"; stderr goes to $T/err
run() { local out rc; out=$(env "$@" PATH="$T/bin:/usr/bin:/bin" bash "$SCRIPT" HEAD . 2>"$T/err"); rc=$?; printf '%s\nrc=%s\n' "$out" "$rc"; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }

R=$(run ECP_STUB=ok)
check   test_summary_line_counts_change_types       "$R" 'baseline b: 4 changed symbols in 2 files (2 modified, 1 added, 1 removed)'
check   test_rows_sorted_by_callers_desc            "$R" $'      3      2     1  f  Function  a.rs:1\n      1      1     0  S  Struct  b.rs:3'
check   test_symbols_with_callers_counted           "$R" '2 of 4 changed symbols have upstream callers'
check   test_risk_line_when_no_symbol_over_ten      "$R" 'risk: no symbol over 10 non-test callers'
check   test_result_caveat_printed_as_note          "$R" 'note: results may be incomplete'
check   test_stderr_lines_prefixed                  "$R" 'stderr: l2.note stub'
check   test_exit_zero                              "$R" 'rc=0'

# PREPASS_MAX takes a non-negative integer only
for bad in -1 abc 1.5 ' ' 5x; do
    R=$(run ECP_STUB=ok "PREPASS_MAX=$bad")
    check   "test_prepass_max_invalid_exits_64[$bad]"  "$R" 'rc=64'
    check   "test_prepass_max_invalid_names_error[$bad]" "$(cat "$T/err")" 'PREPASS_MAX must be a non-negative integer'
    nocheck "test_prepass_max_invalid_prints_no_report[$bad]" "$R" 'baseline b'
done
R=$(run ECP_STUB=ok PREPASS_MAX=1)
check   test_prepass_max_one_limits_rows            "$R" '... 1 more with at most 1 callers'
nocheck test_prepass_max_one_hides_second_row       "$R" '  S  Struct'
R=$(run ECP_STUB=ok PREPASS_MAX=0)
check   test_prepass_max_zero_lists_no_row          "$R" '... 2 more with at most 3 callers'
check   test_prepass_max_zero_exits_zero            "$R" 'rc=0'
R=$(run ECP_STUB=ok PREPASS_MAX=)
check   test_prepass_max_empty_uses_default         "$R" '  S  Struct'

R=$(run ECP_STUB=fail)
check   test_ecp_failure_exit_code_kept             "$R" 'rc=3'
check   test_ecp_failure_error_on_stderr            "$(cat "$T/err")" 'Command failed: boom'
R=$(run ECP_STUB=text)
check   test_non_json_stdout_exits_nonzero          "$R" 'rc=1'
check   test_non_json_stdout_names_the_command      "$(cat "$T/err")" 'ecp printed no JSON'
check   test_missing_baseline_exits_64              "$(PATH="$T/bin:/usr/bin:/bin" bash "$SCRIPT" >/dev/null 2>&1; echo "rc=$?")" 'rc=64'
check   test_missing_ecp_exits_127                  "$(ECP_STUB=ok PATH=/usr/bin:/bin bash "$SCRIPT" HEAD . >/dev/null 2>&1; echo "rc=$?")" 'rc=127'

rm -f "$T/bin/ecp" "$T/err"; rmdir "$T/bin" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
