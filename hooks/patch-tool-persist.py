#!/usr/bin/env python3
"""
Keep the tool-output persistence threshold patched across Claude Code updates.

Claude Code writes a tool result to disk and replaces it with a preview card once
the result exceeds `G1` chars. The stock 50000 is high enough that ordinary
sessions never reach it; 2000 measured 2-6% cheaper on replayed transcripts, with
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
import subprocess
import sys
import time
from hashlib import blake2b
from pathlib import Path

LAUNCHER = Path.home() / ".local/bin/claude"
MARKER = Path.home() / ".claude/.tool-persist-patched"

# A staged file older than this belongs to a run that was killed, not to a peer.
STALE_S = 3600

# (search, replace) — the replacement MUST be the same byte length as the search,
# or the bundle's internal offsets break. A trailing space pads a shorter number;
# a leading zero would be an octal literal and a SyntaxError under strict mode.
#
# The search string carries `G1`'s neighbours as well as `G1` itself. `var
# G1=50000,` alone would also match a future build where `G1` is minified onto an
# unrelated constant of the same value, and `--version` would still pass after
# corrupting it. `REr` (the Bash floor) and `pSe` (the Bash ceiling) sit in the
# same declaration and are what make the window identify this constant.
#
# `S2e` (the preview kept in the card) is deliberately NOT patched. Cutting it to
# 500 saved a further 1-3% but left the model roughly 9-18 lines of a truncated
# payload: enough to identify the output, not enough to use it. The stock 2000
# gives 24-57 lines. Compound Bash commands make this worse, since their output
# is several sections concatenated and a small preview lands mid-section.
PATCHES: tuple[tuple[bytes, bytes], ...] = (
    (b"var G1=50000,REr=4000,pSe=128000,", b"var G1=2000 ,REr=4000,pSe=128000,"),
)

FINGERPRINT = blake2b(repr(PATCHES).encode(), digest_size=6).hexdigest()


def stamp(target: Path) -> str:
    """
    Marker content: what was patched, which bytes, and with which patch set.

    Size and mtime identify the file itself, so reinstalling the same version
    over a patched binary is noticed instead of being read as already done.
    Editing PATCHES changes the fingerprint, so a target skipped under one patch
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
    """Apply every patch, or return None with the reason printed."""
    for old, new in PATCHES:
        if len(old) != len(new):
            print(f"patch-tool-persist: length mismatch for {old[:24]!r}", file=sys.stderr)
            return None
        if (count := data.count(old)) != 1:
            print(f"patch-tool-persist: anchor found {count}x in {name}, skipping", file=sys.stderr)
            return None
        data = data.replace(old, new)
    return data


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

    # Both halves matter: the replacement present AND the original gone. A build
    # that happens to contain both would otherwise be recorded as done with the
    # real constant untouched.
    if all(new in data and old not in data for old, new in PATCHES):
        record(current)
        return 0

    if (patched := apply(data, target.name)) is None:
        record(f"{current}:failed")
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
