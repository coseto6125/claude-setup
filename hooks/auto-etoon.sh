#!/bin/bash
# Bash command 自動補 `| etoon`，把輸出 TOON 化省 token。
# etoon 自動偵測格式；不會壓的純文字 fallback passthrough，預設掛上不痛。
#
# Skip 規則（任一命中 → no-op，原命令照跑）：
#   1. 已含 `| etoon`，避免雙重套
#   2. 末尾 `&` 背景命令（pipe 吃成前景）或末尾 `;`（接 pipe 變語法錯誤）
#   3. 末段重導 `> file` / `>> file` — 輸出已寫檔，etoon 拿不到
#   4. 單一 shell builtin (cd / export / source / set ...) — pipe 開 subshell side-effect 失效
#   5. byte-exact diff (`git diff` / `diff`) — 全局 CLAUDE.md 明列例外
#   6. 明確要求 JSON (--format/--output/-o json、-json/--json、{{json .}}) — byte-exact 需求
#   7. heredoc `<<` — 接 pipe 會破壞結尾定界符

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# 1. 已含 etoon
if printf '%s' "$cmd" | grep -qE '\|\s*etoon(\s|$)'; then
    exit 0
fi

trimmed=$(printf '%s' "$cmd" | sed 's/[[:space:]]*$//')

# 2. 尾隨 `&`（pipe 會把背景吃成前景）或尾隨 `;`（`; | etoon` 是語法錯誤，
#    原命令完全不執行）
case "$trimmed" in *'&'|*';') exit 0 ;; esac

# 3. 末段含輸出重導
last_segment=$(printf '%s' "$trimmed" | awk -F'|' '{print $NF}')
if printf '%s' "$last_segment" | grep -qE '(^|[^<])>>?\s'; then
    exit 0
fi

# 4. 單一 shell builtin（無 compound）
if ! printf '%s' "$cmd" | grep -qE '[&|;]'; then
    first_word=$(printf '%s' "$cmd" | awk '{print $1}')
    case "$first_word" in
        cd|export|unset|alias|unalias|source|.|set|shopt|pushd|popd|exit|return|trap|exec|read|wait|kill)
            exit 0
            ;;
    esac
fi

# 5. byte-exact diff
if printf '%s' "$cmd" | grep -qE '^(git\s+diff|diff)\b'; then
    exit 0
fi

# 6. 明確要求 JSON 輸出 — 呼叫端要 byte-exact JSON（餵 jq / 測試斷言 / 格式
#    偵錯），TOON 化會改寫觀測結果、誤導格式偵錯。涵蓋：
#    --format/--output [=]json（含引號值）、-o json / -o=json / -ojson、
#    單雙 dash -json/--json（go test / terraform / gh，含 =fields 與緊鄰引號）、
#    Go template {{json .}}。過寬命中方向安全（只少省 token）。
if printf '%s' "$cmd" | grep -qE -- '--(format|output)[= ]["'\'']?json|-o[= ]?["'\'']?json|-{1,2}json([[:space:]"'\''=`]|$)|\{\{ *json'; then
    exit 0
fi

# 7. heredoc（`<<` 但非 `<<<` herestring）— 在最後一行接 `| etoon` 會讓結尾
#    定界符變成 `EOF | etoon`，heredoc 永不終結，定界符行被當內容執行
if printf '%s' "$cmd" | grep -qE '(^|[^<])<<([^<]|$)'; then
    exit 0
fi

new_cmd="$cmd | etoon"
jq -n --arg c "$new_cmd" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $c }
  }
}'
