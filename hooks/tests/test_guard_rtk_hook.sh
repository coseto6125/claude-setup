# Run: bash ~/.claude/hooks/tests/test_guard_rtk_hook.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/guard-rtk-hook.sh"
T=$(mktemp -d "$HOME/.cache/guard-rtk-hook-test.XXXXXX") || exit 1
pass=0; fail=0
# run SETTINGS_JSON -> stdout, then rc
run() { printf '%s' "$1" > "$T/s.json"; out=$(bash "$SCRIPT" "$T/s.json"); echo "${out}rc=$?"; }
hooks() { jq -cn --argjson c "$1" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:($c|map({type:"command",command:.}))}]}}'; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] got [$2]"; fi; }

eq    test_combined_hook_only_silent       "$(run "$(hooks '["~/.claude/hooks/auto-etoon.sh"]')")"                        rc=0
check test_standalone_rtk_hook_warns       "$(run "$(hooks '["~/.claude/hooks/auto-etoon.sh","rtk hook claude"]')")"      '"systemMessage":"settings.json has a standalone'
check test_standalone_with_spaces_warns    "$(run "$(hooks '["  rtk hook claude "]')")"                                    'SessionStart'
eq    test_rtk_inside_other_command_silent "$(run "$(hooks '["printf x | rtk hook claude | jq ."]')")"                     rc=0
eq    test_no_hooks_key_silent             "$(run '{}')"                                                                   rc=0
eq    test_malformed_json_silent           "$(run '{not json')"                                                            rc=0
eq    test_missing_file_silent             "$(bash "$SCRIPT" "$T/absent.json"; echo "rc=$?")"                              rc=0
eq    test_hook_without_command_silent     "$(run '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"prompt"}]}]}}')" rc=0
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
