#!/bin/bash
# Bash command 先交給 `rtk hook claude` 改寫，再自動補 `| etoon`，把輸出 TOON 化省 token。
# rtk 由這支串起來，settings.json 不另掛 rtk：兩個 hook 各回 updatedInput 時只有一份生效，
# 而 updatedInput 會整份取代 tool_input，所以 description / timeout / run_in_background 要帶著走。
# 別跑 `rtk init -g --auto-patch`：rtk 只認得字串完全等於 `rtk hook claude` 的 hook，
# 會再加一條獨立的 rtk hook，兩邊又互蓋。`rtk init --show` 回報 hook missing 是預期的。
# etoon 自動偵測格式；不會壓的純文字 fallback passthrough，預設掛上不痛。
#
# Skip 規則（任一命中 → 不補 etoon，rtk 的改寫照用）：
#   1. 已含 `| etoon`，避免雙重套
#   2. 末尾 `&` 背景命令（pipe 吃成前景）或末尾 `;`（接 pipe 變語法錯誤）
#   3. 末段重導 `> file` / `>> file` — 輸出已寫檔，etoon 拿不到
#   4. 單一 shell builtin (cd / export / source / set ...) — pipe 開 subshell side-effect 失效
#   5. byte-exact diff (`git diff` / `diff`) — 全局 CLAUDE.md 明列例外
#   6. 明確要求 JSON (--format/--output/-o json、-json/--json、{{json .}}) — byte-exact 需求
#   7. heredoc `<<` — 接 pipe 會破壞結尾定界符

skip_etoon() {
    local cmd=$1 trimmed last_segment first_word

    # 1. 已含 etoon
    if printf '%s' "$cmd" | grep -qE '\|\s*etoon(\s|$)'; then
        return 0
    fi

    trimmed=$(printf '%s' "$cmd" | sed 's/[[:space:]]*$//')

    # 2. 尾隨 `&`（pipe 會把背景吃成前景）或尾隨 `;`（`; | etoon` 是語法錯誤，
    #    原命令完全不執行）
    #    或尾隨 `\`（續行，`\ | etoon` 會把空白當成參數）
    case "$trimmed" in *'&'|*';'|*'\') return 0 ;; esac

    # 3. 末段含輸出重導
    last_segment=$(printf '%s' "$trimmed" | awk -F'|' '{print $NF}')
    if printf '%s' "$last_segment" | grep -qE '(^|[^<])>>?\s'; then
        return 0
    fi

    # 4. 單一 shell builtin（無 compound）
    if ! printf '%s' "$cmd" | grep -qE '[&|;]'; then
        first_word=$(printf '%s' "$cmd" | awk '{print $1}')
        case "$first_word" in
            cd|export|unset|alias|unalias|source|.|set|shopt|pushd|popd|exit|return|trap|exec|read|wait|kill)
                return 0
                ;;
        esac
    fi

    # 5. byte-exact diff
    if printf '%s' "$cmd" | grep -qE '^(git\s+diff|diff)\b'; then
        return 0
    fi

    # 6. 明確要求 JSON 輸出 — 呼叫端要 byte-exact JSON（餵 jq / 測試斷言 / 格式
    #    偵錯），TOON 化會改寫觀測結果、誤導格式偵錯。涵蓋：
    #    --format/--output [=]json（含引號值）、-o json / -o=json / -ojson、
    #    單雙 dash -json/--json（go test / terraform / gh，含 =fields 與緊鄰引號）、
    #    Go template {{json .}}。過寬命中方向安全（只少省 token）。
    if printf '%s' "$cmd" | grep -qE -- '--(format|output)[= ]["'\'']?json|-o[= ]?["'\'']?json|-{1,2}json([[:space:]"'\''=`]|$)|\{\{ *json'; then
        return 0
    fi

    # 7. heredoc（`<<` 但非 `<<<` herestring）— 在最後一行接 `| etoon` 會讓結尾
    #    定界符變成 `EOF | etoon`，heredoc 永不終結，定界符行被當內容執行
    if printf '%s' "$cmd" | grep -qE '(^|[^<])<<([^<]|$)'; then
        return 0
    fi
    return 1
}

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# rtk 失敗（含 exit 2 擋下命令）時原樣交回它的輸出與 exit code，不再補 etoon
rtk_out=""
if command -v rtk >/dev/null 2>&1; then
    rtk_out=$(printf '%s' "$input" | rtk hook claude)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%s' "$rtk_out"
        exit "$rc"
    fi
fi

# Skip 規則看原命令：rtk 改寫後 `git diff` 變成 `rtk git diff`，規則 5 就認不出來
if skip_etoon "$cmd"; then
    [ -n "$rtk_out" ] && printf '%s\n' "$rtk_out"
    exit 0
fi

if [ -z "$rtk_out" ]; then
    jq -c '{hookSpecificOutput: {hookEventName: "PreToolUse",
            updatedInput: (.tool_input + {command: ((.tool_input.command | sub("\n+$"; "")) + " | etoon")})}}' <<<"$input"
elif printf '%s' "$rtk_out" | jq -e '.hookSpecificOutput.updatedInput.command | strings' >/dev/null 2>&1; then
    printf '%s' "$rtk_out" | jq -c '.hookSpecificOutput.updatedInput.command |= (sub("\n+$"; "") + " | etoon")'
else
    # rtk 回了別的決定（沒有改寫指令）：照原樣交回，不混進 etoon
    printf '%s\n' "$rtk_out"
fi
