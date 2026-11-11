# Run: bash ~/.claude/hooks/tests/test_compact_handoff_nudge.sh
# Feeds the hook a throwaway transcript with a chosen number of compact_boundary entries.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/compact-handoff-nudge.sh"
T=$(mktemp -d "$HOME/.cache/compact-nudge-test.XXXXXX")
TR="$T/transcript.jsonl"
pass=0; fail=0
BOUNDARY='{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"auto"}}'
QUOTED='{"type":"attachment","attachment":{"type":"hook_success","stdout":"x"},"tag":"compact_boundary"}'
transcript() { : > "$TR"; for _ in $(seq 1 "$1"); do printf '%s\n{"type":"user"}\n' "$BOUNDARY" >> "$TR"; done; }
run() { printf '%s' "$1" | bash "$SCRIPT" 2>/dev/null; echo "rc=$?"; }
main() { run "{\"session_id\":\"s\",\"source\":\"compact\",\"transcript_path\":\"$TR\"}"; }
check() { if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want [$3] in [$2]"; fi; }
nocheck() { if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: unwanted [$3] in [$2]"; fi; }

transcript 4
nocheck test_four_compactions_gets_nothing          "$(main)" 'hookSpecificOutput'
check   test_four_compactions_exits_zero            "$(main)" 'rc=0'
transcript 5
check   test_fifth_compaction_gets_reminder         "$(main)" '"hookEventName":"SessionStart"'
check   test_reminder_names_count                   "$(main)" 'compacted 5 times'
check   test_reminder_points_at_handoff_skill       "$(main)" "$HOME/.claude/skills/handoff/SKILL.md"
transcript 6
nocheck test_sixth_compaction_gets_nothing          "$(main)" 'hookSpecificOutput'
transcript 7
nocheck test_seventh_compaction_gets_nothing        "$(main)" 'hookSpecificOutput'
transcript 8
check   test_eighth_compaction_repeats_reminder     "$(main)" 'compacted 8 times'
transcript 11
check   test_eleventh_compaction_repeats_reminder   "$(main)" 'compacted 11 times'

transcript 4; printf '%s\n' "$QUOTED" >> "$TR"
nocheck test_boundary_string_in_other_field_not_counted "$(main)" 'hookSpecificOutput'
transcript 5; printf 'not json "compact_boundary"\n' >> "$TR"
check   test_malformed_line_keeps_count             "$(main)" 'compacted 5 times'
transcript 5; printf 'torn\0tail\n' >> "$TR"
check   test_nul_byte_keeps_count                   "$(main)" 'compacted 5 times'

transcript 5
nocheck test_subagent_gets_nothing  "$(run "{\"agent_id\":\"a1\",\"transcript_path\":\"$TR\"}")" 'hookSpecificOutput'
check   test_empty_agent_id_is_main "$(run "{\"agent_id\":\"\",\"transcript_path\":\"$TR\"}")" 'compacted 5 times'
nocheck test_missing_transcript_gets_nothing "$(run "{\"transcript_path\":\"$T/absent.jsonl\"}")" 'hookSpecificOutput'
check   test_missing_transcript_exits_zero   "$(run "{\"transcript_path\":\"$T/absent.jsonl\"}")" 'rc=0'
nocheck test_no_transcript_field_gets_nothing "$(run '{"session_id":"s"}')" 'hookSpecificOutput'
nocheck test_empty_stdin_gets_nothing  "$(run '')" 'hookSpecificOutput'
check   test_empty_stdin_exits_zero    "$(run '')" 'rc=0'

rm -f "$TR"; rmdir "$T"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
