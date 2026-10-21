#!/usr/bin/env bash
# usage: bash archive.sh <WORK> [name]
# Copies the durable part of a measurement run to $ARCHIVE_ROOT/<YYYY-MM-DD>-<name>/ and prints that path.
# ARCHIVE_ROOT defaults to ~/.claude/prompt-runs (private: outside skills/, so the public mirror never carries client excerpts).
# Scratchpads expire within about two weeks: cite the printed path as the Rows path in measurements.md or maintainer-notes.md.
# Copies *.md *.py *.sh *.tsv *.json *.jsonl *.txt *.sha256 *.patch under 1 MB, up to 3 levels deep (probes/, preload/, runs/ …).
# Skips hidden files (a .credentials.json copy never leaves WORK), the agentic.sh repo snapshot ./base/, and the iso*, cfg*,
# __pycache__ directories.
# Packs the top-level raw* directories into raw.tar.gz (hidden files excluded), so rows can be relabelled later.
# Run it again after scoring: a later run with the same name adds to and overwrites files in the same directory, and never
# deletes one. name defaults to basename of WORK.
usage() { sed -n '2,/^[^#]/s/^# \{0,1\}//p' "$0" >&2; }
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[ $# -ge 1 ] && [ $# -le 2 ] || { usage; exit 2; }
work=$1; name=${2:-$(basename "$work")}
[ -d "$work" ] || { echo "archive: no directory $work" >&2; exit 2; }
case "$name" in */*|.*|*[[:space:]]*|'') echo "archive: bad name '$name'" >&2; exit 2 ;; esac
root=${ARCHIVE_ROOT:-$HOME/.claude/prompt-runs}
dest=$(ls -d "$root"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$name" 2>/dev/null | head -1)
dest=${dest:-$root/$(date +%F)-$name}
mkdir -p "$dest" || exit 1
(cd "$work" && find . -mindepth 1 -maxdepth 3 \( -name '.*' -o -type d \( -name 'raw*' -o -path ./base -o -name 'iso*' -o -name 'cfg*' -o -name '__pycache__' \) \) -prune \
  -o -type f -size -1025k \( -name '*.md' -o -name '*.py' -o -name '*.sh' -o -name '*.tsv' -o -name '*.json' -o -name '*.jsonl' \
  -o -name '*.txt' -o -name '*.sha256' -o -name '*.patch' \) -exec cp --parents -t "$dest" {} +) || exit 1
mapfile -t raws < <(cd "$work" && find . -mindepth 1 -maxdepth 1 -type d -name 'raw*' -printf '%P\n')
[ ${#raws[@]} -eq 0 ] || (cd "$work" && tar czf "$dest/raw.tar.gz" --exclude='.*' -- "${raws[@]}") || exit 1
echo "$dest"
