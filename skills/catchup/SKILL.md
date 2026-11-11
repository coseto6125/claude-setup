---
name: catchup
description: Catch the user up on this chat since their last message, and list every call waiting on them so they can decide from the reply alone. Invoke with /catchup.
disable-model-invocation: true
---

# Catchup

The window starts at the last message the user wrote before `/catchup`. Notifications, hook output and sub-agent results are not user messages. Assume the user remembers that message and nothing after it.

## Gather

Keep this turn read-only: change no file, start no job or agent, and post nothing.

1. Collect your own work since that message, each sub-agent report, and each message from another session.
2. Read the scratchpad ledger when one exists.
3. Check the live state of each PR, CI run and agent that this chat touched, with `gh pr view`, `gh pr checks` and `ListAgents`. Report the live state, not the last report.
4. Check each number you will show against its source. Say so when you correct one.

Collect the **calls**. A call is a decision or a step that only the user can take: a product choice, an approval, an irreversible action, or access you lack.

For each item that a call covers, collect its name or link, what it changes for the user, the evidence behind your pick, its risk, and your pick.

Gathering is done when every PR, agent and job this chat touched has a checked state, and every open call has those five facts.

## Write the reply

1. Open with one sentence that names what waits on the user, or says that nothing does. When nothing happened and nothing waits, say so and stop.
2. Give one line for each thing the user asked for: what came of it, and whether it is done, still running, failed or not checked. Name each bug found and fixed on the way. Never mark something done that still waits on the user. Leave out work that changed nothing for the user.
3. Name in one line the work left that you can do yourself.
4. List the calls. Give each item a change line, an evidence line and a risk line, also when the risk is low. Give each call your pick. Write "unknown" in a line whose fact you do not have, and keep the line.

Rules for the calls:

- When items share one call, such as several PRs that wait on a merge, write the call and your pick once. Then give each item its own line, riskiest first.
- For a choice between options, give each option its gain and its cost. The costs are the risk, so add no separate risk line.
- Put each step that must happen first, or that cannot be undone, into your pick.

Say what changed for the user, not how you did it. Leave out hashes, paths, commands and test counts unless the user needs one to act. Call each PR, branch or agent by a name the user knows, not by a label you invented.
