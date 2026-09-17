#!/usr/bin/env bash
# usage: WORK=<dir> PROJ_MD=<project CLAUDE.md> ARMS="control seven" N=3 JOBS=3 MODEL=opus bash agentic.sh
# base/ = repo snapshot (git archive <ref> | tar -x), task.txt = the request, rules/<arm>.txt = appended rules.
# Each run: fresh copy, git init+commit, claude -p with tools on, stream.jsonl + diff.patch + status.txt left in runs/<arm>.<i>/.
set -u
[ -n "${WORK:-}" ] && [ -d "$WORK/base" ] && [ -f "$WORK/task.txt" ] || { sed -n 2p "$0" >&2; exit 2; }
for arm in ${ARMS:-control seven codex3}; do [ "$arm" = control ] || [ -f "$WORK/rules/$arm.txt" ] || { echo "missing $WORK/rules/$arm.txt" >&2; exit 2; }; done
A="$WORK"; export A   # WORK holds base/ (repo snapshot), rules/, task.txt, runs/
export CLAUDE_CONFIG_DIR=$(mktemp -d); trap 'rm -rf "$CLAUDE_CONFIG_DIR"' EXIT INT TERM; printf '{}' > "$CLAUDE_CONFIG_DIR/settings.json"
cp ~/.claude/.credentials.json ~/.claude/CLAUDE.md ~/.claude/RTK.md ~/.claude/ECP.md "$CLAUDE_CONFIG_DIR"/
PROJ_MD="${PROJ_MD:-}"; export PROJ_MD
JOBS_F=$(mktemp); for arm in ${ARMS:-control seven codex3}; do for i in $(seq 1 "${N:-3}"); do printf '%s\t%s\n' "$arm" "$i" >> "$JOBS_F"; done; done
run_one() {
  IFS=$'\t' read -r arm i <<< "$1"; d="$A/runs/$arm.$i"; [ -f "$d/DONE" ] && return
  rm -rf "$d"; mkdir -p "$d/repo"; cp -r "$A/base/." "$d/repo/"; [ -n "$PROJ_MD" ] && cp "$PROJ_MD" "$d/repo/CLAUDE.md"
  (cd "$d/repo" && git init -q && git add -A && git -c user.email=a@b -c user.name=pilot commit -qm base)
  extra=(); [ "$arm" != control ] && extra=(--append-system-prompt "RULES you follow:
$(cat "$A/rules/$arm.txt")")
  (cd "$d/repo" && timeout 1500 claude -p "$(cat "$A/task.txt")" --model "${MODEL:-opus}" --dangerously-skip-permissions --max-turns 80 \
     --setting-sources user,project --strict-mcp-config --mcp-config '{"mcpServers":{}}' --output-format stream-json --verbose "${extra[@]}" > "$d/stream.jsonl" 2> "$d/err.txt")
  echo "rc=$?" > "$d/DONE"; (cd "$d/repo" && git diff > "$d/diff.patch"; git status --short > "$d/status.txt"); echo "done $arm $i $(cat $d/DONE)"
}
export -f run_one
xargs -d '\n' -P "${JOBS:-3}" -I{} bash -c 'run_one "$@"' _ {} < "$JOBS_F"
