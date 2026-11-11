#!/usr/bin/env bash
# PreToolUse(Bash): four guards for rules that CLAUDE.md "Important Reminders" states.
#   1. Block `rm -r` / `rm -rf` on a path built from a variable or a glob.
#   2. Block a leading `sleep` of 10 s or more that the harness misses (`command sleep 110`).
#   3. Block `pgrep -f` / `pkill -f` with a pattern that matches this command's own shell.
#   4. Block `git push` unless review-mark.sh recorded that a review covered the pushed content.
set -euo pipefail
guard_exit() {
  local rc=$?
  trap - EXIT
  if [ "$rc" != 0 ]; then
    printf '%s\n' 'Blocked: push guard internal error; command denied.' >&2
    exit 2
  fi
  exit "$rc"
}
trap guard_exit EXIT
set -f   # word-split segments without expanding a glob against the cwd

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
rm_word='(^|[^[:alnum:]_-])rm([^[:alnum:]_-]|$)'     # rm as a word: not format, term, confirm
[[ "$cmd" =~ $rm_word || "$cmd" == *push* || "$cmd" == *sleep* || "$cmd" == *pgrep* || "$cmd" == *pkill* ]] ||
  exit 0   # no guard can fire: skip the parse

# The body of a quoted-delimiter heredoc (<<'EOF', <<"EOF", <<\EOF) is literal data for its
# consumer. Drop it unless the consumer is a shell. An unquoted heredoc expands $( ) in its
# body, so it stays.
data_heredocs_dropped() {
  awk '
    function consumer(head,   w, n, i, b) {
      sub(/.*[;&|(]/, "", head)
      n = split(head, w, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        if (w[i] == "" || w[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
        if (w[i] ~ /^(sudo|env|command|exec|nohup|time)$/ || w[i] ~ /^-/) continue
        b = w[i]; sub(/.*\//, "", b); return b
      }
      return ""
    }
    {
      if (n > 0) {
        line = $0
        if (tabs[cur]) sub(/^\t+/, "", line)
        if (keep[cur]) print
        if (line == delim[cur] && ++cur > n) n = 0
        next
      }
      print
      rest = $0; done = 0
      while (match(rest, /<<-?[ \t]*('\''[^'\'']+'\''|"[^"]+"|\\?[A-Za-z_][A-Za-z0-9_]*)/)) {
        op = substr(rest, RSTART, RLENGTH)
        pre = substr(rest, RSTART - 1, 1); post = substr(rest, RSTART + 2, 1)
        head = done + RSTART - 1
        rest = substr(rest, RSTART + RLENGTH); done = head + RLENGTH
        if (pre == "<" || post == "<") continue
        d = op; sub(/^<<-?[ \t]*/, "", d)
        quoted = d ~ /^['\''"\\]/
        gsub(/['\''"\\]/, "", d)
        n++; delim[n] = d; tabs[n] = (op ~ /^<<-/)
        keep[n] = !quoted || consumer(substr($0, 1, head)) ~ /^(bash|sh|zsh|dash|ksh|eval|source|\.|ssh)$/
      }
      if (n > 0) cur = 1
    }'
}

# One command segment per line: split on ; & && || |
segments() { printf '%s\n' "$cmd" | data_heredocs_dropped | sed 's/||/\n/g; s/[;|&]/\n/g'; }
# Each segment, then each $( ) or ` ` body as a command of its own.
# Capture producer failures before any predicate or process substitution can hide them.
segment_text=$(segments)
substitution_text=$(printf '%s\n' "$segment_text" | sed 's/\$(/\n/g; s/`/\n/g')
command_text="$segment_text
$substitution_text"

deny() {
  # stdout JSON is the Prime Agent protocol; stderr + exit 2 is the Claude Code one.
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  printf '%s\n' "$1" >&2
  trap - EXIT
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
  done <<< "$command_text"
  return 1
}

# A line with an odd count of " or ' is a piece of a quoted string that a separator inside it
# split (`grep "a\|pgrep -f" f`). The sleep and pgrep guards do not read it as a command.
split_in_quotes() {
  local dq=${1//[^\"]/} sq=${1//[^\']/}
  (( ${#dq} % 2 || ${#sq} % 2 ))
}

# The prefix words that can stand before a command word, as the sleep and pgrep guards read them.
prefix_word='^(.*=.*|sudo|command|builtin|env|nice|nohup|exec|time|rtk|proxy|if|elif|while|until|do|then|else|!)$'

# The harness blocks a long leading `sleep`, but not under a prefix word (`command sleep 110`),
# a backslash or a path, nor a length it cannot read (`sleep $W`). This guard reads the
# leading command the same way, after any `cd`: an operand of 10 s or more, a m/h/d suffix,
# or a length it cannot read blocks it. A redirection ends the operands.
hit=""
is_leading_sleep() {
  local line tok d
  while IFS= read -r line; do
    set -- ${line//[(){\}]/ }
    [ $# -eq 0 ] && continue
    [ "$1" = cd ] && continue
    split_in_quotes "$line" && return 1
    while [ $# -gt 0 ]; do
      tok=${1#\\}; shift
      [[ "$tok" =~ $prefix_word ]] && continue
      case "$tok" in sleep|*/sleep) ;; *) return 1 ;; esac
      for d; do
        d=${d//[\"\']/}
        case "$d" in
          *'>'*|*'<'*) return 1 ;;
          -*) ;;
          *[!0-9.smhd]*|*[mhd]) hit=$line; return 0 ;;
          *) d=${d%s}; [ "${d%%.*}" -ge 10 ] 2>/dev/null && { hit=$line; return 0; } ;;
        esac
      done
      return 1
    done
    return 1
  done <<< "$segment_text"
  return 1
}

# pgrep -f / pkill -f match whole command lines, and the Bash tool's shell carries this whole
# command in its argv. A pattern with no bracket expression therefore always matches that shell.
is_self_matching_pgrep() {
  local line tok d full want
  while IFS= read -r line; do
    split_in_quotes "$line" && continue
    set -- ${line//[(){\}]/ }
    while [ $# -gt 0 ]; do
      tok=${1#\\}; shift
      [[ "$tok" =~ $prefix_word ]] && continue
      case "$tok" in pgrep|pkill|*/pgrep|*/pkill) ;; *) break ;; esac
      full=0; want=""
      for d; do
        if [ -n "$want" ]; then want=""; continue; fi
        case "$d" in
          --full) full=1 ;;
          --signal|--pidfile|--parent|--pgroup|--group|--session|--terminal|--euid|--uid|--ns|--nslist|--delimiter) want=1 ;;
          --*) ;;
          -[dgGPstuUFr]) want=1 ;;
          -*f*) full=1 ;;
          -*) ;;
          *) [ "$full" = 1 ] && [[ "$d" != *'['* ]] && { hit=$line; return 0; }; break ;;
        esac
      done
      break
    done
  done <<< "$command_text"
  return 1
}

# Absolute paths assigned at the very start of the command (`S=/abs; W=$S/wt; cd $W`).
# This is an allow-list: the leading run of plain assignments always runs in this shell,
# in order. After it, the rest of the command may use a name only as `$NAME` or `${NAME}`.
# Any other appearance of the name, and any spelling that can set a variable without
# naming it plainly, drops every resolved name, so the guard fails closed as before.
declare -A known_vars=()
expand_known() {
  local p=$1 n
  case "$p" in *\'*) printf '%s' "$p"; return ;; esac   # no expansion inside single quotes
  for n in "${!known_vars[@]}"; do p=${p//\$\{$n\}/${known_vars[$n]}}; done
  for n in "${!known_vars[@]}"; do
    while [[ "$p" =~ ^(.*)\$$n([^A-Za-z0-9_].*)?$ ]]; do p=${BASH_REMATCH[1]}${known_vars[$n]}${BASH_REMATCH[2]}; done
  done
  printf '%s' "$p"
}
# Prints the absolute literal path a raw assignment value names; fails on anything else.
literal_value() {
  local v=$1
  case "$v" in *\'*) return 1 ;; esac
  v=$(expand_known "$v")
  case "$v" in \"*\") v=${v:1:${#v}-2} ;; esac
  case "$v" in *'$'*|*'`'*|*\"*|*\'*|*'*'*|*'?'*|*'['*|*'~'*|*[[:space:]]*) return 1 ;; /*) printf '%s' "$v" ;; *) return 1 ;; esac
}
# Names bash sets by itself, and words that set or rename a variable without `NAME=`.
special_var='^(_|PWD|OLDPWD|IFS|HOME|PATH|CDPATH|REPLY|OPTARG|OPTIND|RANDOM|SRANDOM|SECONDS|LINENO|PPID|UID|EUID|SHLVL|HOSTNAME|PIPESTATUS|BASH.*|FUNCNAME|GROUPS|COMP.*|EPOCH.*)$'
var_writer='(^|[^A-Za-z0-9_])(read|mapfile|readarray|printf|declare|typeset|local|export|unset|eval|source|alias|enable|builtin|command|set|shopt|getopts|let|coproc|trap|exec)([^A-Za-z0-9_]|$)'
scan_leading_vars() {
  local rest=$1 re='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=("[^"$`]*"|[^[:space:];&|`"'"'"'()<>#]+)[[:space:]]*(;|&&|$)' v n tail whole val sep
  while [[ "$rest" =~ $re ]]; do
    whole=${BASH_REMATCH[0]} n=${BASH_REMATCH[1]} val=${BASH_REMATCH[2]} sep=${BASH_REMATCH[3]}
    [[ "$n" =~ $special_var ]] && { known_vars=(); return 0; }
    if v=$(literal_value "$val"); then known_vars[$n]=$v; else unset 'known_vars[$n]'; fi
    rest=${rest:${#whole}}
    [ -n "$sep" ] || break
  done
  # The rest: comments, heredocs, background jobs, word splitting, indirection and the
  # writer words above can all change a value or hide a command, so none of them resolves.
  if [[ "$rest" == *'#'* || "$rest" == *'<<'* || "$rest" == *'${!'* || "$rest" == *'+='* \
        || "$rest" =~ (^|[^&>|])\&([^&>]|$) || "$rest" =~ $var_writer || "$rest" =~ (^|[^A-Za-z0-9_])(IFS|for|select|\.)([^A-Za-z0-9_]|$) ]]; then
    known_vars=(); return 0
  fi
  for n in "${!known_vars[@]}"; do
    tail=${rest//\$\{$n\}/}
    while [[ "$tail" =~ ^(.*)\$$n([^A-Za-z0-9_].*)?$ ]]; do tail=${BASH_REMATCH[1]}${BASH_REMATCH[2]}; done
    [[ "$tail" =~ (^|[^A-Za-z0-9_])$n([^A-Za-z0-9_]|$) ]] && unset "known_vars[$n]"
  done
  return 0
}

# Prints the directory a literal path token names, relative to $1. Fails on a
# token the shell would expand or split: `$`, a backtick, `~user`, an inner quote.
literal_dir() {
  local p
  p=$(expand_known "$2")
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
# and unsure (why this parser cannot follow the push). A `cd` inside an if, case or
# loop, and a push inside a loop or beside a function definition, are unsure.
git_subs=(); push_args=(); push_dir=""; push_count=0; non_git=""; unsure=""; dyn=""; hidden_git=""
push_word='(^|[^[:alnum:]_-])push([^[:alnum:]_-]|$)'
push_re='(^|[^[:alnum:]_.-])git[^;&|]*[[:space:]]push([^[:alnum:]_-]|$)'
# Walks $1 from quote state $qs ("", "'" or '"') and leaves the state at its end in $qs.
qs=""
quote_walk() {
  local s=$1 i ch esc=""
  for ((i = 0; i < ${#s}; i++)); do
    ch=${s:i:1}
    if [ -n "$esc" ]; then esc=""; continue; fi
    case "$qs" in
      "'") [ "$ch" != "'" ] || qs="" ;;
      '"') case "$ch" in '\') esc=1 ;; '"') qs="" ;; esac ;;
      *) case "$ch" in '\') esc=1 ;; "'") qs="'" ;; '"') qs='"' ;; esac ;;
    esac
  done
}

scan_git() {
  local raw seg tok sub skip dir base=$1 cd_unknown="" block=0 loop=0 func="" t opened depth=0 prior inq was found
  while IFS= read -r raw; do
    inq=$qs; quote_walk "$raw"                   # inq: the segment starts inside quotes
    t=${raw//[^(]/}; opened=${#t}; t=${raw//[^)]/}; prior=$depth   # subshell depth across lines
    depth=$((depth + opened - ${#t})); [ "$depth" -ge 0 ] || depth=0
    [[ "$raw" =~ (^|[[:space:]])(function[[:space:]]|[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\(\)) ]] && func=1
    seg=${raw//[()]/ }                           # a subshell around a segment
    sub=""; skip=""; dir=""; was=$unsure; found=""
    set -- $seg
    while [ $# -gt 0 ]; do                       # words before the command word
      case "$1" in
        '{'|'}'|'!'|builtin|command|time|'then'|'else'|'elif'|'do') ;;
        'if'|'case') block=$((block + 1)) ;;
        'for'|'while'|'until'|'select') block=$((block + 1)); loop=$((loop + 1)) ;;
        'fi'|'esac') [ "$block" -gt 0 ] && block=$((block - 1)) ;;
        'done') [ "$block" -gt 0 ] && block=$((block - 1)); [ "$loop" -gt 0 ] && loop=$((loop - 1)) ;;
        *) break ;;
      esac
      shift
    done
    case "${1:-}" in
      '$'*) [ -n "$inq" ] || dyn=1 ;;            # a command word built from a variable
      eval|source|.) cd_unknown="eval or source before the push" ;;
      pushd|popd) cd_unknown="$1"; continue ;;
      cd)
        if [ "$opened" -gt 0 ] || [ "$prior" -gt 0 ]; then cd_unknown="cd inside a subshell"
        elif [ -n "$inq" ]; then cd_unknown="cd inside quotes"
        elif [ "$block" -gt 0 ]; then cd_unknown="cd inside an if, case or loop"
        elif [ $# -ge 2 ] && [[ "$2" != -* ]] && dir=$(literal_dir "$base" "$2"); then base=$dir
        else cd_unknown="cd to a path the guard cannot resolve"; fi
        continue ;;
    esac
    while [ $# -gt 0 ]; do
      tok=$1; shift
      case "$tok" in
        '{'|'}') continue ;;                     # a group around the segment
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
        tok=${tok//[\"\']/}                        # git "push" runs push
        git_subs+=("$tok")
        if [ "$tok" = push ]; then
          found=1; push_count=$((push_count + 1)); push_dir=${dir:-$base}; push_args=("$@")
          [ -n "$cd_unknown" ] && unsure=$cd_unknown
          [ "$loop" -gt 0 ] && unsure="push inside a loop"
          [ -n "$inq" ] && unsure="a push inside quotes"
        elif [[ "$raw" =~ (\$\(|\`)(.*)$ ]] && [[ "${BASH_REMATCH[2]}" =~ $push_re ]]; then
          found=1; git_subs+=(push); push_count=$((push_count + 1)); unsure="a push inside a command substitution"
        fi
        break
      fi
    done
    # An unreadable git word (`-C "${W:-a b}"`) can swallow the push that follows it, or
    # expand to one that an earlier assignment holds (`W="/r push"; git -C $W`).
    if [ "$sub" = git ] && [ -z "$found" ] && [ "$unsure" != "$was" ] && [[ "$cmd" =~ $push_word ]]; then hidden_git=$unsure; fi
    [ "$sub" = git ] || non_git+="$raw"$'\n'
  done <<< "$segment_text"
  if [ -n "$func" ] && [ "$push_count" -gt 0 ]; then unsure="push beside a function definition"; fi
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

run_in_background=$(printf '%s' "$input" | jq -r '.tool_input.run_in_background // false')
if [ "$run_in_background" != true ] && is_leading_sleep; then
  msg=$(cat <<'EOF'
Blocked: a leading sleep of 10 s or more, or of a length the guard cannot read:
  HIT

CLAUDE.md "Important Reminders": to wait for another process, start that process
with run_in_background and act on its completion notification. In a sub-agent, run
that process in the foreground instead, in steps that each end within the 10-minute
Bash timeout. A timer you need (wait, then act) runs as one run_in_background call.
EOF
)
  deny "${msg/HIT/$hit}"
fi

if is_self_matching_pgrep; then
  msg=$(cat <<'EOF'
Blocked: pgrep -f / pkill -f with a plain pattern:
  HIT

The shell that runs this command carries the whole command line, so the pattern
always matches that shell: pgrep always finds a process, and pkill kills the shell
(exit 144).

Use the PID: start the process with run_in_background or `cmd & pid=$!`, then
`kill $pid`. Or match the process name: `pgrep -x <name>`. Or put a bracket in the
pattern so it cannot match itself: pkill -f '[v]iberank'.
EOF
)
  deny "${msg/HIT/$hit}"
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
scan_leading_vars "$cmd"
scan_git "${cwd:-$PWD}"
pushes=""
is_git_push && pushes=1
# A push the token walk missed: inside quotes (`bash -c 'git push'`), eval, and
# the like. Only non-git segments are searched, so `git stash push` stays clear.
[[ "$non_git" =~ $push_re ]] && pushes=1
# A push that only appears after expansion: an unreadable git word that swallowed it, or
# a variable set to push (`P=push`, `W=/repo:push`) beside a variable command word or git word.
hidden=$hidden_git
assign_push='(^|[;&|[:space:]])[A-Za-z_][A-Za-z0-9_]*=["'"'"']?([^;&|[:space:]"'"'"']*[^[:alnum:]_;&|[:space:]-])?push(["'"'"';&|[:space:]]|$)'
if [ -z "$hidden" ] && { [ -n "$unsure" ] || [ -n "$dyn" ]; } && [[ "$cmd" =~ $assign_push ]]; then
  hidden=${unsure:-a command word built from a variable}
fi
[ -z "$hidden" ] || pushes=1
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
[ -z "$hidden" ] || unsure_deny "$hidden"
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
git -C "$push_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1

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
  # Optional Git queries return 1 for an absent value; other failures stay fatal.
  optional_git() {
    local rc=0
    git -C "$push_dir" "$@" || rc=$?
    [ "$rc" = 1 ] && return 0
    return "$rc"
  }
  # A configured refspec or push.default=matching pushes refs nobody named. With no
  # remote named, git picks it: branch pushRemote, remote.pushDefault, branch remote, origin.
  if [ -z "$remote" ]; then
    br=$(optional_git symbolic-ref -q --short HEAD)
    if [ -n "$br" ]; then remote=$(optional_git config --get "branch.$br.pushRemote"); fi
    if [ -z "$remote" ]; then remote=$(optional_git config --get remote.pushDefault); fi
    if [ -z "$remote" ] && [ -n "$br" ]; then remote=$(optional_git config --get "branch.$br.remote"); fi
    remote=${remote:-origin}
  fi
  push_default=$(optional_git config --get push.default)
  remote_push=""
  if git -C "$push_dir" config --get-all "remote.$remote.push" >/dev/null; then
    remote_push=1
  else
    rc=$?
    [ "$rc" = 1 ] || exit "$rc"
  fi
  if [ "$push_default" = matching ] || [ -n "$remote_push" ]; then
    unsure_deny "the push config names the refs"
  fi
  git -C "$push_dir" rev-parse -q --verify 'HEAD^{commit}' >/dev/null || {
    rc=$?
    [ "$rc" = 1 ] && exit 0   # no commit: nothing to send
    exit "$rc"
  }
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
