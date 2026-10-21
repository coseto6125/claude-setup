#!/usr/bin/env bash
# PreToolUse(Bash): ecp's graph hits, plus the command that answers what they cannot.
# The hits are a d=1 slice. Blast radius, entry points and cross-file callers need
# `ecp impact`, so the hook hands over the exact command with the symbol filled in.
set -euo pipefail

ECP="${ECP_BIN:-$HOME/.local/bin/ecp}"
[ -x "$ECP" ] || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# ecp picks the repo from the session cwd. A command that cds into another repo first
# (`cd /other/repo && grep ...`) is about that repo, so hand ecp the target of that leading cd.
# A variable target ("$B"), a missing dir or an unparsable command keeps the session cwd.
target=""
if [[ $cmd =~ (^|[\;\&\|\(])[[:space:]]*cd[[:space:]] ]]; then
  target=$(python3 -I -c '
import os, shlex, sys
cmd, cwd = sys.argv[1], sys.argv[2] or os.getcwd()
lex = shlex.shlex(cmd, posix=False, punctuation_chars=True)
lex.whitespace_split = True
try:
    toks = list(lex)
except ValueError:
    sys.exit()
# Assignments may come first. Then the cd must be its whole segment and end in ; or &&.
# Anything else before it (a command, ||, a pipe, a subshell) leaves the session cwd.
seg, segs = [], []
for tok in toks:
    if tok in (";", "&&", "||", "|", "|&", "&", "(", ")", ";;"):
        segs.append((seg, tok))
        seg = []
    else:
        seg.append(tok)
segs.append((seg, ";"))
for seg, sep in segs:
    if seg and sep in (";", "&&") and all("=" in w and not w.startswith("=") for w in seg):
        continue
    if len(seg) == 2 and seg[0] == "cd" and sep in (";", "&&"):
        arg = seg[1]
        if arg[:1] in ("\x22", "\x27"):
            arg = arg[1:-1] if len(arg) > 1 and arg[-1] == arg[0] else ""
        else:
            arg = os.path.expanduser(arg)
        path = os.path.normpath(os.path.join(cwd, arg)) if arg else ""
        if path and os.path.isdir(path):
            print(path)
    break
' "$cmd" "$(printf '%s' "$input" | jq -r '.cwd // ""')" 2>/dev/null) || target=""
  [ -n "$target" ] && input=$(printf '%s' "$input" | jq -c --arg d "$target" '.cwd = $d')
fi

out=$(printf '%s' "$input" | "$ECP" hook pre-tool-use --claude-code 2>/dev/null) || exit 0
[ -n "${out//[[:space:]]/}" ] || exit 0

context=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""')
[ -n "$context" ] || { printf '%s' "$out"; exit 0; }

# Inject only when a hit is an identifier the command itself names. A hit counts when its name has an
# inner underscore or camelCase and appears as a whole word in the command. Plain words (debug, info,
# create, node) matched log greps and git calls: 2026-09-23, 50 sessions, 1,710 injections, 1 in 20
# relevant; this gate keeps 211 of them.
symbol=""
while IFS= read -r name; do
  printf '%s' "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' || continue
  printf '%s' "$name" | grep -Eq '[A-Za-z0-9]_[A-Za-z0-9]|[a-z][A-Z]' || continue
  printf '%s' "$cmd" | grep -Fqw -- "$name" || continue
  symbol=$name; break
done < <(printf '%s\n' "$context" | sed -n 's/^[[:space:]]\{2\}\([^[:space:]]*\) (.*/\1/p')
[ -n "$symbol" ] || exit 0

run_in=""
[ -n "$target" ] && run_in="cd $(printf '%q' "$target") && "
read -r -d '' nudge <<EOF || true
$context
  -- Those callers are the d=1 slice. Full blast radius, cross-file callers and entry points:
     ${run_in}ecp impact --target $symbol --direction upstream --repo .
EOF

printf '%s' "$out" | jq -c --arg c "$nudge" '.hookSpecificOutput.additionalContext = $c'
