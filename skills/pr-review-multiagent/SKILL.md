---
name: pr-review-multiagent
description: Six-angle merge-readiness review of a GitHub PR, posted to the PR.
disable-model-invocation: true
allowed-tools: Bash(gh pr view:*) Bash(gh pr diff:*) Bash(gh pr list:*) Bash(gh pr comment:*) Bash(ecp:*) Bash(git blame:*) Bash(git log:*) Bash(git diff:*) Read Grep Glob Task Write
---

# PR Review — multi-agent, ecp-driven

## Phase 1: Eligibility + context (1 Haiku agent)

1. **Eligibility — stop here if any of these holds**: PR state is not OPEN (closed / merged / draft) · the author is a bot (Dependabot, renovate) · you already reviewed this exact `headRefOid`.
2. **Context paths**: the root `CLAUDE.md` / `GEMINI.md` / `AGENTS.md`, plus the `CLAUDE.md` in every directory the PR touches files in.
3. **PR data**: `gh pr view <num> --json title,body,baseRefName,headRefName,headRefOid,changedFiles` and `gh pr diff <num>`.

Returns `{eligible, claude_md_paths, pr_data}`.

## Phase 2: ecp pre-pass (bash, no LLM)

```bash
ecp impact --baseline <baseRefName> --repo . --format json
# → changed_symbols (added/modified/removed), impact_by_symbol (1-hop callers)
```

Risk floor per global CLAUDE.md → Dispatch → *Risk is inferred*, calibrated for PRs: <5 callers → LOW · 5–15 → MEDIUM · >15 → HIGH · auth / payment / schema-migration / concurrency / external-API path → CRITICAL. What the user stressed and what the repo's own CLAUDE.md guards raise it further; one sentence from the user lowers it.

Deepen every HIGH/CRITICAL symbol with `ecp impact --target <sym> --direction upstream --repo .`. A d=1 caller absent from the diff is a **potential break** — record it as risk evidence.

`found:false` on a feat branch while grep still sees the symbol means HEAD is unindexed rather than a real miss: `ecp admin index --repo .`, then rerun.

Package the result as a `<cgn_context>` block for every Phase-3 agent.

## Phase 3: Parallel review (6 agents)

Launch concurrently with the `Agent` tool. Each receives the PR diff, `<cgn_context>`, and the CLAUDE.md paths. Models track the Phase-2 risk: angles 3/4/5 are retrieval against fixed criteria → `haiku`; angles 1/2/6 → `sonnet`, escalating 2 and 6 to `subagent_type: deep-review` at HIGH/CRITICAL. At CRITICAL, also run Dispatch's cross-family track: hand angle 2 to codex in parallel, and mark any finding both readers raise as CONFIRMED going into Phase 4.

| # | Angle | Focus |
|---|-------|-------|
| 1 | **Guidelines** | Quote each CLAUDE.md / GEMINI.md / AGENTS.md rule and match it against the diff lines. Report rule violations only; style preferences the rules do not cover are out of scope. |
| 2 | **Hot-path bug scan** | Read only the diff hunks themselves. Surface the shallow and obvious: missing filter, `locals()` scope traps, TOCTOU, unhandled None, silent `except`, wrong retry. |
| 3 | **Git history & blame** | `git blame` the modified lines for why the old code was written that way; flag regressions. |
| 4 | **Historical PR cross-check** | `gh pr list --search "<file>"` for past PRs touching the same files; apply their recurring comments here. |
| 5 | **Comment compliance** | Read the `TODO/FIXME/WARN/NOTE` comments in the modified files; confirm the new code honours each existing warning. |
| 6 | **Simplify checklist** | Apply every rung of the Reuse, Quality, and Efficiency sections of `~/.claude/skills/simplify/CHECKLIST.md`. |

Each returns `[{description, file, line_range, reason, severity, failure_scenario, command, command_output}]` — `failure_scenario` is the concrete inputs or state and the wrong output or crash they produce, and an angle that cannot supply one drops the finding rather than filing it weakly; `command`/`command_output` let Phase 4 re-check in one jump instead of redoing the search. Each angle closes with its blind spots: what it did not read, run, or verify.

## Phase 4: Confidence scoring (1 Haiku agent per issue, parallel, ≤20 at a time)

Input: the PR, that one issue, the CLAUDE.md paths. Score 0–100 against the anchors in `~/.claude/skills/simplify/CHECKLIST.md` → Confidence, which also lists the classes that score 0.

More than 20 issues → score them in waves of 20 (Dispatch's parallel-agent cap).

**Gate: keep ≥75** — the 75 anchor is exactly the "would burn us in prod" band, so it ships. Zero survivors still goes to Phase 5, carrying the no-issues body.

## Phase 5: Re-eligibility + post

1. Re-run Phase 1's eligibility check — the PR may have gone draft, merged, or been reviewed by someone else while this ran.
2. Write the comment to a private temp file, then post it: `f=$(mktemp)`, write the body to `$f`, `gh pr comment <num> -F "$f"`, `rm -f "$f"`. A fixed `/tmp` name is a path any local account can pre-empt with a symlink.

Comment format, exactly:

```markdown
### Unified Code Review

**Risk:** <LOW|MEDIUM|HIGH|CRITICAL>
**Affected Flows:** <process names, comma-separated, or "none">

Found N issue(s):

1. <one-line title> (Score: <75-100>) — <Quality|Bug|Efficiency|Compliance>
   <https://github.com/OWNER/REPO/blob/<FULL_40_CHAR_SHA>/path/file.py#L10-L15>
   <2-3 sentences; cite the CLAUDE.md rule for a compliance issue>
```

Keep the body plain text: **never add a `🤖 Generated with Claude Code` footer or any other attribution trailer** (global CLAUDE.md red line), and no emoji. Links carry the full 40-character SHA and a `#L10-L15` range. Keep each issue to 5 lines. With zero surviving issues the body is `No issues found. Checked for bugs, efficiency, compliance.`
