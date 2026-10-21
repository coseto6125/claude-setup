#!/usr/bin/env python3
"""
Keep the tool-output persistence threshold patched across Claude Code updates.

Claude Code writes a tool result to disk and replaces it with a preview card once
the result exceeds a threshold constant (minified, so its name changes per build).
The stock 50000 is high enough that ordinary sessions never reach it; 2000 measured 2-6% cheaper on replayed transcripts, with
no prefix rewrite and therefore no prompt-cache cost.

Runs as a SessionStart hook. The running binary is already mapped into memory, so
a patch applies from the NEXT launch on. A marker file keeps the steady-state
cost at one readlink, one stat and one small read.

The new binary is written beside the old one and renamed over it, so sessions
already running keep their original inode and are unaffected.

Not defended against: an installer replacing the target between the read and the
rename. The identity re-check before the rename narrows that window but cannot
close it without a lock the installer also takes.
"""

from __future__ import annotations

import contextlib
import os
import re
import subprocess
import sys
import time
from hashlib import blake2b
from pathlib import Path

LAUNCHER = Path.home() / ".local/bin/claude"
MARKER = Path.home() / ".claude/.tool-persist-patched"

# A staged file older than this belongs to a run that was killed, not to a peer.
STALE_S = 3600

# The replacement value MUST be the same byte length as the stock one,
# or the bundle's internal offsets break. A trailing space pads a shorter number;
# a leading zero would be an octal literal and a SyntaxError under strict mode.
#
# The anchor carries the threshold's neighbours as well as the threshold itself.
# `=50000,` alone would also match an unrelated constant of the same value, and
# `--version` would still pass after corrupting it. The Bash floor (4000) and the
# Bash ceiling (128000) sit in the same declaration and identify this constant.
#
# The preview kept in the card (stock 2000) is deliberately NOT patched. Cutting it to
# 500 saved a further 1-3% but left the model roughly 9-18 lines of a truncated
# payload: enough to identify the output, not enough to use it. The stock 2000
# gives 24-57 lines. Compound Bash commands make this worse, since their output
# is several sections concatenated and a small preview lands mid-section.
#
# The anchor matches the declaration by shape, not by name: the minifier renames
# the constants per build (`QM` in 2.1.295, `pH` in 2.1.296, `mD` in 2.1.300), and
# 2.1.296 inserted an unrelated `=1e4` (the Edit tool's originalFile cap) between
# the threshold and the Bash floor.
# Group 1 is the threshold's value, stock or already patched.
ANCHOR = re.compile(rb"var [\w$]{1,4}=(50000|2000 ),(?:[\w$]{1,4}=\w+,){0,2}[\w$]{1,4}=4000,[\w$]{1,4}=128000,")
STOCK, PATCHED = b"50000", b"2000 "
assert len(STOCK) == len(PATCHED)

FINGERPRINT = blake2b(repr((ANCHOR.pattern, PATCHED)).encode(), digest_size=6).hexdigest()


def stamp(target: Path) -> str:
    """
    Marker content: what was patched, which bytes, and with which patch set.

    Size and mtime identify the file itself, so reinstalling the same version
    over a patched binary is noticed instead of being read as already done.
    Editing ANCHOR or PATCHED changes the fingerprint, so a target skipped under one patch
    set is retried under the next.
    """
    st = target.stat()
    return f"{target.name}:{st.st_size}:{st.st_mtime_ns}:{FINGERPRINT}"


def marker_says(value: str) -> bool:
    try:
        return MARKER.read_text().strip() == value
    except OSError:
        return False


def record(value: str) -> None:
    """Write the marker, or carry on without one rather than failing the hook."""
    try:
        MARKER.write_text(value)
    except OSError as exc:
        print(f"patch-tool-persist: cannot write the marker ({type(exc).__name__})", file=sys.stderr)


def reap(target: Path) -> None:
    """Remove staged files a killed run left behind, whatever version named them."""
    cutoff = time.time() - STALE_S
    for leftover in target.parent.glob(".*.patching.*"):
        with contextlib.suppress(OSError):
            if leftover.stat().st_mtime < cutoff:
                leftover.unlink()


def discard(staged: Path) -> None:
    """Drop a staged file; a cleanup failure must not mask why we are cleaning up."""
    with contextlib.suppress(OSError):
        staged.unlink(missing_ok=True)


def apply(data: bytes, name: str) -> bytes | None:
    """
    Return the patched bytes, `data` itself when it is already patched, or None
    with the reason printed.

    Exactly one anchor match is required whatever its value. A build holding both
    a stock and a patched declaration would otherwise be read as done with the
    real constant untouched.
    """
    if len(hits := list(ANCHOR.finditer(data))) != 1:
        print(f"patch-tool-persist: anchor found {len(hits)}x in {name}, skipping", file=sys.stderr)
        return None
    if hits[0].group(1) == PATCHED:
        return data
    start, end = hits[0].span(1)
    return data[:start] + PATCHED + data[end:]


def main() -> int:
    try:
        target = LAUNCHER.resolve(strict=True)
        current = stamp(target)
    except OSError:
        return 0
    if marker_says(current) or marker_says(f"{current}:failed"):
        return 0

    reap(target)
    try:
        data = target.read_bytes()
    except OSError as exc:
        print(f"patch-tool-persist: cannot read the target ({type(exc).__name__})", file=sys.stderr)
        return 0

    if (patched := apply(data, target.name)) is None:
        record(f"{current}:failed")
        return 0
    if patched is data:
        record(current)
        return 0

    staged = target.with_name(f".{target.name}.patching.{os.getpid()}")
    try:
        staged.write_bytes(patched)
        staged.chmod(target.stat().st_mode)
        # A list argv, never a shell string, and the only executable named is the
        # copy we just wrote.
        proc = subprocess.run([str(staged), "--version"], capture_output=True, timeout=60, check=False)  # ruff: ignore[subprocess-without-shell-equals-true]
        starts = proc.returncode == 0
        untouched = stamp(target) == current
    except (OSError, subprocess.SubprocessError) as exc:
        discard(staged)
        print(f"patch-tool-persist: {type(exc).__name__}", file=sys.stderr)
        return 0

    if not starts:
        discard(staged)
        print("patch-tool-persist: patched binary failed to start, discarding", file=sys.stderr)
        record(f"{current}:failed")
        return 0
    if not untouched:
        # An installer replaced the target while we were staging. Its bytes win.
        discard(staged)
        print("patch-tool-persist: target changed under us, discarding", file=sys.stderr)
        return 0

    try:
        # Rename is atomic and leaves the old inode intact for running sessions.
        staged.replace(target)
    except OSError as exc:
        discard(staged)
        print(f"patch-tool-persist: {type(exc).__name__}", file=sys.stderr)
        return 0

    record(stamp(target))
    print(f"patch-tool-persist: patched {target.name}; active from the next launch", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
