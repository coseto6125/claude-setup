#!/usr/bin/env bash
# usage: gemini-review.sh <brief-file> <report-file> [timeout-seconds, default 1200]
# Runs one Gemini review through the Antigravity CLI (`agy`) in the repo at $PWD and writes its final report to <report-file>.
# Headless agy auto-denies write_file and every command outside its permissions.allow, so the run cannot edit the repo.
# It also denies read_file, so the run allows read_file for the brief's directory and the repo, on top of the user's own rules.
# agy's stderr and its own log land next to the report as <report-file>.log and <report-file>.agy.log, and stay only when the run fails.
# Exit: 0 report written · 2 agy ended without a report · 3 no report before the timeout
#       4 agy missing or not logged in · 5 Gemini quota used up · 64 usage, or the report path is not writable
# Run it as a background call: it exits when the review ends, so the harness notification is the signal.
set -u
brief=${1:-}; report=${2:-}; limit=${3:-1200}
[ -s "$brief" ] && [ -n "$report" ] && [[ "$limit" =~ ^[1-9][0-9]*$ ]] || { sed -n 2p "$0" >&2; exit 64; }
# agy takes the prompt as one argv string, and Linux caps one string at 128 KiB.
[ "$(stat -c %s "$brief")" -lt 131072 ] || { echo "brief is 128 KiB or more; save the diff next to the brief and name its path instead" >&2; exit 64; }

log="$report.log"; agylog="$report.agy.log"
# Only exit 0 means the report holds this run's output, so empty all three before anything can fail.
{ : > "$report" && : > "$log" && : > "$agylog"; } 2>/dev/null || { echo "cannot write $report or its logs" >&2; exit 64; }
command -v agy >/dev/null || { echo "agy not installed" >&2; exit 4; }
# A rule takes an absolute path, and an unreadable or broken user settings file still yields the two read_file rules.
settings=$(python3 -I - "$HOME/.gemini/antigravity-cli/settings.json" "$(cd "$(dirname "$brief")" && pwd)" "$PWD" <<'PY'
import json, sys
try:
    allow = json.load(open(sys.argv[1]))["permissions"]["allow"]
except (OSError, ValueError, KeyError, TypeError):
    allow = []
allow = [r for r in allow if isinstance(r, str)] if isinstance(allow, list) else []
print(json.dumps({"permissions": {"allow": allow + ["read_file(%s)" % d for d in sys.argv[2:]]}}))
PY
)
# agy's default model is whatever its settings name, so pin a Gemini model.
setsid agy -p "$(cat "$brief")" --model "${AGY_MODEL:-gemini-3.8-flash-high}" --sandbox \
  --print-timeout "${limit}s" --log-file "$agylog" --add-dir "$(dirname "$brief")" --settings "$settings" \
  < /dev/null > "$report" 2> "$log" &
pid=$!
stop() {
  kill -TERM -- "-$pid" 2>/dev/null || return 0
  for _ in $(seq 1 10); do kill -0 -- "-$pid" 2>/dev/null || return 0; sleep 0.5; done
  kill -KILL -- "-$pid" 2>/dev/null
}
# A failed run moves whatever agy printed into the log, so the report stays empty.
fail() { stop; cat "$report" >> "$log"; : > "$report"; echo "$2" >&2; exit "$1"; }
trap stop EXIT
trap 'exit 130' INT TERM

quota='Individual quota reached'
# --print-timeout ends the turn itself; the grace covers an agy that ignores it.
deadline=$((SECONDS + limit + 10))
while kill -0 "$pid" 2>/dev/null; do
  grep -qs '^Authentication required' "$report" "$log" && fail 4 "agy not logged in; run agy once in a terminal"
  grep -qs "$quota" "$agylog" "$log" && break
  [ "$SECONDS" -lt "$deadline" ] || fail 3 "agy: no report after ${limit}s; log: $log"
  sleep 1
done
wait "$pid" 2>/dev/null; rc=$?

if grep -qs "$quota" "$agylog" "$log" "$report"; then
  fail 5 "Gemini quota used up$(grep -ohs 'Resets in [0-9hms.]*' "$agylog" "$log" | tail -1 | sed 's/^/; /')"
fi
grep -qs '^\[agy\] print timeout' "$log" && fail 3 "agy: no report after ${limit}s; log: $log"
grep -qs '^jetski: no output produced' "$report" && fail 2 "agy ended without a report: a tool was denied; log: $log"
[ "$rc" -eq 0 ] || fail 2 "agy exited $rc without a report; log: $log"
[ -s "$report" ] || fail 2 "agy finished with an empty report; log: $log"
rm -f "$log" "$agylog"
