# Resuming a peer that was cut off

A detached peer belongs to the session that launched it. When that session crashes or is torn down,
the peer dies with it. Relaunching from the brief throws away every file the peer already read.
`codex exec resume` puts it back into the same transcript.

## Tell a cut-off run from a finished one

A finished run holds one `tokens used` line. With stdout and stderr in one log, the report appears
twice: in the trace before that line, and again after it, as the log's last lines. A cut-off run has
no `tokens used` line and ends inside a tool trace, most often on a `hook: PostToolUse Completed`
line. Check for the line before you conclude anything about the findings:

```bash
grep -cx 'tokens used' "$SCRATCH/codex-<task>.log"   # 1 finished, 0 cut off
```

A log that ends mid-trace carries no verdict. Treat "no findings reported" from such a log as "no
report", never as "clean".

## The session id

Every run prints its id in the banner the CLI writes at the top of the log:

```bash
grep -m1 "session id:" "$SCRATCH/codex-<task>.log"
```

That id is the handle back into the run. It stays valid after the process is gone, so you recover it
from the log at any time.

## The resume line

```bash
setsid codex exec --sandbox read-only --skip-git-repo-check -C "$PWD" \
  -m gpt-6-astra -c model_reasoning_effort="medium" resume <session-id> \
  "The run was cut off before you printed the report. Finish the remaining rungs of the brief and print the complete final report now, in the format the brief names." \
  < /dev/null > "$SCRATCH/codex-<task>-r2.log" 2>&1 & disown
```

Three things this line gets right:

- **Every flag sits before `resume`.** `resume` takes only the session id, a prompt, `--model` and
  `--config`. A `--sandbox` after it fails immediately with `unexpected argument '--sandbox' found`,
  and the log then holds that one error instead of a run.
- **The log path is new.** One log path per run still holds. Writing to the original path truncates
  the evidence you are trying to keep.
- **The prompt says what remains.** The peer wakes with its own context, so it needs the ending, not
  the brief again.

Everything else about a launch is unchanged: `setsid`, `< /dev/null`, a foreground Bash call, and a
pgrep on this run's own token to confirm the process by process rather than by log.

## Confirming the right run came back

`pgrep -af "[r]esume <first-8-chars-of-id>"` distinguishes several resumed peers from each other. The
new log's banner repeats the model and the effort, so one `grep "reasoning effort"` over the new logs
proves each peer came back with the configuration you meant.
