#!/usr/bin/env python3
"""
PostToolUseFailure hook: name a failure loop when it forms.

When a tool call fails with the same signature and the same error line for the third time
in one transcript, the hook adds a short note to Claude's context that says to switch
strategy. It fires once per loop key, on the third failure only, and keeps no state: it
counts the earlier failures in the transcript. The signature comes from the retro skill's failures.py, so this hook and
/retro count the same thing. An exit 1 that means "no match" (grep, diff, test ...) is not
a failure. Any error inside the hook prints nothing, so the hook never stops a call.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".claude" / "skills" / "retro"))

from failures import DIGITS, PATH, iter_failures, signature

THRESHOLD = 3
NO_MATCH = frozenset({"grep", "rg", "ugrep", "egrep", "fgrep", "diff", "cmp", "test", "[", "which", "pgrep", "git diff"})


def is_no_match(sig: str) -> bool:
    """Return True for a Bash exit 1 whose program uses exit 1 to mean "nothing found"."""
    if not (sig.startswith("Bash: ") and sig.endswith(" (exit 1)")):
        return False
    return sig.removeprefix("Bash: ").removesuffix(" (exit 1)") in NO_MATCH


def loop_key(sig: str, example: str) -> str:
    """Return the key that two failures share when they are the same failure: signature and error line."""
    return f"{sig} | {DIGITS.sub('N', PATH.sub('<path>', example))[:100]}"


def note(event: dict) -> str | None:
    """Return the note for this failure, or None when it is not the third with its loop key."""
    if event.get("is_interrupt"):
        return None
    sig, example = signature(event.get("tool_name", "?"), event.get("tool_input") or {}, event.get("error", ""))
    if is_no_match(sig):
        return None
    path = Path(event.get("transcript_path") or "")
    if not path.is_file():
        return None
    current = event.get("tool_use_id", "")
    key = loop_key(sig, example)
    prior = sum(1 for use_id, s, e in iter_failures(path) if use_id != current and loop_key(s, e) == key)
    if prior + 1 != THRESHOLD:
        return None
    return (
        f"Loop guard: `{sig}` has now failed {THRESHOLD} times in this session with the same error"
        f"{f' ({example})' if example else ''}. "
        "Switch strategy before the next attempt: re-read the whole error, name a new hypothesis, "
        "or run codex for an independent one."
    )


def main() -> int:
    try:
        text = note(json.load(sys.stdin))
    except Exception:
        return 0
    if text:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUseFailure", "additionalContext": text}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
