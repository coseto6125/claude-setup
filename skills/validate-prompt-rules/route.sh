#!/usr/bin/env bash
# Skill-routing A/B. Swaps the whole skills tree via CLAUDE_CONFIG_DIR so the
# only thing that changes between arms is the SKILL.md descriptions.
# usage: route.sh <skills-dir> <n> <model>
# env: CLAUDE_HOME (default ~/.claude), WORKDIR (default $PWD)
# Reads scenarios from scenarios.tsv: <expected-skill>\t<situation>
set -u
SKILLS="$1"; N="$2"; MODEL="$3"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Deletes only a direct child of /tmp that this script made. An empty path, a nested path or `..` is refused.
rm_tmp() { for p; do case "$p" in *..*|/tmp/*/*) echo "rm_tmp: refused '$p'" >&2 ;; /tmp/?*) rm -rf -- "$p" ;; *) echo "rm_tmp: refused '$p'" >&2 ;; esac; done; }
CFGROOT=$(mktemp -d /tmp/route-cfg.XXXXXX) || exit 1
CFG="$CFGROOT/cfg"; mkdir "$CFG"
JOBS=$(mktemp /tmp/route-jobs.XXXXXX) || { rm_tmp "$CFGROOT"; exit 1; }
# The arms authenticate from a copy of the real credentials, so the copy dies
# with the script on any exit path. Without this an interrupt leaves a
# plaintext token in a temp directory until the machine reboots.
trap 'rm_tmp "$CFGROOT" "$JOBS"' EXIT INT TERM

cp -r "$SKILLS" "$CFG"/skills
cp "${CLAUDE_HOME:-$HOME/.claude}"/.credentials.json "$CFG"/ 2>/dev/null
echo '{}' > "$CFG"/settings.json

while IFS=$'\t' read -r want scn; do
  [ -z "${want:-}" ] && continue
  for i in $(seq 1 "$N"); do printf '%s\t%s\n' "$want" "$scn" >> "$JOBS"; done
done < "$HERE/scenarios.tsv"

ask() {
  IFS=$'\t' read -r want scn <<< "$1"
  got=$(cd "${WORKDIR:-$PWD}" && CLAUDE_CONFIG_DIR="$CFG" timeout 180 claude -p \
    "SITUATION: $scn

Name the single skill you would invoke. Output only its name, nothing else." \
    --model "$MODEL" --setting-sources user --max-turns 1 \
    --strict-mcp-config --mcp-config '{"mcpServers":{}}' 2>/dev/null | tr -d '`\r' | head -1 | xargs)
  if [ "$got" = "$want" ]; then printf 'OK\t%s\t%s\n' "$want" "$got"; else printf 'MISS\t%s\t%s\n' "$want" "$got"; fi
}
export -f ask; export CFG MODEL

cat "$JOBS" | xargs -d '\n' -P 6 -I{} bash -c 'ask "$@"' _ {} | sort | uniq -c | sort -rn
