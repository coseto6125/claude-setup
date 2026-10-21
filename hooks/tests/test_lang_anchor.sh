# Run: bash ~/.claude/hooks/tests/test_lang_anchor.sh
# Runs the hook with HOME pointing at a throwaway settings.json.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/lang-anchor.sh"
T=$(mktemp -d "$HOME/.cache/lang-anchor-test.XXXXXX"); mkdir "$T/.claude"
pass=0; fail=0
run() { printf '%s' "$2" | HOME="$T" bash "$SCRIPT" "$1" 2>/dev/null; echo "rc=$?"; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }

printf '{"language":"Deutsch"}' > "$T/.claude/settings.json"
check   test_main_session_gets_anchor        "$(run PostToolUse '{"session_id":"s"}')"  '"hookEventName":"PostToolUse"'
check   test_anchor_names_language           "$(run UserPromptSubmit '{}')"             'user sees in Deutsch'
check   test_empty_agent_id_is_main_session  "$(run PostToolUse '{"agent_id":""}')"     'Deutsch'
nocheck test_subagent_gets_nothing           "$(run PostToolUse '{"agent_id":"a1"}')"   'hookSpecificOutput'
check   test_subagent_exits_zero             "$(run PostToolUse '{"agent_id":"a1"}')"   'rc=0'
nocheck test_empty_stdin_gets_nothing        "$(run PostToolUse '')"                    'hookSpecificOutput'
printf '{}' > "$T/.claude/settings.json"
nocheck test_no_language_setting_nothing     "$(run PostToolUse '{}')"                  'hookSpecificOutput'
rm -f "$T/.claude/settings.json"
check   test_missing_settings_exits_zero     "$(run PostToolUse '{}')"                  'rc=0'

rm -f "$T/.claude/settings.json"; rmdir "$T/.claude" "$T"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
