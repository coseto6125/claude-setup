# Long real context: resume a cut session

Resume a real session that showed the failure, cut just before the turn you measure.

1. Pick the cut: the uuid of the entry just before that turn's user prompt. The CLI refuses a resume with no new prompt.
2. Run `python3 fork_fixture.py <session.jsonl> <cut-uuid>`. It prints the fixture id and path.
3. From the source session's cwd, run every trial of an arm with the same prompt:

```bash
claude -p --resume "$FID" --no-session-persistence --system-prompt-snapshot off --model claude-opus-5-5 \
  --output-format json --tools Read,Grep,Glob "$PROMPT" < /dev/null
```

- **Pass `--system-prompt-snapshot off` in every arm.** Without it, a resume reuses the system prompt that the session recorded, and `--append-system-prompt` has no effect.
- **Restrict the tools.** A trial runs in the real project, so allow only read tools, or `--tools ""` for a text-only probe. A hook that rewrites Bash commands makes every `--allowedTools` Bash prefix miss. To allow read-only Bash, gate it with a PreToolUse hook passed through `--settings`, and pass `--permission-mode dontAsk`.
- **Subtract the source session's cost.** The fixture carries it, so `total_cost_usd` of a trial includes it.
- **Put the arm difference after the history**: in the prompt, or in a hook's injected text. A change to the system prompt or a `CLAUDE.md` rewrites the cache for the whole history in each arm.
- **Expect one full cache write per arm.** Trials 2 to n of an arm read the history from the cache.
- **This design is not isolated.** The live `CLAUDE.md`, hooks and skills load, and the history carries the old rules' effects. Name it as a preloaded design in the report, and skip the isolation gate.

Delete the fixture by the literal path that step 2 printed.
