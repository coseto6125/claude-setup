---
name: pr-finalize
description: Remove a finished PR's local worktree and local branch.
disable-model-invocation: true
---

# PR Finalize

```bash
cd "$(git rev-parse --show-toplevel)" && bash ~/.claude/skill_script/pr-finalize.sh [PR#]
```

`PR#` omitted → auto-detected from the current branch. The script resolves the PR, keeps unpushed work safe by refusing to touch it, removes the worktree (prompting only when it is dirty), and deletes the local branch — printing the reason behind any refusal.

Run it from the main repo root. A subprocess cannot move its parent shell's cwd, so the script refuses when your cwd is inside the worktree it must delete; otherwise the caller would land on a deleted directory. The `cd "$(git rev-parse --show-toplevel)"` prefix covers every case except standing inside that worktree — from there, `cd` to the main repo first.
