#!/usr/bin/env bash
# PreToolUse hook: block an unfiltered "remove all images" on podman or docker.
# Other sessions keep locally built images (CI matrix images, demo images) that cannot always be rebuilt.
# Blocked without --filter: `image prune -a`, `system prune -a`, `rmi -a`, `image rm -a` (also --all[=true]),
# and `rmi` on an id list from `$( )`, a backtick or xargs unless that listing carries -f/--filter. Exit 2 shows the reason.

set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Check each command segment on its own: a filter in one segment must not excuse another.
[[ "$cmd" == *podman* || "$cmd" == *docker* ]] || exit 0
blocked=""
# The tool word after a space, a path, a quote or a paren (/usr/bin/podman, bash -c "podman …").
tool_re='(^|[[:space:]/"'\''(])(sudo[[:space:]]+)?(podman|docker)[[:space:]]'
remove_re='(image|system)[[:space:]]+prune|image[[:space:]]+rm([[:space:]]|$)|[[:space:]]rmi([[:space:]]|$)'
all_re='(^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all(=true)?)([[:space:]"'\'')]|$)'
filter_re='[[:space:]]--filter[[:space:]=]'
listed_re='\$\(|`|(^|[[:space:]])xargs[[:space:]]'
listing_filter_re='images[^|)]*[[:space:]](-f|--filter)[[:space:]=]'   # images -f dangling=true -q
# Outer loop: one command per line (split on || ; &). Inner loop: one pipeline stage per line.
while IFS= read -r command; do
  command=${command%%[[:space:]]#*}             # a comment: the shell ignores the rest
  prev=""
  while IFS= read -r seg; do
    if [[ "$seg" =~ $tool_re ]] && [[ "$seg" =~ $remove_re ]] && ! [[ "$seg" =~ $filter_re ]]; then
      # An id list from a substitution, or from xargs after a pipe, removes everything unless
      # the listing that feeds it filters: inside the stage itself, or the stage before it.
      if [[ "$seg" =~ $all_re ]] || { [[ "$seg" =~ $listed_re ]] && ! [[ "$prev $seg" =~ $listing_filter_re ]]; }; then
        blocked="$seg"
        break 2
      fi
    fi
    prev=$seg
  done < <(printf '%s\n' "$command" | tr '|' '\n')
done < <(printf '%s\n' "$cmd" | sed -E 's/(\|\||;|&)/\n/g')

[ -z "$blocked" ] && exit 0

{
  echo "Blocked: an unfiltered 'remove all images' deletes images other sessions built and still use:"
  echo "  $blocked"
  echo "Prune only what is old enough to be unused, for example:"
  echo "  podman image prune -a --filter until=168h"
  echo "  podman image prune            (dangling images only)"
  echo "Remove one image by name: podman rmi <image>"
} >&2
exit 2
