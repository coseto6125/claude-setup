# Changelog

Tagged versions start at v0.1.0. The history before it is untagged: see the git log for the
initial import, the live-config sync, and the skills README rebuild.

## v0.1.3 — 2026-09-17

### Added

- `skills/simplify/codex-review.sh`: runs the cross-family codex review as one background
  call. It launches `codex exec` read-only, waits for the CLI's `tokens used` line, writes
  the report that follows it once the log holds still, and ends the codex process group:
  TERM first, KILL after 5 seconds. The report file is emptied before any check that can
  fail and filled through a temp file, and only exit 0 means it holds this run's report
  (an unwritable report path keeps its old content and exits 64). Exit 0 report written, 2 codex ended without a
  report or the report could not be written, 3 timeout, 4 codex missing or not logged in,
  64 usage or an unwritable report path. The log is deleted on success and kept on
  failure. The caller waits on the harness notification instead of writing a loop.
  36 checks in `skills/simplify/tests/`.
- `hooks/prune-scratchpad.sh`, wired on `SessionStart`: deletes session temp directories
  (`scratchpad/`, `tasks/`) under `$CLAUDE_CODE_TMPDIR` in which nothing changed for 14
  days. The current session and anything touched inside the window are kept; a symlinked
  project or session directory is never followed; a session whose scan errors is kept;
  `SCRATCH_KEEP_DAYS` is read as decimal (`08` is eight days). It forks and prints
  nothing, because hook stdout lands in the session context. `--dry-run` lists without
  deleting. 27 checks in `hooks/tests/`. Known gap: a session idle for the whole window
  that resumes between the scan and the delete loses what it just wrote. First run on the
  author's machine: 770 directories, 13.2 GB.

### Changed

- `skills/simplify/CHECKLIST.md`, Quality rung 13 *Prose drift*: the reviewer lists every
  name and value the diff changes, reads the docstrings and caller comments, and greps
  README, docs, CLAUDE.md, SKILL.md, `--help` strings and example configs for the old and
  the new name. A stale sentence outside the diff is a finding, and its fix may edit any
  file of the repo. A changelog entry for a past release stays as written. Measured on
  sonnet, n=5 per arm: a stale README usage line was reported at 70 or above 5/5 with the
  rung and 1/5 without it; a stale docstring 5/5 against 2/5. Rows in
  `skills/validate-prompt-rules/measurements.md`.
- `skills/simplify/SKILL.md`, Phase 5: the fix gate drops from 70 to 50. The 50 anchor
  already means a real finding, and across 30 sonnet reviews every finding scored 50 to 69
  was real (missing tests, an unvalidated key lookup, a duplicated literal list, a stale
  comment). A finding whose evidence the re-check cannot confirm goes under
  "Scanned, not acted on" instead of being fixed.
- `skills/simplify/SKILL.md`: the reviewer preamble says the graph's rename-only proof covers
  code only, so *Prose drift* still searches the text for a renamed name.
- `skills/simplify/SKILL.md`: the cross-family section calls `codex-review.sh` and maps its
  exit codes to `cross-family skipped: <reason>`. The inline launch command, the run tag
  and the wait loop are gone.
- `skills/simplify/CHECKLIST.md`: two duplicated passages removed, the per-skill gate
  numbers and the Spec axis's "reports on its own" sentence that `SKILL.md` already holds.
  A/B on sonnet, n=15 per arm, showed no drop on any predeclared target (rows in
  `skills/validate-prompt-rules/measurements.md`).
- `skills/peer-agent/DETACHED-LAUNCH.md`, *Waiting*: a detached peer's finish is the CLI's
  `tokens used` line, and the process only answers whether it died. Across 20 local codex
  logs every finished run held that line once and every unfinished run held none, and a
  finished codex stayed alive 70 minutes after its report. The section carries a bounded
  loop with a bracketed, run-named `pgrep`: it exits 2 when codex dies without a report and
  3 on timeout, and waits up to 60 seconds for the log to hold still before it reads the
  report, because the report reaches the log after the marker. The launch note that Bash kills a
  `run_in_background` call at 120s now says the cut may no longer hold (two waits lived 70
  minutes), and keeps the foreground launch as the measured recipe.
- `skills/peer-agent/RESUME.md`: a finished run is told by its one `tokens used` line, not by
  the last lines of the log, since the report appears both before and after that line.
- `skills/validate-prompt-rules`: `agentic.sh` and `preloaded.sh` exit 2 with their usage
  line when `WORK` is unset or lacks its base inputs (`base/` and `task.txt`, or the probes
  directory). `agentic.sh` also exits 2 naming the missing `rules/<arm>.txt` for a selected
  arm; `preloaded.sh` checks only that the rules directory exists, and honours `PROBES_DIR`
  and `RULES_DIR`. Before, both fell back to the current directory and started runs there.
- `CLAUDE.md`, Dispatch: a "Phase" bullet sizes an implementer's phase to end under 150k
  tokens of context; a brief names the line range for files over 200 lines and pastes the
  batching instances. Evidence in `maintainer-notes.md` and
  `skills/validate-prompt-rules/measurements.md`.
- `settings.example.json`: regenerated; it wires `prune-scratchpad.sh`.
- README: the hooks paragraph counts fourteen scripts and nine wired, and describes
  `prune-scratchpad.sh`; the Token footprint note no longer claims a direction.

### Removed from the published history

- Private project names and one internal database port were rewritten out of every commit,
  commit message and PR description. Tags v0.1.0 to v0.1.2 were moved to the rewritten
  commits, so a clone made before 2026-09-17 no longer shares history with `main`.

## v0.1.2 — 2026-09-11

### Changed

- `CLAUDE.md`, Test Discipline: "(happy path + key edge cases)" is replaced by a class
  sentence: name each input's atypical states and each dependency's failure; every state
  named is a test. The measured "write a test that reproduces the bug" sentence is untouched.
- `CLAUDE.md`, Dispatch: a Haiku or Sonnet implementer gets the seven-item edge list pasted
  into its prompt; the Haiku tier applies a rule only when the rule lists its instances; the
  Sonnet tier gets reuse or extraction named in the brief; a count in a delegate's report
  comes from a command's output.
- `agents/lite-scan.md`: line numbers only from tool output, counts only from a command.
- `skills/preflight`: user-invoked (`disable-model-invocation: true`).
- `skills/simplify/CHECKLIST.md`, Altitude: a second site judged unaffected is a finding
  unless the report names the consumers of its value that were checked.
- `skills/writing-for-agents`: a "Class and instance" lever under Leading words.
- `skills/validate-prompt-rules`: three sections — a control that preloads the deployed
  CLAUDE.md, an agentic probe for "go and look" behaviour, and a both-ways classifier check —
  with `preloaded.sh`, `agentic.sh` and `measurements.md`. `ab.sh` carries a note that its
  isolation leaks `~/.claude`.

### Added

- `skills/context-audit` and `skills/preflight`.

### Measured

Rows and method in `skills/validate-prompt-rules/measurements.md`; wording provenance in
`maintainer-notes.md`. Against a control that preloads this CLAUDE.md, 25 of 26 one-line
design rules were saturated on opus, and an agentic plant was fixed 3/3 by the control. The
one line that moved: the edge-case class sentence, opus 0/5 to 5/5 in abstract and instance
form alike; haiku 0/5 to 4/5 only with the instances listed. n=5 pilots; re-probe at n≥15
before treating any of it as settled.

## v0.1.1 — 2026-09-09

### Changed

- `skills/eli5`: three lines outside Step 1 still described the age-5 default that v0.1.0
  removed. Part 1 now says it applies when the request names an audience *and* when it names
  none, `/eli5 <topic>` is documented as working with or without a `for <audience>` clause,
  and the worked example labels its audience `Age 5 (the request carries no audience signal)`
  rather than `Age 5 (default)`.
- `skills/peer-agent`: acknowledge every delivery `check --wait` returns, heartbeats included.
  The wait re-delivers the oldest unacknowledged delivery and holds the ones behind it, so a
  loop that only greps for `worker_done` reads the same heartbeat forever while the report
  sits queued. Measured 2026-09-09: a task showed `completed` for 12 minutes before an
  `--ack` let the report through.

### Measured

The two `pending` rows in v0.1.0 are filled in. Both hold, which is the point: the rewrite
moved the engineer and the inferred-reader branches and left the others alone.

| probe | no skill | before | after |
|---|---|---|---|
| analogy drawn from a 15-year-old's world | 0/15 | 14/15 | 15/15 |
| manager named, impact and a decision to take | 11/15 | 13/15 | 15/15 |

The manager row's control is 11/15 here against the 6/15 recorded in v0.1.0; the control arm
was re-run alongside the `before` arm so all three numbers come from one round.

The open question v0.1.0 left — whether `A bare ELI5 with no other signal means age 5` reads
as the token alone rather than as a request carrying no audience signal — was measured and
answered: the shipped wording scores 14/15, a reworded version 13/15, against a 9/15 control.
The wording stays.

## v0.1.0 — 2026-09-09

### Changed

- `skills/eli5` Part 1 now infers the reader, and applies the ELI5 method at that reader's
  own level.
  - Step 1 opens on two axes. **Level** is the vocabulary the audience sets. **Method** is
    how the explanation is built, and it holds for every audience. An engineer keeps
    `mutex`, `backpressure` and `p99`, explained the ELI5 way.
  - The age-5 default is gone. When the request names no audience, the skill infers the
    reader from the material and from the words the user wrote, then names that reader in
    one line. A bare `ELI5` with no other signal still means age 5.
  - The frontmatter description follows the same change.

Measured on haiku with `validate-prompt-rules`, n=15 per arm, isolated through
`CLAUDE_CONFIG_DIR`:

| probe | no skill | before | after |
|---|---|---|---|
| engineer named, terms kept and ELI5 method used | 3/15 | 5/15 | 14/15 |
| no audience named, question written in engineer vocabulary | 13/15 | 5/15 | 14/15 |
| analogy drawn from a 15-year-old's world | 0/15 | pending | 15/15 |
| manager named, impact and a decision to take | 6/15 | pending | 15/15 |
| 8-year-old named, no surviving jargon | 15/15 | 15/15 | 15/15 |

The second row is why the default changed. `default to "Age 5"` scored 5/15 against a 13/15
no-skill control on a question written in engineer vocabulary: it pulled an engineer's
question down to a child's explanation.

### Measured, and left unchanged

- The four audience tables. Replacing them with one class-level sentence dropped the
  15-year-old analogy probe from 15/15 to 2/15, against a 0/15 control.
- The three worked examples. Removing them dropped the same probe from 28/30 to 17/30 over
  two rounds.
- Part 2 rule 9, which caps a list at five items. It is inert on haiku (5/15 against a 4/15
  control) and load-bearing on opus (14/15 against 8/15). Opus is the deployed reader, so
  the rule stays.

`pending` marks a before-number still running: those two probes were built after the
rewrite, so the old wording has not been through them yet. Both rows report the new
wording against a no-skill control, which is what the row's other two numbers say.
