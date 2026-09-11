#!/usr/bin/env bash
# usage: WORK=<dir with probes/ rules/> PROJ_MD=<project CLAUDE.md> ARMS="control A B" MODELS=opus N=5 JOBS=8 bash preloaded.sh
# probes/<id>.json needs scenario, ask, hit_regex, scope; rules/<NN>.<arm>.txt is injected as "RULE you follow: …" where NN = id prefix.
# Control preloads ~/.claude/CLAUDE.md (+RTK, ECP) unless PRELOAD_USER=0. Score with score26.py-style regex over raw/.
set -u
S="${WORK:-$PWD}"; export S   # WORK holds probes/, rules/, raw/
export CLAUDE_CONFIG_DIR=$(mktemp -d); trap 'rm -rf "$CLAUDE_CONFIG_DIR"' EXIT INT TERM; printf '{}' > "$CLAUDE_CONFIG_DIR/settings.json"
cp ~/.claude/.credentials.json "$CLAUDE_CONFIG_DIR"/; [ "${PRELOAD_USER:-1}" = 1 ] && cp ~/.claude/CLAUDE.md ~/.claude/RTK.md ~/.claude/ECP.md "$CLAUDE_CONFIG_DIR"/
echo "user surface:"; ls -A "$CLAUDE_CONFIG_DIR"
PROJ_MD="${PROJ_MD:-}"; export PROJ_MD   # project CLAUDE.md to seed each probe cwd (optional)
mkdir -p "$S/raw"
JOBS_F=$(mktemp)
for p in ${PROBES:-$(cd "$S/${PROBES_DIR:-probes}" && ls *.json | sed "s/\.json$//")}; do
  for arm in ${ARMS:-control A B}; do for m in ${MODELS:-opus}; do for i in $(seq 1 "${N:-5}"); do
    printf '%s\t%s\t%s\t%s\n' "$p" "$arm" "$m" "$i" >> "$JOBS_F"; done; done; done; done
run_one() {
  IFS=$'\t' read -r p arm m i <<< "$1"
  out="$S/raw/$p.$arm.$m.$i.txt"; [ -s "$out" ] && return
  j="$S/${PROBES_DIR:-probes}/$p.json"
  scn=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["scenario"])' "$j")
  ask=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["ask"])' "$j")
  n=${p%%-*}
  extra=(); if [ "$arm" != control ]; then extra=(--append-system-prompt "RULE you follow: $(cat "$S/${RULES_DIR:-rules}/$n.$arm.txt")"); fi
  d=$(mktemp -d); [ -n "$PROJ_MD" ] && cp "$PROJ_MD" "$d/CLAUDE.md"
  (cd "$d" && timeout 300 claude -p "SITUATION: $scn

$ask" --model "$m" --setting-sources user,project --strict-mcp-config --mcp-config '{"mcpServers":{}}' "${extra[@]}" > "$out.tmp" 2>"$out.err")
  rc=$?; if [ $rc -eq 0 ] && [ -s "$out.tmp" ]; then mv "$out.tmp" "$out"; rm -f "$out.err"; echo "ok  $p $arm $m $i"; else echo "ERR $p $arm $m $i rc=$rc"; fi
  rm -rf "$d"
}
export -f run_one
xargs -d '\n' -P "${JOBS:-8}" -I{} bash -c 'run_one "$@"' _ {} < "$JOBS_F"
