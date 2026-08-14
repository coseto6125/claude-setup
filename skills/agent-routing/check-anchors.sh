#!/usr/bin/env bash
# Report when the Orca orchestration guide moves out from under the overrides in
# SKILL.md. The guide ships inside the orca binary, so it changes with the app,
# not with any file on disk.
#
# Two-stage on purpose: every run probes the app version only. Pulling the full
# guide happens once per Orca release, not once per session.
#
# Exit code is always 0 — this reports, it never blocks a session.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/.last-checked"
ANCHORS="$DIR/anchors.txt"
ORCA="${ORCA_CLI_COMMAND:-orca-ide}"

command -v "$ORCA" >/dev/null 2>&1 || exit 0
[ -r "$ANCHORS" ] || exit 0

ver=$("$ORCA" status --json 2>/dev/null |
      grep -o '"appVersion"[[:space:]]*:[[:space:]]*"[^"]*"' |
      head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -n "$ver" ] || exit 0

# Same Orca as last clean check: the guide cannot have moved.
[ -f "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = "$ver" ] && exit 0

guide=$("$ORCA" skills get orchestration 2>/dev/null)
[ -n "$guide" ] || exit 0

missing=0
while IFS= read -r anchor; do
    [ -z "$anchor" ] && continue
    printf '%s' "$guide" | grep -qF -- "$anchor" && continue
    [ "$missing" -eq 0 ] && echo "agent-routing: the orchestration guide changed under Orca $ver."
    echo "  missing anchor: $anchor"
    missing=1
done < "$ANCHORS"

if [ "$missing" -eq 0 ]; then
    printf '%s' "$ver" > "$STATE"
else
    # Leave the state stale on purpose, so the warning repeats until the
    # override section in SKILL.md is re-read against the new guide.
    echo "  re-read those sections of \`$ORCA skills get orchestration\`, then update SKILL.md and anchors.txt"
fi
exit 0
