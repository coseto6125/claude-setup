#!/usr/bin/env python3
"""Measure a page with Lighthouse, N runs per target, and report medians.

Why this exists: a single Lighthouse run is not a measurement. On a normal dev
machine the same unchanged build scores anywhere in a ~30 point band, so one
before-run and one after-run cannot tell an improvement from noise. This runs
every target N times and reports the median, which is stable enough to act on.

Two targets at once is the point: serve the old build and the new build side by
side and compare them under identical conditions. Comparing your local build
against the deployed site instead mixes in a different network path.

Usage:
    lighthouse_ab.py before=dist-old after=dist-new
    lighthouse_ab.py after=dist --runs 5 --form-factor desktop
    lighthouse_ab.py live=https://example.com/ local=dist

Each target is `label=<dir-or-url>`. Directories are served over localhost.
No external Python dependencies; Node and npx must be on PATH.
"""

import argparse
import http.server
import json
import os
import shutil
import socketserver
import statistics
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

CATEGORIES = {
    "performance": "Performance",
    "accessibility": "Accessibility",
    "best-practices": "Best Practices",
    "seo": "SEO",
}

# displayed as `label: audit-id`
METRICS = {
    "FCP": "first-contentful-paint",
    "LCP": "largest-contentful-paint",
    "TBT": "total-blocking-time",
    "CLS": "cumulative-layout-shift",
    "SI": "speed-index",
}


def find_chrome() -> str:
    """Locate a Chrome/Chromium that Lighthouse can actually drive.

    The WSL trap: `/usr/bin/google-chrome` there is often a shim for the Windows
    binary. It launches, prints a DevTools endpoint, and Lighthouse then fails
    with ECONNREFUSED because the debugging port lives on the Windows side of
    the network boundary. Any path under /mnt/ is therefore rejected, and a
    Playwright-managed Linux Chromium is preferred when one is installed.
    """
    env = os.environ.get("CHROME_PATH")
    if env and Path(env).exists():
        return env

    pw = sorted(Path.home().glob(".cache/ms-playwright/chromium-*/chrome-linux/chrome"))
    if pw:
        return str(pw[-1])

    for name in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable"):
        found = shutil.which(name)
        if found and not os.path.realpath(found).startswith("/mnt/"):
            return found

    sys.exit("No usable Chrome found. Install Chromium, or set CHROME_PATH to a Linux binary.")


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory: str) -> tuple[str, socketserver.TCPServer]:
    """Serve `directory` on a free localhost port. Returns (url, server)."""
    handler = lambda *a, **kw: QuietHandler(*a, directory=directory, **kw)  # noqa: E731
    server = socketserver.TCPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{server.server_address[1]}/", server


def run_lighthouse(url: str, out: Path, form_factor: str, chrome: str) -> dict:
    """One Lighthouse run. `npx --yes lighthouse` always fetches the newest
    release, which is the same engine PageSpeed Insights runs."""
    cmd = [
        "npx", "--yes", "lighthouse", url,
        "--quiet",
        "--output=json",
        f"--output-path={out}",
        "--chrome-flags=--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu",
    ]
    if form_factor == "desktop":
        cmd.append("--preset=desktop")
    # Run from a temp dir, not the caller's cwd. chrome-launcher sees WSL and takes its
    # Windows branch, so the throwaway Chrome profile is built at a `C:\\Users\\...` path.
    # That is not a real path on Linux, so mkdirSync creates ONE directory whose literal
    # name contains backslashes, relative to cwd. Measure a repo from its own root and
    # every run leaves an untracked `C:\\Users\\...\\lighthouse.12345` folder behind.
    # Clearing TMP / TEMP / LOCALAPPDATA does not help: the fallback path is Windows-shaped
    # too. Moving cwd puts the junk somewhere harmless whichever branch it takes.
    env = {**os.environ, "CHROME_PATH": chrome}
    subprocess.run(
        cmd, env=env, cwd=tempfile.gettempdir(),
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return json.loads(out.read_text(encoding="utf-8"))


def numeric(report: dict, audit_id: str):
    node = report["audits"].get(audit_id) or {}
    return node.get("numericValue")


def fmt(audit_id: str, value) -> str:
    if value is None:
        return "—"
    if audit_id == "cumulative-layout-shift":
        return f"{value:.3f}"
    if audit_id == "total-blocking-time":
        return f"{value:.0f}ms"
    return f"{value / 1000:.1f}s"


def table(rows: list[list[str]]) -> str:
    widths = [max(len(str(r[i])) for r in rows) for i in range(len(rows[0]))]
    return "\n".join("  ".join(str(c).ljust(widths[i]) for i, c in enumerate(r)) for r in rows)


def diagnose(report: dict) -> None:
    """The four reads that tell you WHERE the time goes.

    Score alone never says what to change, and the audit titles are misleading
    on their own — an "unused CSS" warning next to a 3-second style-recalc is
    pointing at the wrong file.
    """
    audits = report["audits"]

    work = audits.get("mainthread-work-breakdown", {}).get("details", {}).get("items", [])
    if work:
        print("\n  Main-thread work (script-heavy and layout-heavy pages need opposite fixes):")
        for item in sorted(work, key=lambda i: -i["duration"])[:5]:
            print(f"    {item['duration']:>8.0f} ms  {item['group']}")

    blocking = audits.get("render-blocking-insight", {}).get("details", {}).get("items", [])
    if blocking:
        print("\n  Render-blocking:")
        for item in blocking[:5]:
            print(f"    {item.get('wastedMs', 0):>8.0f} ms  {item.get('url', '')[:78]}")

    tasks = audits.get("long-tasks", {}).get("details", {}).get("items", [])
    if tasks:
        print("\n  Long tasks:")
        for item in tasks[:5]:
            print(f"    {item['duration']:>8.0f} ms  {(item.get('url') or '')[:78]}")

    metrics = audits.get("metrics", {}).get("details", {}).get("items", [{}])[0]
    sim, obs = metrics.get("largestContentfulPaint"), metrics.get("observedLargestContentfulPaint")
    if sim and obs:
        print(f"\n  LCP simulated {sim:.0f} ms vs observed {obs:.0f} ms")
        if sim > obs * 3:
            print("    Gap this wide means the simulator put a slow request on the LCP")
            print("    dependency chain. Real users are fine; the score is not. Take the")
            print("    resource off the critical path rather than trying to speed it up.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("targets", nargs="+", metavar="label=dir-or-url")
    parser.add_argument("--runs", type=int, default=3, help="runs per target (default 3; use 5 on a noisy machine)")
    parser.add_argument("--form-factor", choices=("mobile", "desktop"), default="mobile")
    parser.add_argument("--path", default="", help="path appended to served directories, e.g. pricing/")
    parser.add_argument("--keep", metavar="DIR", help="keep the raw JSON reports here")
    args = parser.parse_args()

    chrome = find_chrome()
    print(f"Chrome:      {chrome}")
    print(f"Form factor: {args.form_factor}   Runs per target: {args.runs}\n")

    # Absolute: run_lighthouse runs the CLI from a temp cwd, so a relative --keep path
    # would write the reports next to the junk instead of where the caller asked.
    workdir = (Path(args.keep) if args.keep else Path(tempfile.mkdtemp(prefix="lh-ab-"))).resolve()
    workdir.mkdir(parents=True, exist_ok=True)

    servers, results = [], {}
    try:
        for target in args.targets:
            if "=" not in target:
                sys.exit(f"Expected label=dir-or-url, got {target!r}")
            label, where = target.split("=", 1)

            if where.startswith(("http://", "https://")):
                url = where
            else:
                directory = Path(where).resolve()
                if not directory.is_dir():
                    sys.exit(f"Not a directory: {directory}")
                url, server = serve(str(directory))
                servers.append(server)
                url += args.path

            print(f"Measuring {label} ({url}) ", end="", flush=True)
            reports = []
            for run in range(1, args.runs + 1):
                reports.append(run_lighthouse(url, workdir / f"{label}-{run}.json", args.form_factor, chrome))
                print(".", end="", flush=True)
            print(" done")
            results[label] = reports
    finally:
        for server in servers:
            server.shutdown()

    header = ["target"] + [CATEGORIES[c] for c in CATEGORIES] + list(METRICS)
    rows = [header]
    for label, reports in results.items():
        row = [label]
        for category in CATEGORIES:
            scores = [round(r["categories"][category]["score"] * 100) for r in reports if category in r["categories"]]
            row.append(f"{statistics.median(scores):.0f} {sorted(scores)}" if scores else "—")
        for audit_id in METRICS.values():
            values = [v for v in (numeric(r, audit_id) for r in reports) if v is not None]
            row.append(fmt(audit_id, statistics.median(values)) if values else "—")
        rows.append(row)

    print("\n" + table(rows))
    print("\nEach score column is `median [all runs]`. A spread wider than ~10 points")
    print("means the median is still soft — re-run with --runs 5 before drawing a")
    print("conclusion, and never report a single run as a result.")

    for label, reports in results.items():
        print(f"\n=== {label} ===")
        diagnose(reports[len(reports) // 2])

    print(f"\nRaw reports: {workdir}")


if __name__ == "__main__":
    main()
