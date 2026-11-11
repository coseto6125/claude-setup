#!/usr/bin/env bash
# PreToolUse hook on a compiling cargo command. Three checks, in order; the first to fail exits 2:
# 1. A sub-agent of this session that can edit files is running (a marker that track-subagents.sh
#    keeps under ~/.cache/claude-agents/<session_id>/, younger than 90 minutes). A build over
#    half-written edits fails, and a crash takes every agent's uncommitted work.
# 2. A `cargo test` / `cargo nextest run` that ends without a test-thread cap. `-j` caps only the
#    compile jobs; the test binaries then take every CPU, and that load has powered off the host.
#    `cc-auto-etoon cap` (Rust port of lib/cargo_test_cap.py) decides for every cargo invocation in the command: capped, or rewritable
#    (the Bash hook's --pre rewriter then adds the cap), or unknown. Only an unknown one blocks.
# 3. The cwd's filesystem has less free space than a build here may still grow to: the larger of
#    CARGO_MIN_FREE_GB (default 20) and the biggest worktree target/ minus this worktree's own
#    target/. A full disk kills the linker with a Bus error and can leave corrupt git objects.
#    The target/ sizes come from a 6-hour cache; `du` on a 150G dir is slow. All sizes are bytes.
# `cc-auto-etoon cap --check` also tells whether the command runs cargo at all: a cargo word that is an
# argument, a comment or heredoc text is not a cargo command.
# `cargo clean`, `fmt`, `metadata` and the like still run.

set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
# The prefilter also passes `car\go` and `c"a"rgo`: the shell reads them as cargo.
[[ "$cmd" =~ c[\\\"\']*a[\\\"\']*r[\\\"\']*g[\\\"\']*o || "$cmd" == *\$\'* ]] || exit 0

# "<1 when the command compiles> <ok when every test invocation is capped or rewritable>".
# A helper that fails is read as "compiles, cannot cap", so the guard stays closed.
verdict=$("${BASH_SOURCE[0]%/*}/../bin/cc-auto-etoon" cap --check "$cmd" 2>/dev/null)
[[ "$verdict" =~ ^[01]\ (ok|fail)$ ]] || verdict="1 fail"
[ "${verdict%% *}" = 1 ] || exit 0

session=$(jq -r '.session_id // ""' <<<"$input")
if [[ "$session" =~ ^[A-Za-z0-9_-]+$ ]]; then
  agents=$(find "$HOME/.cache/claude-agents/$session" -maxdepth 1 -type f -mmin -90 2>/dev/null)
  if [ -n "$agents" ]; then
    {
      echo "Blocked: $(wc -l <<<"$agents") sub-agent(s) of this session can still edit files:"
      while IFS= read -r m; do echo "  $(head -1 "$m") ($m)"; done <<<"$agents"
      echo "Run cargo after every editing agent has returned, and commit its files by path first."
      echo "An agent that was killed leaves its marker: delete that file by its literal path."
    } >&2
    exit 2
  fi
fi

if [ "${verdict#* }" = fail ]; then
  {
    echo "Blocked: a cargo test or nextest command has no test-thread cap, and this hook cannot add one."
    echo "-j caps only the compile jobs. Write the cap by hand:"
    echo "  cargo test ... -- --test-threads=4   (after an existing ' -- ', only --test-threads=4)"
    echo "  cargo nextest run ... --test-threads=4"
    echo "A quoted \$'...' body, a command substitution or an unknown cargo option hides the command from the hook."
  } >&2
  exit 2
fi

cwd=$(jq -r '.cwd // ""' <<<"$input")
[ -d "$cwd" ] || cwd=$PWD
gib=1073741824
floor_gb=${CARGO_MIN_FREE_GB:-20}
[[ "$floor_gb" =~ ^[0-9]{1,9}$ ]] || floor_gb=20
floor=$((floor_gb * gib))
free=$(df --output=avail -B1 "$cwd" 2>/dev/null | tail -1 | tr -dc '0-9')
[ -n "$free" ] || exit 0
to_gib() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1073741824 }'; }

# Per-worktree target/ sizes, one "<bytes>\t<path>" line each, cached 6 hours per repo. A cache hit
# runs no `du`. A refresh holds a lock, re-checks freshness after it gets the lock, and never
# replaces a cache that holds sizes with an empty one: a failed or timed-out `du` keeps the last
# sizes and renews their age; with no earlier sizes it leaves an empty cache, so the floor applies.
cache_dir="$HOME/.cache/claude-cargo-disk"
size_cache=
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
fresh() { [ -n "$(find "$size_cache" -mmin -360 2>/dev/null)" ]; }
refresh_sizes() {
  mkdir -p "$cache_dir" && exec 9>"$size_cache.lock" && flock -w 45 9 || return
  fresh && return
  local targets=() wt sizes tmp
  while IFS= read -r wt; do
    [ -d "$wt/target" ] && targets+=("$wt/target")
  done < <(git -C "$cwd" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
  if [ ${#targets[@]} -gt 0 ] && sizes=$(timeout 30 du -s -B1 "${targets[@]}" 2>/dev/null); then
    tmp=$(mktemp "$cache_dir/.tmp.XXXXXX") || return
    printf '%s\n' "$sizes" >"$tmp" && mv -f "$tmp" "$size_cache"
  elif [ -s "$size_cache" ]; then
    touch "$size_cache"
  else
    tmp=$(mktemp "$cache_dir/.tmp.XXXXXX") || return
    mv -f "$tmp" "$size_cache"
  fi
}
if [ -n "$top" ] && [ -n "$common" ]; then
  size_cache="$cache_dir/$(printf '%s' "$common" | sha1sum | cut -c1-16).tsv"
  fresh || refresh_sizes
fi

min=$floor
how="CARGO_MIN_FREE_GB or the default 20"
if [ -n "$size_cache" ] && [ -s "$size_cache" ]; then
  IFS=$'\t' read -r big own bigpath < <(awk -F'\t' -v own="$top/target" \
    '$1+0 > m {m=$1+0; p=$2} $2 == own {o=$1+0} END {printf "%.0f\t%.0f\t%s\n", m, o, p}' "$size_cache")
  if [ $((big - own)) -gt "$floor" ]; then
    min=$((big - own))
    how="largest worktree target/ $(to_gib "$big")G ($bigpath) minus this worktree's $(to_gib "$own")G; the floor is ${floor_gb}G"
  fi
fi
[ "$free" -lt "$min" ] || exit 0

{
  echo "Blocked: only $(to_gib "$free")G free on the filesystem of $cwd (minimum $(to_gib "$min")G for a cargo build)."
  echo "Minimum $(to_gib "$min")G = $how."
  if [ -n "$size_cache" ] && [ -s "$size_cache" ]; then
    echo "Largest target/ dirs in this repo's worktrees (cached up to 6 hours):"
    sort -rn "$size_cache" | head -3 | while IFS=$'\t' read -r b p; do echo "  $(to_gib "$b")G  $p"; done
  fi
  echo "Free space first: cargo clean --manifest-path <worktree>/Cargo.toml"
  echo "Clean a worktree you own or whose PR merged. Ask the user before you clean another session's worktree."
} >&2
exit 2
