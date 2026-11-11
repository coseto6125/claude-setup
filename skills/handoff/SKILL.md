---
name: handoff
description: Write a hand-off document so a fresh session can continue this conversation's work, and optionally start that session in Orca. Invoke with /handoff, optionally followed by what the next session will do.
argument-hint: "What will the next session do?"
disable-model-invocation: true
---

Write a hand-off document that lets a fresh session continue the current work without this conversation.

When the user passes an argument, read it as the next session's goal. Keep only the state that goal needs.

Save the document to `<scratchpad>/HANDOFF-<YYYYMMDD-HHMM>.md`, where `<scratchpad>` is the session scratchpad directory from the system prompt. Write it in English.

## Sections

| Section | Content |
|---|---|
| Goal | The next session's goal and its done condition. |
| State | What is done, what is in progress, and the last command that verified each part. |
| Pointers | Each artifact the work already produced, by absolute path, URL, PR number, commit SHA or mpm item ID. |
| Running agents | Each background agent, Orca worker or background command still running, with the name that `ListAgents` or Orca prints. Write "None" when nothing runs. |
| Open questions | Each decision that waits on the user, with the options already offered. |
| Suggested skills | Each skill the next session must call the Skill tool for, and the step that needs it. Name user-invoked skills too, because a fresh session does not see them. |

Point to an artifact instead of copying it. The ledger, a spec, a diff and a report each stay in their own file.

Redact every secret: an API key, a password, a token, a connection string with credentials, and personal data. Write `<REDACTED>` in its place.

## Start the next session

Run this section after the file exists, when a compaction reminder sent you here or the user asks for a new session.

1. Reach a break point. No background build or test runs, no agent edits files, and every change is committed by path. Wait for each running job's completion notification.
2. Resolve the Orca executable: `$ORCA_CLI_COMMAND` when it is set, else `orca-ide` on Linux.
3. Find the workspace root, the repo's main checkout. Run `git -C "<work directory>" worktree list --porcelain`. Its first line is `worktree <root>`. When the command fails, the root is the work directory. Pass that root, never a `.claude/worktrees/` path: a launch into one hangs.
4. Launch the agent as a background call, and act on its completion notification. Quote each path:

   ```text
   <orca> agent launch --agent claude --worktree "path:<workspace root>" --surface terminal --prompt "<prompt>" --json
   ```

   When the launch fails or its reply is lost, re-issue the same command with `--retry-launch <operationId>` from the error. Never start a second fresh launch.

   Write the prompt in English, as three sentences:
   - `cd "<work directory>"`, the absolute path of the worktree or checkout that holds the work.
   - Every Edit and Write targets that directory by absolute path.
   - Read `<file path>` in full, then continue its Goal to its done condition.
5. Confirm delivery. The result's `result.prompt.outcome` is `handed-to-terminal` or `journaled`. Then run `<orca> terminal read --terminal <result.outcome.handle> --json`, and find the prompt's first sentence in `result.terminal.tail`. When the tail does not show it yet, run the read again.
6. Stop. After the reply, change no file and start no command.

## Done

The step is done when the file exists and every section holds content or "None". After "Start the next session", the step is done when the new terminal's `tail` shows the prompt.

Reply to the user in their language with two lines: the absolute path of the file, and the resume prompt `接手 <absolute path>`. After "Start the next session", add a third line: the new session's terminal handle.
