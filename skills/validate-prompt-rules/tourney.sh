#!/usr/bin/env bash
# Tournament over candidate rewrites of one rule block.
# usage: tourney.sh <scn> <ask> <scorer.py> <n> <hit-regex> <name>=<file|EMPTY> ...
#
# Runs every candidate on opus, sonnet and haiku, n trials each, then prints
# hit-rate per model and the Pareto front: the shortest candidate that ties the
# best hit-rate. A candidate only wins when it is both shorter and not worse.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCN="$1"; ASK="$2"; SCORER="$3"; N="$4"; HIT="$5"; shift 5

RAW=$(mktemp)
"$HERE/ab.sh" "$SCN" "$ASK" "$SCORER" "$N" "$@" | tee "$RAW" >/dev/null
head -1 "$RAW"

python3 - "$RAW" "$HIT" "$@" <<'PY'
import sys, re, os, collections
raw, hit_re = sys.argv[1], sys.argv[2]
specs = sys.argv[3:]
length = {}
for s in specs:
    name, f = s.split('=', 1)
    length[name] = 0 if f == 'EMPTY' else len(open(f, encoding='utf8').read())

tot = collections.Counter(); hit = collections.Counter(); err = collections.Counter()
per = collections.defaultdict(lambda: [0, 0])
for line in open(raw, encoding='utf8'):
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 3 or parts[0] not in length:
        continue
    arm, model, rest = parts[0], parts[1], '\t'.join(parts[2:])
    if rest.startswith('ERR('):
        err[arm] += 1
        continue
    ok = bool(re.search(hit_re, rest))
    tot[arm] += 1; hit[arm] += ok
    per[(arm, model)][1] += 1; per[(arm, model)][0] += ok

models = ['opus', 'sonnet', 'haiku']
print(f"\n{'arm':<10}{'chars':>7}{'opus':>9}{'sonnet':>9}{'haiku':>9}{'total':>9}")
rows = []
for arm in length:
    if not tot[arm]:
        continue
    cells = []
    for m in models:
        h, t = per[(arm, m)]
        cells.append(f"{h}/{t}" if t else "-")
    rate = hit[arm] / tot[arm]
    rows.append((arm, length[arm], rate, hit[arm], tot[arm], cells))
rows.sort(key=lambda r: (-r[2], r[1]))
for arm, ln, rate, h, t, cells in rows:
    print(f"{arm:<10}{ln:>7}{cells[0]:>9}{cells[1]:>9}{cells[2]:>9}{h:>5}/{t:<3}")

best = max(r[2] for r in rows)
front = [r for r in rows if r[2] >= best]
winner = min(front, key=lambda r: r[1])
te = sum(err.values())
if te: print(f"\nWARNING: {te} failed calls excluded: " + ", ".join(f"{a}={n}" for a,n in err.items() if n))
print(f"\nbest hit-rate {best:.2f}; shortest at that rate: {winner[0]} ({winner[1]} chars)")
incumbent = rows[0]
print("Pareto front:", ", ".join(f"{r[0]}({r[1]})" for r in sorted(front, key=lambda r: r[1])))
PY
rm -f "$RAW"
