#!/usr/bin/env bash
# Remove idle worktrees whose work is already safe elsewhere. Runs from an
# async SessionStart hook; any doubt skips the worktree, it never forces.
#
#   sweep-merged-worktrees.sh [--dry-run] [--force]
#     --dry-run  print every decision, remove nothing, ignore the throttle
#     --force    ignore the throttle
#
# Repos: the repo at the current directory; when that is not a repo, every
# repo one directory below it (a project root that holds the repo in a subdirectory).
# Each repo first drops registrations whose directory no longer exists (git worktree prune).
#
# A worktree under <main>/.claude/worktrees/ is removed, with its branch, only when ALL hold:
#   1. it is on a branch;
#   2. that branch's PR is MERGED, at least MIN_AGE_MIN minutes ago;
#   3. the local tip equals the PR's last head commit (no follow-up work);
#   4-6. it is clean, unused and idle (below).
#
# A scratch worktree (any path under ~/.cache/) is removed, keeping its branch, only when ALL hold:
#   1. its HEAD is on at least one remote-tracking branch (no commit exists only here);
#   2. when the path names a session scratchpad, that session's transcript is older than SCRATCH_IDLE_MIN;
#   4-6. it is clean, unused and idle, with SCRATCH_IDLE_MIN as the idle time.
#
# Clean, unused and idle:
#   4. `git status --porcelain` is empty (tracked and untracked);
#   5. no process has its cwd or an open file inside it;
#   6. no file outside target/ and .git changed in the last MIN_AGE_MIN minutes.
set -u

MIN_AGE_MIN=120
SCRATCH_IDLE_MIN=1440
THROTTLE_MIN=720
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-sweep"
SCRATCH_ROOT="$HOME/.cache/"

dry=0 force=0
for a in "$@"; do
    case "$a" in
        --dry-run) dry=1 ;;
        --force) force=1 ;;
        *) echo "usage: $0 [--dry-run] [--force]" >&2; exit 2 ;;
    esac
done

command -v gh >/dev/null || exit 0
mkdir -p "$STATE_DIR"
log="$STATE_DIR/sweep.log"
now=$(date +%s)

# A snapshot of every process cwd and open file, taken by sweep_repo once the throttle lets it run
# (about 1 s of CPU, wasted on a throttled start).
snapshot_used() { used=$(for p in /proc/[0-9]*; do readlink "$p/cwd"; for f in "$p"/fd/*; do readlink "$f"; done; done 2>/dev/null | sort -u); }

in_use() {
    awk -v d="$1/" 'index($0 "/", d) == 1 { found = 1; exit } END { exit !found }' <<<"$used"
}

# Steps 4 to 6 with $2 minutes as the idle time. Prints the skip reason, or nothing when the worktree may go.
busy() {
    local path=$1 idle=$2 recent
    if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then echo "uncommitted changes"; return; fi
    if in_use "$path"; then echo "a process is using it"; return; fi
    recent=$(find "$path" \( -path "$path/target" -o -path "$path/.git" \) -prune -o -type f -mmin -"$idle" -print -quit 2>/dev/null)
    if [ -n "$recent" ]; then echo "recent edit ${recent#"$path"/}"; fi
}

# Scratch step 2: the session id in a path like .../claude-tmp/<user>/<project>/<session id>/scratchpad/...
owner_active() {
    local sid
    sid=$(sed -nE 's#.*/claude-tmp/[^/]+/[^/]+/([0-9a-f-]{36})/.*#\1#p' <<<"$1")
    [ -n "$sid" ] || return 1
    [ -n "$(find "$HOME/.claude/projects" -maxdepth 2 -name "$sid.jsonl" -mmin -"$SCRATCH_IDLE_MIN" -print -quit 2>/dev/null)" ]
}

sweep_repo() {
    local main=$1 key stamp merged
    key=$(printf '%s' "$main" | sha1sum | cut -c1-12)
    stamp="$STATE_DIR/$key.stamp"

    # Several sessions can start at once; one sweep per repo at a time.
    exec 9>"$STATE_DIR/$key.lock"
    flock -n 9 || return 0

    if [ "$dry" = 0 ] && [ "$force" = 0 ] && [ -n "$(find "$stamp" -mmin -"$THROTTLE_MIN" 2>/dev/null)" ]; then
        return 0
    fi
    snapshot_used

    say() {
        local line
        line="$(date '+%F %T') $main $*"
        if [ "$dry" = 1 ]; then echo "$line"; else echo "$line" >>"$log"; fi
    }

    if [ "$dry" = 1 ]; then
        git -C "$main" worktree prune --dry-run -v 2>&1 | sed 's/^/would /' | while IFS= read -r l; do say "$l"; done
    else
        git -C "$main" worktree prune -v 2>&1 | while IFS= read -r l; do say "pruned: $l"; done
    fi

    merged=$(cd "$main" && gh pr list --state merged --limit 300 \
        --json headRefName,headRefOid,mergedAt \
        --jq '.[] | [.headRefName, .headRefOid, .mergedAt] | @tsv' 2>/dev/null) || merged="!"
    # A failed gh (offline, logged out) leaves the throttle open, so the next start retries.
    [ "$dry" = 0 ] && [ "$merged" != "!" ] && touch "$stamp"
    [ "$merged" = "!" ] && merged=""

    git -C "$main" worktree list --porcelain | awk '
        /^worktree /{ if (path != "") print path "\t" branch; path = substr($0, 10); branch = "" }
        /^branch refs\/heads\//{ branch = substr($0, 19) }
        END { if (path != "") print path "\t" branch }
    ' | tail -n +2 | while IFS=$'\t' read -r path branch; do
        local name=${path##*/} row head_oid merged_at age_min tip why
        case "$path" in
        "$main"/.claude/worktrees/*)
            [ -n "$branch" ] || continue
            row=$(awk -F'\t' -v b="$branch" '$1 == b { print; exit }' <<<"$merged")
            [ -n "$row" ] || continue
            IFS=$'\t' read -r _ head_oid merged_at <<<"$row"
            age_min=$(( (now - $(date -d "$merged_at" +%s)) / 60 ))
            if [ "$age_min" -lt "$MIN_AGE_MIN" ]; then say "skip $name: merged ${age_min}m ago"; continue; fi
            tip=$(git -C "$path" rev-parse HEAD 2>/dev/null)
            if [ "$tip" != "$head_oid" ]; then say "skip $name: local tip ${tip:0:8} is not the PR head ${head_oid:0:8}"; continue; fi
            why=$(busy "$path" "$MIN_AGE_MIN")
            if [ -n "$why" ]; then say "skip $name: $why"; continue; fi
            if [ "$dry" = 1 ]; then say "would remove $name ($branch)"; continue; fi
            if git -C "$main" worktree remove "$path" 2>>"$log" && git -C "$main" branch -D "$branch" >/dev/null 2>>"$log"; then
                say "removed $name ($branch)"
            else
                say "FAILED $name ($branch); see the git error above"
            fi
            ;;
        "$SCRATCH_ROOT"*)
            [ -d "$path" ] || continue
            if [ -z "$(git -C "$path" branch -r --contains HEAD 2>/dev/null)" ]; then
                say "skip $name: HEAD is on no remote branch"; continue
            fi
            if owner_active "$path"; then say "skip $name: its session is still active"; continue; fi
            why=$(busy "$path" "$SCRATCH_IDLE_MIN")
            if [ -n "$why" ]; then say "skip $name: $why"; continue; fi
            if [ "$dry" = 1 ]; then say "would remove scratch $path"; continue; fi
            if git -C "$main" worktree remove "$path" 2>>"$log"; then
                say "removed scratch $path"
            else
                say "FAILED scratch $path; see the git error above"
            fi
            ;;
        esac
    done
}

top=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$top" ]; then
    repos=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
else
    repos=$(for g in ./*/.git; do [ -d "$g" ] && (cd "${g%/.git}" && pwd); done 2>/dev/null)
fi
[ -n "$repos" ] || exit 0
while IFS= read -r repo; do
    [ -n "$repo" ] && ( sweep_repo "$repo" )
done <<<"$repos"
