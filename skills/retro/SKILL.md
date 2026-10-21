---
name: retro
description: Look back at a coding session and propose changes to the agent's environment, not to the code. Invoke with /retro, optionally followed by a session ID.
disable-model-invocation: true
---

Run a **retrospective**: find what in the environment made this session slower, costlier or wrong, and propose the change that prevents it next time.

## 1. Load the writing guide

Call the Skill tool with "writing-for-agents". Every proposed rule follows it.

## 2. Read the session

Default to the current session. When the user names another session, its transcript is `~/.claude/projects/<project dir>/<session id>.jsonl`, and its sub-agents are under `<session id>/subagents/`. Search a transcript with `rg`. Read only the matched turns, never the whole file.

Collect the evidence first:

- each correction from the user, and the turn that caused it,
- each tool call that failed or was repeated on the same target,
- each long search for a file, a fact or a command,
- each tool call whose output was much larger than what the agent used.

**Done** when every item on that list has its turn quoted.

## 3. Classify each item

Filter each item first:

- **Skill was used.** Route a skill change only to a skill the session used: a Read of its `SKILL.md`, a Skill call, or its documented command in a tool call. When a skill should have fired and did not, the target is its `description`.
- **Already covered.** Read the target file. When it states the rule clearly, drop the item as an execution miss. When the rule is there but buried or weak, propose a placement or wording change, never a second copy.
- **Durable.** Keep only a change that still holds in six months. A path, a SHA or a version number goes into the evidence, not into the rule.

| Category | Question | Typical fix |
|---|---|---|
| Navigation | Did the agent take long to find the right file or symbol? | A pointer in the project `CLAUDE.md` or a skill description; `ecp` for code structure |
| Automated checks | Could a check have caught the mistake? | Follow the **mechanical rule** bullet in `writing-for-agents`. Look for an existing check that is unwired or broken first: a hook in `~/.claude/hooks/`, the project's lint, CI |
| Review | Did `simplify` miss the mistake? | A rung in `~/.claude/skills/simplify/CHECKLIST.md` |
| Rules | Did the agent break a rule it had loaded, or follow a rule that no longer fits? | A wording change in `CLAUDE.md` or a skill. Read the rule's measurement first (`~/.claude/maintainer-notes.md`, or `measurements.md` beside the skill) |
| Tool economy | Did a call cost far more tokens than it returned in value? | A narrower command, an `rtk` filter, or a script that returns only the answer |
| Information access | Did the agent lack a fact it could not get? | A log tee, read access, or a reference file |
| Lesson | Is the fix a fact about the user or the project, not a rule? | A memory file, per the memory rules in the system prompt |

For an item a check could catch, pick the highest level that works: remove the wrong path from the code, then a type, then a lint or hook whose error names the right command, then a test. A prose rule comes last, and only for a judgment call.

**Done** when every item carries one category or a drop reason.

## 4. Report

List the candidates from most to least costly. For each one give:

- the evidence: the quoted turn, with its session ID,
- the category,
- the target file and the exact change,
- for a check, the level you picked and why each higher level does not work,
- whether the change needs a `validate-prompt-rules` A/B before it ships. A change to `CLAUDE.md` or to a measured sentence always does.

Write the report in the user's language. Apply nothing until the user picks the candidates.
