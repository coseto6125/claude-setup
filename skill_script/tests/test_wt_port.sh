# Tests for wt-port.sh. Run: bash ~/.claude/skill_script/tests/test_wt_port.sh
# Real git repos and real listening sockets; a stub `ss` simulates the dependency being down.
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/wt-port.sh"
SCRATCH=${WT_PORT_TEST_DIR:-$HOME/.cache}
T=$(mktemp -d "$SCRATCH/wt-port-test.XXXXXX") || exit 1
PASS=0 FAILS=0
LISTENERS=()
cleanup() { for p in "${LISTENERS[@]}"; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT

ok()   { PASS=$((PASS + 1)); }
fail() { FAILS=$((FAILS + 1)); echo "FAIL: $*"; }
in_range() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 20000 && $1 <= 29999 )); }

# listen PORT DIR: hold PORT open from a process whose cwd is DIR; waits until it listens.
listen() {
    (cd "$2" && exec python3 -I -c '
import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(60)' "$1") &
    LISTENERS+=($!)
    for _ in $(seq 50); do ss -ltnH "sport = :$1" | grep -q . && return 0; sleep 0.1; done
    echo "listener on $1 never came up"; return 1
}

git init -q "$T/repo" && git -C "$T/repo" commit -q --allow-empty -m init
git -C "$T/repo" worktree add -q -b feat "$T/repo-feat"
mkdir -p "$T/repo/src/deep" "$T/plain" "$T/elsewhere" "$T/空 白"
git init -q "$T/空 白"

test_wt_port_same_dir_twice_same_port() {
    local a b; a=$(cd "$T/repo" && bash "$SCRIPT"); b=$(cd "$T/repo" && bash "$SCRIPT")
    in_range "$a" && [ "$a" = "$b" ] && ok || fail "same dir: '$a' vs '$b'"
}

test_wt_port_subdirectory_matches_worktree_root() {
    local a b; a=$(cd "$T/repo" && bash "$SCRIPT"); b=$(cd "$T/repo/src/deep" && bash "$SCRIPT")
    in_range "$a" && [ "$a" = "$b" ] && ok || fail "subdir: '$a' vs '$b'"
}

test_wt_port_two_worktrees_differ() {
    local a b; a=$(cd "$T/repo" && bash "$SCRIPT"); b=$(cd "$T/repo-feat" && bash "$SCRIPT")
    in_range "$b" && [ "$a" != "$b" ] && ok || fail "worktrees: '$a' vs '$b'"
}

test_wt_port_two_services_differ() {
    local a b; a=$(cd "$T/repo" && bash "$SCRIPT" web); b=$(cd "$T/repo" && bash "$SCRIPT" api)
    in_range "$b" && [ "$a" != "$b" ] && ok || fail "services: '$a' vs '$b'"
}

test_wt_port_empty_service_equals_default() {
    local a b; a=$(cd "$T/repo" && bash "$SCRIPT"); b=$(cd "$T/repo" && bash "$SCRIPT" "")
    in_range "$a" && [ "$a" = "$b" ] && ok || fail "empty service: '$a' vs '$b'"
}

test_wt_port_whitespace_service_rejected() {
    local out rc; out=$(cd "$T/repo" && bash "$SCRIPT" "  " 2>&1); rc=$?
    [ "$rc" = 2 ] && ok || fail "whitespace service: rc=$rc out='$out'"
}

test_wt_port_extra_args_usage_error() {
    local rc; (cd "$T/repo" && bash "$SCRIPT" a b >/dev/null 2>&1); rc=$?
    [ "$rc" = 2 ] && ok || fail "extra args: rc=$rc"
}

test_wt_port_not_a_repo_uses_directory() {
    local a b; a=$(cd "$T/plain" && bash "$SCRIPT"); b=$(cd "$T/elsewhere" && bash "$SCRIPT")
    in_range "$a" && in_range "$b" && [ "$a" != "$b" ] && ok || fail "plain dirs: '$a' vs '$b'"
}

test_wt_port_space_and_cjk_path_in_range() {
    local a; a=$(cd "$T/空 白" && bash "$SCRIPT")
    in_range "$a" && ok || fail "cjk path: '$a'"
}

test_wt_port_foreign_listener_shifts_with_note() {
    local base got err
    base=$(cd "$T/repo-feat" && bash "$SCRIPT")
    listen "$base" "$T/elsewhere" || { fail "foreign listener setup"; return; }
    got=$(cd "$T/repo-feat" && bash "$SCRIPT" 2>"$T/err"); err=$(cat "$T/err")
    if in_range "$got" && [ "$got" != "$base" ] && ! ss -ltnH "sport = :$got" | grep -q . \
        && [[ "$err" == *"$base"* ]]; then ok; else fail "foreign: base=$base got=$got err='$err'"; fi
    kill "${LISTENERS[-1]}" 2>/dev/null; wait "${LISTENERS[-1]}" 2>/dev/null
}

test_wt_port_own_listener_keeps_port() {
    local base got
    base=$(cd "$T/repo" && bash "$SCRIPT" api)
    listen "$base" "$T/repo/src" || { fail "own listener setup"; return; }
    got=$(cd "$T/repo" && bash "$SCRIPT" api 2>/dev/null)
    in_range "$got" && [ "$got" = "$base" ] && ok || fail "own: base=$base got=$got"
    kill "${LISTENERS[-1]}" 2>/dev/null; wait "${LISTENERS[-1]}" 2>/dev/null
}

test_wt_port_ss_down_prints_base_with_warning() {
    local base got err rc
    base=$(cd "$T/repo" && bash "$SCRIPT")
    mkdir -p "$T/stub" && printf '#!/bin/sh\nexit 1\n' > "$T/stub/ss" && chmod +x "$T/stub/ss"
    got=$(cd "$T/repo" && PATH="$T/stub:$PATH" bash "$SCRIPT" 2>"$T/err"); rc=$?; err=$(cat "$T/err")
    [ "$rc" = 0 ] && in_range "$got" && [ "$got" = "$base" ] && [ -n "$err" ] && ok || fail "ss down: rc=$rc got=$got err='$err'"
}

test_wt_port_concurrent_calls_agree() {
    local a b
    (cd "$T/repo-feat" && bash "$SCRIPT" db > "$T/c1") & (cd "$T/repo-feat" && bash "$SCRIPT" db > "$T/c2") & wait
    a=$(cat "$T/c1"); b=$(cat "$T/c2")
    in_range "$a" && [ "$a" = "$b" ] && ok || fail "concurrent: '$a' vs '$b'"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_wt_port_'); do "$t"; done
echo "pass=$PASS fail=$FAILS"
[ "$FAILS" = 0 ]
