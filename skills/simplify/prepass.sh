#!/usr/bin/env bash
# Phase 2 pre-pass of the simplify skill: the blast radius of a diff, in a few lines.
#
#   prepass.sh <baseline> [repo]
#
# Runs `ecp impact --baseline <baseline> --repo <repo> --format json` with stderr kept apart (ecp
# prints notes there, and mixed into stdout they break a JSON parser), then prints only:
#   - the count of changed symbols by change type
#   - each changed symbol that has upstream callers, most callers first: callers (all depths, depth
#     <= 5), direct callers, test callers, name, kind, file:line. PREPASS_MAX (default 50, a non-negative integer) caps the list.
#   - the risk line: any symbol over 10 non-test callers is HIGH
#   - ecp's `result` caveat when it has one, then ecp's stderr lines, each prefixed `stderr: `
# Exit non-zero with ecp's error on stderr when ecp is missing, fails, or prints no JSON.
set -uo pipefail

baseline=${1:-}
repo=${2:-.}
[ -n "$baseline" ] || { echo "usage: prepass.sh <baseline> [repo]" >&2; exit 64; }
max=${PREPASS_MAX:-50}
[[ "$max" =~ ^[0-9]+$ ]] || { echo "PREPASS_MAX must be a non-negative integer, got: $max" >&2; exit 64; }
command -v ecp >/dev/null 2>&1 || { echo "ecp is not installed" >&2; exit 127; }

err=$(mktemp) || exit 1
trap 'rm -f -- "$err"' EXIT
json=$(ECP_SKIP_BG_REBUILD=1 ecp impact --baseline "$baseline" --repo "$repo" --format json 2>"$err" </dev/null)
rc=$?
if [ "$rc" -ne 0 ]; then
  cat "$err" >&2
  [ -z "$json" ] || printf '%s\n' "$json" >&2
  exit "$rc"
fi

# stdout of python is the report; its stderr is left alone.
py=$(cat <<'PY'
import collections, json, os, sys

HIGH = 10
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit("ecp printed no JSON on stdout; run it by hand: ecp impact --baseline <ref> --repo . --format json")

changed = data.get("changed_symbols", [])
kinds = {(c["name"], c["filePath"]): c["kind"] for c in changed}
by_type = collections.Counter(c.get("change_type", "?") for c in changed)
print(f"baseline {data.get('baseline', '?')}: {len(changed)} changed symbols in {len(data.get('changed_paths', []))} files ("
      + ", ".join(f"{n} {t}" for t, n in by_type.most_common()) + ")")

rows = []
for entry in data.get("impact_by_symbol", []):
    callers = {i["uid"]: i for i in entry.get("impact", []) if i.get("depth", 0) >= 1}
    if not callers:
        continue
    own = next((i for i in entry["impact"] if i.get("depth") == 0), {})
    name, path = entry["symbol"], entry["filePath"]
    rows.append((len(callers),
                 sum(1 for i in callers.values() if i["depth"] == 1),
                 sum(1 for i in callers.values() if i.get("test")),
                 name, own.get("kind") or kinds.get((name, path), "?"),
                 f"{path}:{own.get('line', '?')}"))
rows.sort(key=lambda r: (-r[0], r[3], r[5]))

limit = int(os.environ["PREPASS_MAX"])
print("callers direct tests  symbol  kind  file:line")
for r in rows[:limit]:
    print(f"{r[0]:>7} {r[1]:>6} {r[2]:>5}  {r[3]}  {r[4]}  {r[5]}")
if len(rows) > limit:
    print(f"... {len(rows) - limit} more with at most {rows[limit][0]} callers")
print(f"{len(rows)} of {len(changed)} changed symbols have upstream callers")

high = [r for r in rows if r[0] - r[2] > HIGH]
if high:
    print(f"risk: HIGH, {len(high)} symbol(s) over {HIGH} non-test callers: " + ", ".join(r[3] for r in high[:8]) + (", ..." if len(high) > 8 else ""))
else:
    print(f"risk: no symbol over {HIGH} non-test callers (auth / payment / migration / concurrency paths: judge from the diff)")

if data.get("result"):
    print("note: " + str(data["result"]))
with open(os.environ["PREPASS_ERR"]) as f:
    for line in f.read().splitlines():
        print("stderr: " + line)
PY
)
PREPASS_ERR=$err PREPASS_MAX=$max python3 -I -c "$py" <<<"$json"
