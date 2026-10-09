#!/usr/bin/env bash
# usage: WORK=<dir with probes/ rules/> PROJ_MD=<project CLAUDE.md> ARMS="control A B" MODELS=claude-opus-5-5 N=5 JOBS=8 bash preloaded.sh
# probes/<id>.json needs scenario, ask, hit_regex, scope. An arm's text comes from $WORK/<arm>.md when that file exists: the
# whole body (frontmatter stripped) goes before the scenario, as the Skill tool delivers it. Otherwise rules/<NN>.<arm>.txt
# is injected as "RULE you follow: …" where NN = id prefix. Pass full model IDs: an alias moves at a model release.
# Control preloads ~/.claude/CLAUDE.md (+RTK, ECP) unless PRELOAD_USER=0. Score with score26.py-style regex over raw/.
usage() { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; }
# Takes no arguments: any argument prints the header and exits, so `--help` never starts a run.
if [ $# -gt 0 ]; then usage; case "$1" in -h|--help) exit 0 ;; *) exit 2 ;; esac; fi
set -u
[ -n "${WORK:-}" ] && [ -d "$WORK/${PROBES_DIR:-probes}" ] || { sed -n 2p "$0" >&2; exit 2; }
for arm in ${ARMS:-control A B}; do [ "$arm" = control ] || [ -f "$WORK/$arm.md" ] || [ -d "$WORK/${RULES_DIR:-rules}" ] || { echo "missing $WORK/${RULES_DIR:-rules}/" >&2; exit 2; }; done
S="$WORK"; export S   # WORK holds probes/, rules/, raw/
# Deletes only a direct child of /tmp that this script made. An empty path, a nested path or `..` is refused.
rm_tmp() { for p; do case "$p" in *..*|/tmp/*/*) echo "rm_tmp: refused '$p'" >&2 ;; /tmp/?*) rm -rf -- "$p" ;; *) echo "rm_tmp: refused '$p'" >&2 ;; esac; done; }
CLAUDE_CONFIG_DIR=$(mktemp -d /tmp/preloaded-cfg.XXXXXX) || exit 1; export CLAUDE_CONFIG_DIR; trap 'rm_tmp "$CLAUDE_CONFIG_DIR"' EXIT INT TERM; printf '{}' > "$CLAUDE_CONFIG_DIR/settings.json"
cp ~/.claude/.credentials.json "$CLAUDE_CONFIG_DIR"/; [ "${PRELOAD_USER:-1}" = 1 ] && cp ~/.claude/CLAUDE.md ~/.claude/RTK.md ~/.claude/ECP.md "$CLAUDE_CONFIG_DIR"/
echo "user surface:"; ls -A "$CLAUDE_CONFIG_DIR"
PROJ_MD="${PROJ_MD:-}"; export PROJ_MD   # project CLAUDE.md to seed each probe cwd (optional)
mkdir -p "$S/raw"
JOBS_F=$(mktemp)
for p in ${PROBES:-$(cd "$S/${PROBES_DIR:-probes}" && ls *.json | sed "s/\.json$//")}; do
  for arm in ${ARMS:-control A B}; do for m in ${MODELS:-claude-opus-5-5}; do for i in $(seq 1 "${N:-5}"); do
    printf '%s\t%s\t%s\t%s\n' "$p" "$arm" "$m" "$i" >> "$JOBS_F"; done; done; done; done
run_one() {
  IFS=$'\t' read -r p arm m i <<< "$1"
  out="$S/raw/$p.$arm.$m.$i.txt"; [ -s "$out" ] && return
  j="$S/${PROBES_DIR:-probes}/$p.json"
  scn=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["scenario"])' "$j")
  ask=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["ask"])' "$j")
  n=${p%%-*}
  pre=""; extra=(); if [ -f "$S/$arm.md" ]; then pre="$(awk 'NR==1 && /^---$/{fm=1; next} fm && /^---$/{fm=0; next} !fm' "$S/$arm.md")

---

"; elif [ "$arm" != control ]; then extra=(--append-system-prompt "RULE you follow: $(cat "$S/${RULES_DIR:-rules}/$n.$arm.txt")"); fi
  d=$(mktemp -d /tmp/preloaded.XXXXXX) || { echo "ERR $p $arm $m $i: mktemp failed"; return 1; }; [ -n "$PROJ_MD" ] && cp "$PROJ_MD" "$d/CLAUDE.md"
  (cd "$d" && timeout 300 claude -p "${pre}SITUATION: $scn

$ask" --model "$m" --setting-sources user,project --disable-slash-commands --strict-mcp-config --mcp-config '{"mcpServers":{}}' "${extra[@]}" > "$out.tmp" 2>"$out.err")
  rc=$?; if [ $rc -eq 0 ] && [ -s "$out.tmp" ]; then mv "$out.tmp" "$out"; rm -f "$out.err"; echo "ok  $p $arm $m $i"; else echo "ERR $p $arm $m $i rc=$rc"; fi
  rm_tmp "$d"
}
export -f run_one rm_tmp
xargs -d '\n' -P "${JOBS:-8}" -I{} bash -c 'run_one "$@"' _ {} < "$JOBS_F"
