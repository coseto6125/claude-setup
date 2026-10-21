---
name: diagnose
description: Debug a failing test or wrong output. Invoke the moment it appears, before your first edit, and again when a fix leaves it red or a brief says debug.
---

Fit check first: when the failure output names the cause and one fix turns it green, make that fix and stop here.

Otherwise diagnose in phases. Each phase ends on its done condition. Skip a phase only when you state why.

Redact every secret in each command, output and artifact you show. Write `<REDACTED>` in its place, and keep credentials in env vars.

## 1. Build the loop

A **red-capable** loop is one command that drives the real bug path and asserts the user's exact symptom. It goes red on this bug and green after the fix. "Runs without error" is not red-capable.

Build it in this order of preference:

1. A failing test at a seam that reaches the bug.
2. A curl or HTTP script against a running dev server.
3. A CLI call with a fixture input, diffed against a known-good output.
4. A Playwright script that asserts on the DOM, console or network.
5. A captured request, payload or log, replayed through the code path.
6. A minimal harness that calls the bug path with one function call.
7. A property loop over random inputs, for "sometimes wrong output".
8. `git bisect run` with the loop, when a known-good commit exists.
9. A differential run: the same input through the old and the new version.

When a human must act, drive the steps with `computer-use` or Playwright. Otherwise ask the user to run them and paste the output.

Measure the loop with `bash ~/.claude/skills/diagnose/scripts/loop.sh 5 <command>`. For a flaky bug, use 50 runs and raise the red rate with repetition, parallel runs or injected delays.

**Done:** `loop.sh` prints `verdict=always-red`, or a stable red rate for a flaky bug, and `median_ms` in seconds, not minutes. The first red output matches the user's symptom. Until then, read code only to build the loop, never to form a theory.

When you cannot build a loop, stop. List what you tried, and ask the user for an environment that reproduces it, a redacted artifact (HAR, log dump, recording), or permission for temporary instrumentation.

## 2. Minimise

Cut inputs, callers, config, data and steps one at a time. Run the loop after each cut, and keep only the parts that keep it red.

**Done:** removing any one remaining part turns the loop green.

## 3. Hypothesise

Write 3 to 5 ranked hypotheses before you test any. Each one states its prediction: "If X is the cause, then changing Y makes the bug disappear."

Show the ranked list to the user, then continue without waiting.

To find where a wrong value comes from, run `ecp flow --file <path> --line <n> --column <n> --direction backward`. To find who reaches the bug path, run `ecp impact --target <symbol> --direction upstream`.

## 4. Instrument

Test one hypothesis per probe, and change one variable at a time. Prefer a debugger or REPL. Otherwise log at the boundaries that separate the hypotheses.

Tag every debug log with one prefix, such as `[DEBUG-a4f2]`.

For a performance regression, profile instead of logging: `cProfile` per CLAUDE.md Core Philosophy, and the `rust-perf` skill for Rust.

When every hypothesis fails, write a new ranked list from the probe results. After two failed fix attempts, run codex for an independent hypothesis (CLAUDE.md Dispatch).

## 5. Fix

Write the regression test before the fix, at a seam where the test runs the call chain the bug took. A test below that chain proves nothing. When no such seam exists, report that as a finding (CLAUDE.md Test Discipline).

1. Turn the minimised repro into that test, and watch it fail.
2. Apply the fix, and watch the test pass.
3. Run the Phase 1 loop on the original scenario.

## 6. Clean up

**Done** when all of these hold:

- The Phase 1 loop on the original scenario gives `verdict=always-green`.
- The regression test passes, or the report names the missing seam.
- `git diff | grep -n 'DEBUG-'` prints nothing.
- Throwaway harnesses are deleted.
- The confirmed cause is in the commit message, and in the PR body section that `pr-body` names for it.
