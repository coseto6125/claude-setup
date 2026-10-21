---
name: handoff
description: Write a hand-off document so a fresh session can continue this conversation's work. Invoke with /handoff, optionally followed by what the next session will do.
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

## Done

The step is done when the file exists and every section holds content or "None".

Reply to the user in their language with two lines: the absolute path of the file, and the resume prompt `接手 <absolute path>`.
