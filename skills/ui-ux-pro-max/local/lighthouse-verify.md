# Lighthouse Verification

Measure a page before and after a change, with numbers you can defend. Use this
whenever a task is about page speed, whenever you touch fonts / CSS delivery /
above-the-fold markup, and whenever a user brings a PageSpeed Insights report.

Run it. Never estimate a score, and never report an improvement you did not measure.

## Run it

```bash
python3 ~/.claude/skills/ui-ux-pro-max/local/lighthouse_ab.py before=<dir-or-url> after=<dir-or-url>
```

Each target is `label=<dir-or-url>`; directories get served on localhost. Options:
`--runs N` (default 3), `--form-factor desktop`, `--path pricing/`, `--keep <dir>`
to retain the raw JSON.

To produce a real before-build: `git stash push -u`, build, copy `dist` aside,
`git stash pop`, build again. Compare the two directories, not your local build
against the deployed site — different network paths are not a controlled comparison.

## Read it

The summary prints `median [all runs]` per category, then per target: main-thread
work by group, render-blocking resources, long tasks, and simulated vs observed LCP.

Four reads, in order:

1. **Main-thread work group.** `scriptEvaluation` high means ship less JS or split
   the work. `styleLayout` high means the page costs too much to lay out — the fix
   is `content-visibility: auto` on offscreen sections, a smaller DOM, or fewer
   forced reflows, and shipping less JS will not help.
2. **Render-blocking.** Everything listed sits between the user and first paint.
   A third-party stylesheet here is the single most common cause of a bad FCP.
3. **Long tasks.** The URL is the attributed script, not always the real cause —
   a long task attributed to a framework runtime is often the browser laying out
   the page that the framework just built.
4. **Simulated vs observed LCP.** The score uses simulated. When simulated is
   several times observed, the simulator has put a slow request on the LCP
   dependency chain: real users are fine and the score is not. Take the resource
   off the critical path instead of trying to make it faster.

## Traps

**One run is not a measurement.** The same unchanged build has scored 61, 75 and
90 on consecutive runs on an idle machine. Always compare medians of 3+ runs, and
re-run with `--runs 5` when the spread is wider than ~10 points.

**WSL Chrome.** `/usr/bin/google-chrome` under WSL is usually a shim for the
Windows binary; Lighthouse launches it and then dies with `ECONNREFUSED` because
the debugging port is on the Windows side. The script rejects any binary under
`/mnt/` and prefers a Playwright-managed Linux Chromium. Override with `CHROME_PATH`.

**`media="print"` does not take a stylesheet off the critical path.** The
`<link media="print" onload="this.media='all'">` trick still leaves the request in
the simulator's dependency graph, and the score swings wildly. Injecting the
`<link>` from an `addEventListener('load', …)` handler does take it off.

**Prerendered sites bake injected tags back in.** A prerenderer that snapshots
`document.documentElement.outerHTML` after `load` captures anything a load handler
appended to `<head>` — including the very `<link>` you moved off the critical path,
which then ships as a static render-blocking tag. Mark such nodes so the
prerenderer strips them, and grep the built HTML to confirm.

**Web fonts are usually the whole story.** A Google Fonts URL bundling a CJK family
returns 400+ `@font-face` rules (≈500 KB of CSS). Self-host the Latin families as
variable-font woff2 (~30 KB each, same origin) and keep the CJK family on Google's
unicode-range slicing, loaded after `load`.

**A metric can get worse for a good reason.** Total Blocking Time is measured from
FCP. When a page was blocked for 12 s, its layout cost landed before FCP and TBT
read 0; fix the blocking and the same work now lands after FCP and TBT jumps. The
work did not appear — it became visible. Say so, then fix it too.
