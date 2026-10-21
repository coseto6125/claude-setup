# Sourced by preloaded.sh and agentic.sh. preload_snapshot <WORK> <script>
# On the first run it copies ~/.claude/CLAUDE.md, RTK.md, ECP.md (and $PROJ_MD when set) into <WORK>/preload/, with the
# script's sha256. Later runs read that snapshot, so every N step of one run sees the same text even when another session
# edits the live files. Warns when the script itself changed since the snapshot. Delete <WORK>/preload/ for a fresh run.
# Sets PRELOAD_DIR, and points PROJ_MD at the snapshot copy.
_preload_drop() { rm -f -- "$1/CLAUDE.md" "$1/RTK.md" "$1/ECP.md" "$1/script.sha256"; rmdir -- "$1"; }
preload_snapshot() {
  local work=$1 script=$2 p="$1/preload" sha tmp
  sha=$(sha256sum "$script" | cut -c1-64)
  if [ ! -d "$p" ]; then
    tmp=$(mktemp -d "$work/.preload.XXXXXX") || return 1
    if ! { cp ~/.claude/CLAUDE.md ~/.claude/RTK.md ~/.claude/ECP.md "$tmp"/ && echo "$sha" > "$tmp/script.sha256"; }; then
      _preload_drop "$tmp"; return 1
    fi
    if ! mv -T "$tmp" "$p" 2>/dev/null; then
      _preload_drop "$tmp"
      [ -d "$p" ] || { echo "preload_snapshot: cannot create $p" >&2; return 1; }
      echo "preload_snapshot: another run took $p first; using it" >&2
    fi
  else
    [ "$(cat "$p/script.sha256" 2>/dev/null)" = "$sha" ] || echo "WARN: $(basename "$script") changed since $p was taken; the arms may mix two script versions" >&2
    for f in CLAUDE.md RTK.md ECP.md; do cmp -s ~/.claude/"$f" "$p/$f" || echo "NOTE: live ~/.claude/$f differs from the snapshot in $p; using the snapshot" >&2; done
  fi
  if [ -n "${PROJ_MD:-}" ]; then
    [ -f "$p/project.md" ] || cp "$PROJ_MD" "$p/project.md" || return 1
    PROJ_MD=$p/project.md
  fi
  PRELOAD_DIR=$p
}
