#!/usr/bin/env bash
# SessionStart: warn when settings.json carries a standalone `rtk hook claude` entry.
# auto-etoon.sh calls rtk itself. Claude Code applies only one PreToolUse updatedInput,
# so a second rewriting hook silently drops either the rtk rewrite or the etoon pipe.
# `rtk init -g --auto-patch` re-adds that entry, and rtk's own missing-hook warning is suppressed.
settings="${1:-$HOME/.claude/settings.json}"
jq -e '[.hooks.PreToolUse[]? | .hooks[]? | .command // "" | select(test("^\\s*rtk hook claude\\s*$"))] | length > 0' \
    "$settings" >/dev/null 2>&1 || exit 0
msg="settings.json has a standalone 'rtk hook claude' PreToolUse entry (rtk init -g --auto-patch adds it). auto-etoon.sh already calls rtk; two rewriting hooks drop one rewrite. Remove that entry."
jq -nc --arg m "$msg" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}}'
