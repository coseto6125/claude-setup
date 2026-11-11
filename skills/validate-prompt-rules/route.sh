#!/usr/bin/env bash
# Skill-routing A/B. Swaps the whole skills tree via CLAUDE_CONFIG_DIR so the
# only thing that changes between arms is the SKILL.md descriptions.
# usage: [SCENARIOS=<tsv>] [WORK=<dir>] [PROJ_MD=<CLAUDE.md>] route.sh <skills-dir> <n> <model>
# env: CLAUDE_HOME (default ~/.claude), WORKDIR (default $PWD)
# SCENARIOS=<tsv>: file of <expected-skill>\t<situation> lines. Default: scenarios.tsv next to this script.
# WORK=<dir>: keep every raw row in $WORK/raw/<model>/<arm>/<NN>-<expected>/<trial>.txt (+ .err) and one line per row in $WORK/labels.tsv
# (status, expected, got, row path). ARM=<name> names the arm (default basename of <skills-dir>). Without WORK it prints totals only.
# PROJ_MD=<project CLAUDE.md>: copy it into a fresh probe cwd and load it (--setting-sources user,project).
# The arms see the deployed skill surface: the arm's tree shadows a bundled skill of the same name, the other bundled skills
# stay, and mirror_surface.py carries over $CLAUDE_HOME's skillOverrides and enabled user-scope plugins.
# CLAUDE.md, RTK.md, ECP.md and rules/ preload unless PRELOAD_USER=0.
# The arms only name a skill (--max-turns 1) and never run one, so only each top-level <name>/SKILL.md, and the SKILL.md and
# marker files of the claude.ai skills under synced/, are copied (symlinks followed); scripts and reference files stay behind.
# Runs isolation_gate.py --skills-surface first (cached per CLI version; GATE_FORCE=1 reruns it); exit 3 on a failed check.
# A call that exits non-zero, prints nothing, or prints an API error scores ERR, not MISS. Totals end with an OK/MISS/ERR line.
usage() { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0"; }
case "${1:-}" in -h|--help|"") usage; [ -n "${1:-}" ]; exit $? ;; esac
set -u
SKILLS="$1"; N="${2:-}"; MODEL="${3:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCN_FILE="${SCENARIOS:-$HERE/scenarios.tsv}"
[ -d "$SKILLS" ] || { echo "route.sh: skills dir '$SKILLS' does not exist" >&2; exit 2; }
[ -f "$SCN_FILE" ] || { echo "route.sh: scenarios file '$SCN_FILE' does not exist" >&2; exit 2; }
case "$N" in ''|*[!0-9]*) echo "route.sh: <n> must be a positive integer" >&2; exit 2 ;; esac
[ -n "$MODEL" ] || { echo "route.sh: <model> is required" >&2; exit 2; }
[ -z "${PROJ_MD:-}" ] || [ -f "$PROJ_MD" ] || { echo "route.sh: PROJ_MD '$PROJ_MD' does not exist" >&2; exit 2; }
if [ -n "${WORK:-}" ]; then mkdir -p "$WORK" && WORK=$(cd "$WORK" && pwd) || exit 2; fi

# Deletes only a direct child of /tmp that this script made. An empty path, a nested path or `..` is refused.
rm_tmp() { for p; do case "$p" in *..*|/tmp/*/*) echo "rm_tmp: refused '$p'" >&2 ;; /tmp/?*) rm -rf -- "$p" ;; *) echo "rm_tmp: refused '$p'" >&2 ;; esac; done; }
CFGROOT=$(mktemp -d /tmp/route-cfg.XXXXXX) || exit 1
CFG="$CFGROOT/cfg"; mkdir "$CFG"
JOBS=$(mktemp /tmp/route-jobs.XXXXXX) || { rm_tmp "$CFGROOT"; exit 1; }
# The arms authenticate from a copy of the real credentials, so the copy dies
# with the script on any exit path. Without this an interrupt leaves a
# plaintext token in a temp directory until the machine reboots.
trap 'rm_tmp "$CFGROOT" "$JOBS"' EXIT INT TERM

UHOME="${CLAUDE_HOME:-$HOME/.claude}"
cp "$UHOME"/.credentials.json "$CFG"/ 2>/dev/null
python3 -I "$HERE/mirror_surface.py" "$UHOME" "$CFG" || exit 2
if [ "${PRELOAD_USER:-1}" = 1 ]; then
  for f in CLAUDE.md RTK.md ECP.md; do [ ! -f "$UHOME/$f" ] || cp "$UHOME/$f" "$CFG"/; done
  [ ! -d "$UHOME/rules" ] || cp -rL "$UHOME/rules" "$CFG/rules"
fi

STAGE="$CFGROOT/skills"; mkdir "$STAGE"
find -L "$SKILLS" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0 | while IFS= read -r -d '' f; do
  d="$STAGE/$(basename "$(dirname "$f")")"; mkdir "$d" && cp -L "$f" "$d"/
done
if [ -d "$SKILLS/synced" ]; then
  (cd "$SKILLS" && find -L synced \( -name SKILL.md -o -name '.*' \) -type f -print0) | while IFS= read -r -d '' f; do
    mkdir -p "$STAGE/$(dirname "$f")" && cp -L "$SKILLS/$f" "$STAGE/$f"
  done
fi
[ -n "$(ls -A "$STAGE")" ] || { echo "route.sh: no <name>/SKILL.md under '$SKILLS'" >&2; exit 2; }

SOURCES=user; [ -z "${PROJ_MD:-}" ] || SOURCES=user,project
# The gate gets the arms' config before the skills tree joins it: it plants its own sentinel skills there.
GCFG="$CFGROOT/gate"; cp -r "$CFG" "$GCFG"
python3 -I "${GATE:-$HERE/isolation_gate.py}" --script route --cfg "$GCFG" ${PROJ_MD:+--proj "$PROJ_MD"} --skills-surface ${GATE_FORCE:+--force} -- \
  --setting-sources "$SOURCES" --strict-mcp-config --mcp-config '{"mcpServers":{}}' || exit 3
mv "$STAGE" "$CFG"/skills

id=0
while IFS=$'\t' read -r want scn || [ -n "${want:-}" ]; do
  case "${want//[[:space:]]/}" in ''|'#'*) continue ;; esac
  [ -n "${scn//[[:space:]]/}" ] || continue
  id=$((id + 1))
  for i in $(seq 1 "$N"); do printf '%s\t%s\t%s\t%s\n' "$id" "$i" "$want" "$scn" >> "$JOBS"; done
done < "$SCN_FILE"
[ -s "$JOBS" ] || { echo "route.sh: no scenarios in '$SCN_FILE'" >&2; exit 2; }
ARM="${ARM:-$(basename "$SKILLS")}"; ARM="${ARM//[^A-Za-z0-9._-]/_}"
[ -z "${WORK:-}" ] || : > "$WORK/labels.tsv"

ask() {
  IFS=$'\t' read -r id trial want scn <<< "$1"
  if [ -n "${WORK:-}" ]; then
    rel="raw/$MODEL/$ARM/$(printf '%02d' "$id")-$want/$trial.txt"; out="$WORK/$rel"; err="$out.err"
    mkdir -p "$(dirname "$out")"
  else
    rel=; out="$CFGROOT/out.$id.$trial"; err=/dev/null
  fi
  cwd="${WORKDIR:-$PWD}"
  if [ -n "${PROJ_MD:-}" ]; then
    cwd=$(mktemp -d /tmp/route-probe.XXXXXX) || { echo "ERR $want mktemp"; return; }
    cp "$PROJ_MD" "$cwd/CLAUDE.md"
  fi
  (cd "$cwd" && CLAUDE_CONFIG_DIR="$CFG" timeout 180 claude -p \
    "SITUATION: $scn

Name the single skill you would invoke. Output only its name, nothing else." \
    --model "$MODEL" --setting-sources "$SOURCES" --max-turns 1 \
    --strict-mcp-config --mcp-config '{"mcpServers":{}}' > "$out" 2> "$err")
  rc=$?
  [ -z "${PROJ_MD:-}" ] || rm_tmp "$cwd"
  got=$(tr -d '`\r' < "$out" | head -1 | xargs 2>/dev/null)
  if [ "$rc" -ne 0 ] || [ -z "$got" ] || [[ "$got" =~ ^(API\ Error|Error:) ]]; then status=ERR
  elif [ "$got" = "$want" ]; then status=OK
  else status=MISS; fi
  [ -z "${WORK:-}" ] || printf '%s\t%s\t%s\t%s\n' "$status" "$want" "$got" "$rel" >> "$WORK/labels.tsv"
  printf '%s\t%s\t%s\n' "$status" "$want" "$got"
}
export -f ask rm_tmp
export CFG CFGROOT MODEL ARM WORK SOURCES PROJ_MD WORKDIR

RES=$(mktemp /tmp/route-res.XXXXXX) || exit 1
trap 'rm_tmp "$CFGROOT" "$JOBS" "$RES"' EXIT INT TERM
xargs -d '\n' -P 6 -I{} bash -c 'ask "$@"' _ {} < "$JOBS" > "$RES"
sort "$RES" | uniq -c | sort -rn
awk -F'\t' '{c[$1]++} END {printf "OK=%d MISS=%d ERR=%d\n", c["OK"], c["MISS"], c["ERR"]}' "$RES"
