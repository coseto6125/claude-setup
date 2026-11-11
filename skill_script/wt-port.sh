#!/usr/bin/env bash
# wt-port [SERVICE]: print a stable TCP port for SERVICE (default "web") in this worktree.
#
# Use it only when you start a dev server: PORT=$(wt-port) npm run dev. Nothing runs at
# worktree creation and no state is kept: the port is CRC32("<worktree root>:<service>")
# mapped into 20000-29999, below the Linux ephemeral range (32768+), so the same worktree
# and service always get the same port, from any subdirectory.
#
# A port held by a process whose cwd is outside this worktree is someone else's: try the
# next one (up to PROBES) and say so on stderr. A port held from inside this worktree is
# ours (a server that is still running), so print it as it is. When `ss` fails, print the
# base port with a warning: an unchecked port beats no port.
set -uo pipefail

BASE=20000 SPAN=10000 PROBES=20

usage() { echo "usage: wt-port [SERVICE]" >&2; exit 2; }
(( $# <= 1 )) || usage
service=${1:-web}
[[ "$service" =~ ^[[:space:]]+$ ]] && usage

root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
read -r crc _ < <(printf '%s:%s' "$root" "$service" | cksum)
start=$(( crc % SPAN ))

# owner PORT: print "free", "ours" or "foreign"; exit 1 when ss cannot answer.
owner() {
    local out pid cwd
    out=$(ss -ltnpH "sport = :$1" 2>/dev/null) || return 1
    [ -z "$out" ] && { echo free; return; }
    for pid in $(grep -o 'pid=[0-9]*' <<<"$out" | cut -d= -f2); do
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
        [[ "$cwd/" == "$root/"* ]] && { echo ours; return; }
    done
    echo foreign
}

first=$(( BASE + start ))
for (( i = 0; i < PROBES; i++ )); do
    port=$(( BASE + (start + i) % SPAN ))
    if ! state=$(owner "$port"); then
        echo "wt-port: ss failed, $port is unchecked" >&2
        echo "$port"; exit 0
    fi
    case "$state" in
        free | ours)
            (( port != first )) && echo "wt-port: $first is taken by another directory, using $port" >&2
            echo "$port"; exit 0 ;;
    esac
done
echo "wt-port: $PROBES ports from $first are taken by other directories" >&2
exit 1
