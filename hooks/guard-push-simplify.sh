#!/usr/bin/env bash
# PreToolUse(Bash): two guards for rules that CLAUDE.md "Important Reminders" states.
#   1. Block `rm -r` / `rm -rf` on a path built from a variable or a glob.
#   2. Block `git push` unless review-mark.sh recorded that a review covered the pushed content.
set -euo pipefail
set -f   # word-split segments without expanding a glob against the cwd

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
rm_word='(^|[^[:alnum:]_-])rm([^[:alnum:]_-]|$)'     # rm as a word: not format, term, confirm
[[ "$cmd" =~ $rm_word || "$cmd" == *push* ]] || exit 0   # neither guard can fire: skip the parse

# One command segment per line: split on ; & && || |
segments() { printf '%s\n' "$cmd" | sed 's/||/\n/g; s/[;|&]/\n/g'; }

deny() {
  # stdout JSON is the Prime Agent protocol; stderr + exit 2 is the Claude Code one.
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  printf '%s\n' "$1" >&2
  exit 2
}

# rm counts in command position: the first word, after a listed prefix word (sudo, env,
# xargs, timeout, if, do …, with their options), after `find … -exec`, or inside $( ) or ` `.
is_variable_rm() {
  # `atcmd` is 1 while the next plain word is a command word; `val` is 1 when it is an option's value.
  # `pos` is 1 while the prefix word still owes its positional argument (timeout 5, chrt 10).
  local seg tok t rm recursive dynamic piped atcmd val pos find wrap
  while IFS= read -r seg; do
    set -- ${seg//[()]/ }                        # a subshell around a segment
    rm=0; recursive=0; dynamic=0; piped=0; atcmd=1; val=0; pos=0; find=0; wrap=""
    for tok; do
      if [ "$rm" = 0 ]; then
        t=${tok#\\}                              # \rm skips an alias, not the guard
        case "$t" in
          '{'|'}') continue ;;                   # a group around the segment
          -exec|-execdir|-ok|-okdir) [ "$find" = 1 ] && atcmd=1; continue ;;
        esac
        # The options that take a separate value, per prefix word (sudo -u root, nice -n 5).
        case "$wrap:$t" in
          sudo:-[ugCDhpUrtT]|doas:-[uC]|nice:-n|env:-[uCS]|xargs:-[InPLsdEa]|ionice:-[cnp]|timeout:-[sk]|timeout:--signal|timeout:--kill-after) val=1; continue ;;
        esac
        case "$t" in -*) continue ;; esac        # an option of a prefix word or of find
        if [ "$val" = 1 ]; then val=0; continue; fi
        if [ "$pos" = 1 ]; then pos=0; continue; fi
        [ "$atcmd" = 1 ] || { [ "$find" = 1 ] && continue; break; }
        wrap=$t
        case "$t" in
          rm|*/rm) rm=1 ;;
          xargs) piped=1 ;;
          find) piped=1; find=1; atcmd=0 ;;
          timeout|chrt) pos=1 ;;
          *=*|sudo|doas|command|env|nice|ionice|nohup|setsid|stdbuf|time|exec) ;;
          if|elif|while|until|do|then|else|'!') ;;
          *) break ;;                            # the command word, and it is not rm
        esac
        continue
      fi
      case "$tok" in
        --recursive) recursive=1 ;;
        --*) ;;
        -*[rR]*) recursive=1 ;;
        -*) ;;
        *'$'*|*'`'*|*'*'*|*'?'*|*'['*) dynamic=1 ;;
      esac
    done
    [ "$rm" = 1 ] && [ "$recursive" = 1 ] && { [ "$dynamic" = 1 ] || [ "$piped" = 1 ]; } && return 0
  done < <(segments; segments | sed 's/\$(/\n/g; s/`/\n/g')   # then each $( ) or ` ` body as its own command
  return 1
}

# Prints the directory a literal path token names, relative to $1. Fails on a
# token the shell would expand or split: `$`, a backtick, `~user`, an inner quote.
literal_dir() {
  local p=$2
  case "$p" in *'$'*|*'`'*) return 1 ;; esac
  case "$p" in \"*\"|\'*\') p=${p:1:${#p}-2} ;; esac
  case "$p" in *\"*|*\'*) return 1 ;; esac
  # shellcheck disable=SC2088  # matching a literal tilde token on purpose
  case "$p" in '~') p=$HOME ;; '~/'*) p=$HOME/${p#\~/} ;; '~'*) return 1 ;; esac
  case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s' "$1" "$p" ;; esac
}

# Walks the command segment by segment. Sets git_subs (the git subcommand of each
# segment, in order), push_count, push_dir (the repo of the push: the input cwd,
# then each literal `cd`, then `-C`), push_args (the tokens after `push`),
# non_git (the segments with no git subcommand, for the fallback push search),
# and unsure (why this parser cannot follow the push).
git_subs=(); push_args=(); push_dir=""; push_count=0; non_git=""; unsure=""
scan_git() {
  local raw seg tok sub skip dir base=$1 cd_unknown=""
  while IFS= read -r raw; do
    seg=${raw//[(){\}]/ }                        # a subshell or group around a segment
    sub=""; skip=""; dir=""
    set -- $seg
    case "${1:-}" in
      pushd|popd) cd_unknown="$1"; continue ;;
      cd)
        if [[ "$raw" == *'('* ]]; then cd_unknown="cd inside a subshell"
        elif [ $# -ge 2 ] && [[ "$2" != -* ]] && dir=$(literal_dir "$base" "$2"); then base=$dir
        else cd_unknown="cd to a path the guard cannot resolve"; fi
        continue ;;
    esac
    while [ $# -gt 0 ]; do
      tok=$1; shift
      case "$tok" in
        GIT_DIR=*|GIT_WORK_TREE=*) unsure="$tok"; continue ;;
        *=*) [ -z "$sub" ] && continue ;;          # leading VAR=value
      esac
      if [ -n "$skip" ]; then
        if [ "$skip" = C ]; then dir=$(literal_dir "${dir:-$base}" "$tok") || unsure="git -C $tok"; fi
        case "$skip:$tok" in c:push.*|c:remote.*) unsure="git -c $tok" ;; esac   # config that picks the refs
        skip=""; continue
      fi
      case "$tok" in
        git) sub="git"; continue ;;
        -C) [ "$sub" = git ] && skip=C; continue ;;
        -c) [ "$sub" = git ] && skip=c; continue ;;
        --git-dir=*|--work-tree=*|--namespace=*) [ "$sub" = git ] && unsure="$tok"; continue ;;
        --git-dir|--work-tree|--namespace) [ "$sub" = git ] && { unsure="$tok"; skip=x; }; continue ;;
        -*) continue ;;
      esac
      if [ "$sub" = git ]; then
        git_subs+=("$tok")
        if [ "$tok" = push ]; then
          push_count=$((push_count + 1)); push_dir=${dir:-$base}; push_args=("$@")
          [ -n "$cd_unknown" ] && unsure=$cd_unknown
        fi
        break
      fi
    done
    [ "$sub" = git ] || non_git+="$raw"$'\n'
  done < <(segments)
}
is_git_push() { local s; for s in "${git_subs[@]}"; do [ "$s" = push ] && return 0; done; return 1; }

if is_variable_rm; then
  deny "$(cat <<'EOF'
Blocked: a recursive rm on a path built from a variable, a glob or xargs input.

CLAUDE.md "Important Reminders": delete only named files by literal absolute
path, and only files you created. For an empty directory, create a new one:
  mktemp -d "<scratch dir>/name.XXXXXX"
or move the old one aside with mv first.
EOF
)"
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
scan_git "${cwd:-$PWD}"
pushes=""
is_git_push && pushes=1
# A push the token walk missed: inside quotes (`bash -c 'git push'`), eval, and
# the like. Only non-git segments are searched, so `git stash push` stays clear.
push_re='(^|[^[:alnum:]_-])git[^;&|]*[[:space:]]push([^[:alnum:]_-]|$)'
[[ "$non_git" =~ $push_re ]] && pushes=1
[ -n "$pushes" ] || exit 0
[[ "${CLAUDE_SKIP_SIMPLIFY:-}" == "1" || "$cmd" == CLAUDE_SKIP_SIMPLIFY=1* ]] && exit 0

# From here every failure blocks the push instead of letting it through.
set -E
trap 'deny "Blocked: the push guard failed at line $LINENO, so the push stays blocked. Prefix CLAUDE_SKIP_SIMPLIFY=1 only when the push carries no code change."' ERR

unsure_deny() {
  deny "Blocked: the push guard cannot follow this push ($1).
Write it as a plain \`git push [remote] [branch]\` from the repo directory, or
\`git -C /absolute/path push [remote] [branch]\`, as a command of its own."
}
is_git_push || unsure_deny "a push inside quotes, a subshell string or eval"
[[ "$non_git" =~ $push_re ]] && unsure_deny "a push inside quotes, a subshell string or eval"
[ "$push_count" -gt 1 ] && unsure_deny "more than one push in one command"
[ -n "$unsure" ] && unsure_deny "$unsure"

dry=""; wide=""; del=""; remote=""; repo_opt=""; refs=(); skipnext=""; tagnext=""
for a in "${push_args[@]}"; do
  if [ -n "$skipnext" ]; then skipnext=""; continue; fi
  if [ -n "$tagnext" ]; then tagnext=""; refs+=("refs/tags/$a"); continue; fi
  case "$a" in
    tag) if [ -n "$remote" ]; then tagnext=1; else remote=$a; fi ;;   # `tag <name>` is refs/tags/<name>
    '>'|'>>'|'<'|[0-9]'>'|[0-9]'>>'|[0-9]'<') skipnext=1 ;;   # a spaced redirect: the next word is its file
    --dry-run|-n) dry=1 ;;
    --all|--mirror|--tags) wide=$a ;;
    --delete|-d) del=1 ;;
    \#*) break ;;                              # a comment: the shell ignores the rest
    --repo=*) repo_opt=${a#--repo=} ;;          # the positional repository wins over it
    --repo) unsure_deny "--repo with a separate value" ;;
    -o|--push-option|--receive-pack|--exec) skipnext=1 ;;
    -*|[\<\>]*|*[!\\][\<\>]*) ;;               # an option, or a redirect joined to its file (not \>)
    *) if [ -z "$remote" ]; then remote=$a; else refs+=("$a"); fi ;;
  esac
done
remote=${remote:-${repo_opt:-}}
[ -n "$dry" ] && exit 0
[ -n "$wide" ] && unsure_deny "$wide pushes refs nobody named"
[ -n "$del" ] && exit 0
[ -d "$push_dir" ] || unsure_deny "the push runs in $push_dir, which does not exist"
git -C "$push_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# The source of each refspec; an empty source deletes a remote ref and sends no content.
srcs=()
for r in "${refs[@]}"; do
  s=$r
  case "$s" in \"*\"|\'*\') s=${s:1:${#s}-2} ;; esac   # unquote the whole word first
  s=${s#+}; s=${s%%:*}
  [ -z "$s" ] && continue
  git -C "$push_dir" rev-parse -q --verify "$s^{commit}" >/dev/null || unsure_deny "source ref $s does not name a commit"
  srcs+=("$s")
done
if [ ${#refs[@]} -eq 0 ]; then
  # A configured refspec or push.default=matching pushes refs nobody named. With no
  # remote named, git picks it: branch pushRemote, remote.pushDefault, branch remote, origin.
  if [ -z "$remote" ]; then
    br=$(git -C "$push_dir" symbolic-ref -q --short HEAD || true)
    remote=$( { [ -n "$br" ] && git -C "$push_dir" config --get "branch.$br.pushRemote"; } \
      || git -C "$push_dir" config --get remote.pushDefault \
      || { [ -n "$br" ] && git -C "$push_dir" config --get "branch.$br.remote"; } \
      || echo origin)
  fi
  if [ "$(git -C "$push_dir" config --get push.default || true)" = matching ] \
     || git -C "$push_dir" config --get-all "remote.$remote.push" >/dev/null; then
    unsure_deny "the push config names the refs"
  fi
  git -C "$push_dir" rev-parse -q --verify 'HEAD^{commit}' >/dev/null || exit 0   # no commit: nothing to send
  srcs=(HEAD)
fi

# A commit in the same command lands after this check, so the working tree it
# commits is judged too; after an `add`, oversize untracked files count as unreviewed.
# Any other subcommand that moves HEAD before the push leaves the pushed content unknown.
with_worktree=""; strict=""
for s in "${git_subs[@]}"; do
  [ "$s" = push ] && break
  case "$s" in
    add) strict=1 ;;
    commit) with_worktree=1 ;;
    merge|rebase|cherry-pick|am|pull|revert|reset|stash|checkout|switch|restore)
      unsure_deny "git $s before the push in one command" ;;
  esac
done

MARK=${REVIEW_MARK:-$HOME/.claude/skills/simplify/review-mark.sh}
verdict() {   # runs one review-mark check; returns on success, blocks otherwise
  local out rc=0
  out=$(REVIEW_MARK_STRICT="$strict" "$MARK" "$@" "$push_dir" 2>&1) || rc=$?
  [ "$rc" = 0 ] && return 0
  [ "$rc" = 1 ] || deny "Blocked: review-mark.sh $1 failed (rc=$rc): $out"
  deny "$(cat <<EOF
Blocked: no /simplify review covers the content this push sends ($out).

Run the review — the skill at ~/.claude/skills/simplify/SKILL.md. Its last step
records the reviewed content with review-mark.sh. An edit after the review
changes the content, so it needs a new review.

Escape hatch for a push that carries no code change
(tag, branch delete, already-reviewed rebase): prefix the command with
  CLAUDE_SKIP_SIMPLIFY=1
EOF
)"
}
[ -n "$with_worktree" ] && verdict check-worktree
for s in "${srcs[@]}"; do verdict check "$s"; done
exit 0
