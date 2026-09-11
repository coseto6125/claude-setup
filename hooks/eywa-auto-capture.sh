#!/usr/bin/env bash
# Stop hook: send the latest turn to eywa for autonomous capture, with the
# commands and output that turn actually produced.
#
# Why the [EVIDENCE] section exists:
#   Sending assistant prose alone gave the extractor nothing to quote, so it
#   paraphrased the prose and invented the specifics — one stored principle
#   placed a hook's behaviour at "line 48" of a file whose line 48 does nothing
#   of the sort. The extractor now has to return a verbatim span for every
#   principle, and eywa drops the entry when that span is absent from what we
#   sent. Commands and their output heads are what make a real quote available.

# No `set -e`: every step below is intentionally fallible (grep finds no match
# on a tool-only turn, jq parses empty, etc.) and already guarded with
# `|| true` / `// empty`. `-e` turned those expected non-zero exits into a
# "Stop hook failed (No stderr output)" — exactly the false alarm this removes.
# The script ends in an explicit `exit 0`; that is the intended contract.
set -o pipefail

# Byte-cut, then drop the partial UTF-8 sequence the cut can leave behind — a
# half character would reach the extractor as U+FFFD inside a span it is being
# asked to quote verbatim.
# `iconv -c` drops invalid bytes but still reports the truncated tail on stderr,
# which a Stop hook surfaces as a spurious failure — discard it.
clip() { head -c "$1" | iconv -c -f utf-8 -t utf-8 2>/dev/null; }

# Bytes of one turn we are willing to read and hold. See the slice below.
# Overridable so a test can drive the cut path without a 60MB fixture.
WINDOW=${EYWA_TURN_WINDOW:-4194304}

input=$(cat)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

context=""

# ── Preferred path: parse the .jsonl transcript for the latest turn ──
# A "turn" starts at the most recent user message whose content is a plain
# string (not a tool_result wrapper) and runs through end-of-file. Anything
# in between (assistant text + tool_use / tool_result entries) is the
# assistant's full answer for that turn.
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ]; then
    last_user_lineno=$(grep -an '"role":"user","content":"' "$transcript_path" | tail -1 | cut -d: -f1)
    if [ -n "$last_user_lineno" ]; then
        # Strip NUL bytes inline — JSONL transcripts carry embedded NULs (pasted
        # binary / base64), which bash $(...) can't preserve and would otherwise
        # warn on. gsub at the source is one pass, no extra `tr` pipe.
        #
        # WINDOW caps what one turn may cost. Unbounded, a 61MB transcript whose
        # turn starts at line 1 held the whole slice in a bash variable: 7.2s wall
        # and 490MB RSS for a Stop hook, against 0.29s / 27MB once capped.
        #
        # The cap keeps the turn's FIRST line and its LAST bytes, because that is
        # where the meaning is: line 1 is the user's prompt, and the answer plus
        # the tool calls it rests on are at the end. Capping from the front
        # instead dropped the assistant's reply and the hook posted nothing.
        # A byte cut can leave a partial JSON line at the front of the tail, so
        # drop that line — but only when the tail really was cut.
        user_line=$(awk -v from="$last_user_lineno" 'NR == from { gsub(/\0/, ""); print; exit }' "$transcript_path")
        rest=$(awk -v from="$last_user_lineno" 'NR > from { gsub(/\0/, ""); print }' "$transcript_path" | tail -c "$WINDOW")
        # Ask the parser, not the byte count: `$(...)` strips trailing newlines,
        # so a length test against WINDOW misses the cut by one byte and leaves
        # the fragment in — which makes `jq -rs` fail and the whole turn vanish.
        printf '%s' "$rest" | head -1 | jq -e . >/dev/null 2>&1 || rest=$(printf '%s' "$rest" | tail -n +2)
        slice=$(printf '%s\n%s\n' "$user_line" "$rest")

        user_text=$(printf '%s\n' "$slice" | head -1 \
            | jq -r '.message.content // empty | if type == "string" then . else "" end' 2>/dev/null || true)
        # A turn the harness opened — a task notification, a teammate's message —
        # carries no knowledge of its own, and the extractor reads the envelope
        # instead: "a task notification carries a task-id and a status field" was
        # stored and re-injected nine times in four days.
        harness_envelope='^[[:space:]]*<(task-notification|agent-message|teammate-message)'
        [[ "$user_text" =~ $harness_envelope ]] && exit 0

        # Pull every text block from every assistant message in this turn,
        # joined in order.
        assistant_text=$(printf '%s\n' "$slice" | jq -rs '
            map(select(.type == "assistant") | .message.content // [] | .[]?
                | select(.type == "text") | .text // empty)
            | join("\n\n")
        ' 2>/dev/null || true)

        # Quotable ground truth: each tool call as `$ Tool: arg` and each result
        # as `> head`. Whitespace is collapsed and each entry capped at 180
        # chars, so one runaway output can't crowd out the rest of the turn.
        # The last 24 entries are the ones the answer was actually built on.
        evidence=$(printf '%s\n' "$slice" | jq -rs '
            map(.message.content // [] | if type == "array" then .[] else empty end)
            | map(
                if .type == "tool_use" then
                  "$ \(.name): \((.input.command // .input.file_path // .input.pattern // .input.query // "") | tostring | gsub("\\s+"; " ") | .[0:180])"
                elif .type == "tool_result" then
                  "> \((if (.content|type) == "array" then (.content | map(.text // "") | join(" ")) else (.content // "" | tostring) end) | gsub("\\s+"; " ") | .[0:180])"
                else empty end)
            | map(select(. != "$ : " and . != "> "))
            | .[-24:] | join("\n")
        ' 2>/dev/null || true)

        # No text = pure tool-call turn. Skip outright — don't pay the LLM
        # round-trip just to have it conclude "nothing to capture".
        if [ -n "$assistant_text" ]; then
            context=$(printf '[USER PROMPT]\n%s\n\n[EVIDENCE]\n%s\n\n[ASSISTANT RESPONSE]\n%s\n' \
                "$(printf '%s' "$user_text" | clip 800)" \
                "$(printf '%s' "$evidence" | clip 2000)" \
                "$assistant_text")
        fi
    fi
fi

# ── Fallback: stdin assistant_message field (older hook contract) ──
if [ -z "$context" ]; then
    context=$(printf '%s' "$input" | jq -r '.assistant_message // empty' 2>/dev/null)
fi

[ -z "$context" ] && exit 0
[ "${#context}" -lt 30 ] && exit 0

# Fire-and-forget: /auto-capture queues the work server-side and returns 202
# "queued" in ~5ms — the LLM fan-out (extract + classify + persist) runs as a
# background task inside eywa-server, NOT here. So this curl is a synchronous
# enqueue, not a wait-for-result.
#
# Capture outcomes are logged server-side by eywa.capture, so we no longer mirror
# them into CAPTURE_LOG / RECENT_LOG here — `queued` is all the client ever sees.
#
# Fenced code blocks are dropped from the prose: they are the assistant's own
# restatement of code, and the [EVIDENCE] section already carries the real
# thing. 6000 chars fits the server's 8192-token extraction slot with room for
# the generation, even for CJK text.
cleaned_context=$(printf '%s' "$context" | awk '/^```/ { in_code = !in_code; if (in_code) print "[CODE BLOCK REMOVED]"; next } !in_code { print }')
truncated=$(printf '%s' "$cleaned_context" | clip 6000)
curl -s --max-time 5 http://127.0.0.1:8788/auto-capture \
    -X POST -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$truncated" '{text: $t}')" >/dev/null 2>&1 || true

exit 0
