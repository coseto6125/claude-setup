---
name: pr-finalize
description: Remove a finished PR's local worktree and local branch.
disable-model-invocation: true
---

# PR Finalize

This skill is the one sanctioned exception to the `CLAUDE.md` rule "Never delete `.claude/worktrees/` directories". The user typed the command, and the script refuses to remove a worktree whose branch has commits the PR lacks.

```bash
cd "$(git rev-parse --show-toplevel)" && bash ~/.claude/skill_script/pr-finalize.sh [PR#]
```

`PR#` omitted → auto-detected from the current branch. The script resolves the PR and removes the worktree, prompting only when it is dirty. Then it force-deletes the local branch. It refuses, and prints the reason, in three cases. The PR is not merged and `origin/<branch>` does not exist. The script cannot fetch the PR head. The local branch has commits the PR does not have.

Run it from the main repo root. A subprocess cannot move its parent shell's cwd, so the script refuses when your cwd is inside the worktree it must delete; otherwise the caller would land on a deleted directory. The `cd "$(git rev-parse --show-toplevel)"` prefix covers every case except standing inside that worktree — from there, `cd` to the main repo first.
