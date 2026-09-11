# context-audit

A user-invoked Claude Code skill that audits context sources, examines usage and dependencies, and recommends changes suited to your tasks and invocation habits. It captures the audit's reasoning process, not a previous user's list of skills to disable. Invoke it with `/context-audit`.

## Install

Copy this directory to `~/.claude/skills/context-audit` (every project) or `<repo>/.claude/skills/context-audit` (one project). This is an instruction-only Claude Code skill; it has no bundled scripts or additional runtime dependencies.

## Use

1. Run `/context-audit`, optionally with tool or skill names to examine. Describe your goal and relevant habits, such as preferring automatic discovery or explicit commands.
2. Provide `/context all` for a measured baseline when available. Missing measurements do not prevent an inventory or provisional recommendations.
3. Review the evidence, recommendations and tradeoffs. Low usage does not automatically mean manual invocation, disabling or removal. You can stop at advice.
4. If you request changes, the skill applies authorized rows and reports backups or restoration steps. Restart and run `/context all` again, then check affected workflows.

`KNOBS.md` provides candidate settings and their documentation sources. Check support in the installed version before applying a setting.
