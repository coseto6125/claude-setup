#!/usr/bin/env bash
# Idle-guard (UserPromptSubmit): if the gap since the last activity exceeds the
# threshold, the prompt cache is likely cold -> block this submission once as a
# heads-up. The warning rides on decision:block.reason, shown to the user only,
# never entering Claude's context.
#
# Every submission updates the activity timestamp BEFORE the block branch, so a
# blocked prompt's resubmit measures ~0 idle and passes — no flag file needed.
# Updating here (not only on Stop) keeps the baseline correct even when Stop
# never fires (interrupt / errored turn), which otherwise causes false blocks.
#
# State is keyed by session_id so parallel sessions don't collide. A fresh
# session has no .last file -> idle defaults to 0 -> no false block.

IDLE_THRESHOLD=3300   # 55 min. Claude-subscription cache TTL is 60 min.

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null || echo default)
[ -z "$sid" ] && sid=default
# State lives under the user's own directory, never a world-writable /tmp path.
# The session id falls back to "default", so a shared /tmp would give any local
# account a predictable name to pre-empt with a symlink.
state_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-idle-guard"
mkdir -p "$state_dir" 2>/dev/null || exit 0
last_file="$state_dir/${sid}.last"

now=$(date +%s)
last=$(cat "$last_file" 2>/dev/null)
[ -z "$last" ] && last="$now"
idle=$(( now - last ))

printf '%s' "$now" > "$last_file"

if [ "$idle" -gt "$IDLE_THRESHOLD" ]; then
  mins=$(( idle / 60 ))
  printf '{"decision":"block","reason":"⏸ 已閒置約 %d 分鐘，prompt cache (1h TTL) 可能已冷，這一輪會是未快取的慢回合。再送一次即正常送出（此提醒不寫入對話）。"}\n' "$mins"
fi
exit 0
