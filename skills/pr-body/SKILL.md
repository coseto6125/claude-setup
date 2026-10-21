---
name: pr-body
description: Write a pull request title and body in the fixed four-section shape, with a rollback and blast-radius call. Use before you run `gh pr create`, or before you rewrite a PR body with `gh pr edit`.
---

Write the PR in the repo's own language: the language of its README and recent PR bodies.

Read the repo's last five merged PRs first: `gh pr list --state merged --limit 5 --json title,body`. When their titles or bodies follow a convention, such as Conventional Commits titles that feed a changelog, follow that convention. Add the door and the blast radius to its first section. Use the title and body shape below only when the repo has no convention.

## Title

Start the title with one prefix: `[bug]`, `[feature]` or `[chore]`. When the PR mixes kinds, use the main kind in the title, and tag each bullet under the third section with its own prefix.

## Body

Use these four headings in this order:

| Chinese repo | English repo | Content |
|---|---|---|
| 結論 | Outcome | One paragraph: the result, then the door, then the blast radius. |
| 發生什麼事 | What happened | The problem or the need. For a bug, the confirmed cause and the hypothesis that held. |
| 改了什麼 | What changed | One bullet per change, tagged with its prefix when the PR mixes kinds. |
| 怎麼確認 | How to verify | The commands run, their counts, and the review rounds. |

## The door and the blast radius

The **door** says whether a revert undoes the merge:

- **Two-way door**: one `git revert` restores the old behaviour.
- **One-way door**: a revert leaves a trace. Examples: a schema migration, deleted or rewritten data, a published API or package version, a message sent to an outside party.

Name what a one-way door leaves behind.

The **blast radius** names the changed symbols with the most upstream callers, and their caller counts. Take them from the `impact_by_symbol` line of the `simplify` ecp pre-pass. When that pass did not run, run `ecp impact --baseline origin/main --repo .`. For a change with no code symbol, such as a config or a doc, name the consumers instead.

## Evidence

Show a before and an after for the behaviour the PR changes:

- A bug fix: the regression test red before the fix and green after, with the command.
- A visual change: a screenshot before and after.
- Other changes: the command output before and after.

## Rules

- Point to an artifact by path, URL, issue or commit. Do not paste a spec or a long log into the body.
- Write no attribution line: no `Co-Authored-By: Claude` trailer and no "Generated with Claude Code" footer.
