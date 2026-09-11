#!/usr/bin/env bash
# UserPromptSubmit hook: inject relevant eywa principles into context.
# Uses /smart-query for llama-server-orchestrated multi-domain search.
# Session cache prevents re-injecting same principle within a session.

set -eo pipefail

CACHE_DIR="$HOME/.eywa/session_cache"
SERVER="http://127.0.0.1:8788"
RECENT_LOG="$HOME/.eywa/recent.log"
# Failure sentinel: "<consecutive_failures> <epoch_of_first_failure>". The
# statusline raises a persistent alarm from this. Silent skip is the right
# behaviour for one bad query, but a *sustained* skip is an outage — and an
# unobserved one ran for 5 days (Jul 22-27) because the only signal was
# recent.log, which keeps rotating stale successes and reads as healthy.
HEALTH_FAIL="$HOME/.eywa/health.fail"

# ── Read stdin JSON ──
input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0
# A harness-authored prompt has no question in it. 40 of 162 injections in one
# four-day sample answered a <task-notification>, and what they retrieved was
# the notification format itself.
harness_envelope='^[[:space:]]*<(task-notification|agent-message|teammate-message)'
[[ "$prompt" =~ $harness_envelope ]] && exit 0

# ── Preceding conversation ──
# Most prompts cannot be searched alone: 57% of real interactive prompts are 40
# chars or fewer ("繼續", "好", "B"), and a bare "B" retrieves whatever else
# mentions the letter. Judged over three such prompts, prompt-only scored 18%
# precision@5 against 58% with the preceding turns attached.
#
# Send the tail unconditionally and let the server budget it (build_search_text):
# a prompt that already carries signal gets none. Only plain-string user content
# and assistant text blocks are taken — tool_result payloads are the file dumps
# and command output that drowned the query in the first place.
history=""
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ]; then
    history=$(tail -n 400 "$transcript_path" 2>/dev/null | jq -rs '
        map(select(.type == "user" or .type == "assistant")
            | select(.isSidechain != true)
            | (.message.content) as $c
            | if ($c | type) == "string" then "\(.type): \($c)"
              elif ($c | type) == "array" then
                ($c | map(select(.type == "text") | .text) | join(" ")) as $t
                | if ($t | length) > 0 then "\(.type): \($t)" else empty end
              else empty end)
        | .[-8:] | join("\n") | .[-4000:]' 2>/dev/null)
    # Sliced inside jq, by codepoint. `tail -c` would cut mid-UTF-8 and hand
    # `jq --arg` a byte sequence it cannot encode.
fi

# ── Session cache ──
mkdir -p "$CACHE_DIR"
find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
CACHE_FILE="$CACHE_DIR/$session_id.txt"
touch "$CACHE_FILE"

# ── Smart query (llama-server plans domains → concurrent search → rerank) ──
# If the server is down, do nothing — never cold-start the CLI here, because
# `eywa query` will reload bge-m3 (~450MB) + the LLM model from scratch on every
# invocation. Repeated cold-starts under a hook trigger have caused fork-bomb /
# OOM-restart loops in the past. Server unreachable = skip injection silently.
# Pass cwd so the server can apply the project-aware boost.
#
# rerank defaults to true on the eywa side — LLM rerank picks the top-K
# principles for the actual prompt instead of raw RSF score. Cap the wait so a
# slow rerank or long prompt can't stall prompt-submit. curl's --max-time fires
# first, returning empty → silent skip; the outer `timeout` is a 1 s backstop.
# 2026-08-21: 5 s → 10 s with the move to Bonsai-27B-Q1_0. That model is
# prefill-bound at 785 tok/s against Qwen3.5-4B's 1376, so smart-query runs
# ~1.8-2.4 s idle instead of ~1.2 s. Idle still cleared 5 s, but a capture batch
# sharing the GPU costs 2-3x, which put the contended case over the old cap and
# turned every overrun into a "failed injection" alarm.
# ROLLBACK with the model: put 6/5 back.
# -f: HTTP >=400 (LLM down, busy queue, …) exits non-zero → silent skip.
# Without it a 500's TOON body (`error: "…"`) parses as a principle line and
# gets injected into every new session's context — observed Jul 22–27.
if ! results=$(timeout 11 curl -sf --max-time 10 "$SERVER/smart-query" \
    -X POST -H 'Content-Type: application/json' \
    -d "$(jq -n --arg c "$prompt" --arg cwd "$PWD" --arg h "$history" \
          '{context: $c, cwd: $cwd, history: $h}')" 2>/dev/null); then
    # Transport or HTTP >=400. Keep the FIRST failure's epoch so the statusline
    # can report how long this has been broken, not just that it is.
    read -r _n _since < "$HEALTH_FAIL" 2>/dev/null || true
    # Treat a non-numeric field as absent. Feeding one to `$(( ))` writes a bash
    # arithmetic error to stderr from a UserPromptSubmit hook, and the `>`
    # truncates the file before printf dies — so the outage counter resets to
    # zero, which is the exact silence this sentinel exists to break.
    [[ "$_n" =~ ^[0-9]+$ ]] || _n=0
    [[ "$_since" =~ ^[0-9]+$ ]] || _since=$(date +%s)
    printf '%s %s\n' "$(( _n + 1 ))" "$_since" > "$HEALTH_FAIL"
    exit 0
fi
rm -f "$HEALTH_FAIL"

# Empty body with a 2xx is a legitimate "nothing relevant matched" — not an
# outage, so the sentinel stays cleared.
[ -z "$results" ] && exit 0

# ── Parse output lines (format: [key][category] content, [key][category][domain] content) ──
# The leading bracket group is the principle key. It is what the reader cites
# when an injected principle changes what it does, and it is what this cache
# dedups on — an exact identity, in place of the 80-char slug of the rendered
# line that stood in before the key was there.
selected_lines=()
new_keys=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Skip HTML comments (conflict notices)
    [[ "$line" == "<!--"* ]] && continue
    # Skip error payloads that arrive with a 200 status (belt for curl -f)
    [[ "$line" == error:* || "$line" == "error "* ]] && continue
    [[ "$line" != \[*\]* ]] && continue
    # Prefix with "k:" so the key never starts with "-" (which grep treats as
    # an option flag — the bug that silently broke dedup for months).
    pkey=${line%%]*}
    cache_key="k:${pkey#[}"
    [ "$cache_key" = "k:" ] && continue
    grep -Fxq -- "$cache_key" "$CACHE_FILE" 2>/dev/null && continue
    selected_lines+=("$line")
    new_keys+=("$cache_key")
done <<< "$results"

[ "${#selected_lines[@]}" -eq 0 ] && exit 0

# ── Output inject results ──
# stdout → injected into Claude's context (eats tokens, Claude reads it).
# RECENT_LOG → in-TUI statusline rotates through it (no extra tokens).
printf '[eywa]\n'
printf '%s\n' "${selected_lines[@]}"
ts="$(date '+%H:%M:%S')"
{
    for line in "${selected_lines[@]}"; do
        printf 'INJECT %s %s\n' "$ts" "$line"
    done
} >> "$RECENT_LOG"
# Keep recent.log to the last 50 entries so the statusline rotation has a
# bounded window — older entries roll off automatically.
tail -50 "$RECENT_LOG" > "$RECENT_LOG.tmp" 2>/dev/null && mv "$RECENT_LOG.tmp" "$RECENT_LOG"
printf '%s\n' "${new_keys[@]}" >> "$CACHE_FILE"
