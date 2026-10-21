# Archive of superseded `maintainer-notes.md` entries

Measurements on models before the 2026-10-09 re-verification. Read only for history; the live entry under the same heading in `maintainer-notes.md` is the authority.

## `colleague-zh` Voice, the turn-ending sentence

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Live failure: a turn ended on 「開始了。」 with no tool call after it, then repeated one turn
later with the first fix already in place.

Four probe designs failed before one worked. The two informative failures: a scenario that
*instructs* the handoff scores every arm at 0/10, and an escape hatch cheap enough to name
(`output TOOLCALL`) scores every arm at ~100%. The design that reproduces it states facts only
("the first of three things is done, the other two are open") and asks for the whole message.

n=12 per arm on opus, scoring whether the closing sentence announces a future action:

| passage | clean |
|---|---|
| bare | 0/12 |
| whole passage removed | 8/24 |
| original sentence alone ("Let the last sentence be the last fact.") | 3/12 |
| red line alone | 7/12 |
| shipped: original + "A fact is already true when you write it" + red line | 11/12 |

The original sentence alone is indistinguishable from writing nothing (p=0.81). The red line
alone is 7/12. Together they are 11/12 (p=0.0011 against removal, p=0.078 against the red line
alone). **A sentence can be inert alone and load-bearing in combination** — the same shape as
"a name needs two mentions" in Dispatch, "Model and effort". The negative wording is deliberate: this prior is strong
enough that bare opus announces 12/12, which is the condition `writing-for-agents` names for
keeping an explicit negative.

Removed on the same evidence: a `**Tool calls fire direct.**` paragraph added to the style that
same day. Against the rest of the style it scored 20/20 vs 18/20 at n=20 (p=0.24), while bare
opus scored 2/20 — redundant against the document, not against the model.

## Core Philosophy

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Core Philosophy | dedup 10M strings, first-seen order | 8/10 | 5/10 | load-bearing on opus (3v0); haiku already does it |

## Proactive Engineering

### Breaking-change sign-off, added 2026-08-25 — pilot only, not shipping-grade

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source ideas and the common thread: `## Method notes`, the 2026-08-25 subsection.

**Proactive Engineering, breaking-change sign-off.** Same isolation, n=5 per arm, scenario: a
signature change breaks exactly one caller, in a peripheral test-helper file, not a core module.

| arm | asks before proceeding |
|---|---|
| control (no rule) | 0/5 |
| positive wording (shipped) | 5/5 |
| negative wording ("Never break... silently") | 5/5 |

Clean, unsaturated effect; the positive rewrite held as well as the blunt negative at this n — no
leak observed, unlike the `colleague-zh` case elsewhere in this file where a positive rewrite did
leak. Paired with a matching edit to `ECP.md`: its "many callers → confirm" line was a second,
weaker threshold for the same decision (derived-mirror drift), demoted to a pure `ecp impact`
usage note that points at this rule as the sole authority on whether to ask.

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Proactive Engineering | next action after fixing a None-deref | 10/10 | 1/10 | load-bearing |

Probe design matters more than n. Proactive Engineering first measured 6/6 vs 6/6 on a probe
that asked "what do you do about the other three?" — the question already carried the decision.
Rewritten to "state your single next action", the same section separates 10/10 vs 1/10.
A null result on a probe whose control cannot fail says nothing.

## Surgical Changes

### Leave-one-out, 2026-08-21, n=6 per arm, opus + haiku (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | opus c/B/A | haiku c/B/A | verdict |
|---|---|---|---|
| Surgical Changes | 0/0/6 | 2/5/6 | opus load-bearing; haiku does not separate |

## Commit & PR Authorship

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Red line — keep the negative wording; a positive rephrase here weakens the constraint (verified: reworded variant let a model re-add the footer).

**The rule was fighting the harness. `includeCoAuthoredBy: false` removes the fight at its source** (set on 2026-08-14). The CLI injects both attribution texts by default, so the system prompt carried `End git commit messages with: Co-Authored-By: Claude …` in the same session that `CLAUDE.md` said never to add it.

The settings reference's table claims the default is `false`. It is not. Verified against the 2.1.232 binary: the attribution builder returns the trailer and the PR footer unless `includeCoAuthoredBy === false`, and `attribution: {commit, pr}` overrides both texts and outranks it. To re-verify on a later build, start a session and read whether the system prompt still carries the trailer instruction.

The `CLAUDE.md` rule stays for now. Its red-line status was measured while the harness was injecting the opposite instruction, and nothing has been measured without it. Deleting it needs its own A/B against the model's own prior, on more than one model: the injection is gone, the training prior for `🤖 Generated with Claude Code` is not.

## Prompt Writing Guide

### The `writing-for-agents` pointer, live failure 2026-09-04

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Live failure 2026-09-04: a session edited `simplify/SKILL.md` by hand, following the Guide's
own bullets from context, and never invoked `writing-for-agents`. The skill's own description
never fired, because the inline block already felt like coverage.

Probe reproduces the failure rather than describing it: the task is a RULE change to a named
SKILL.md ("make the code-review skill launch a second reviewer at every tier, not only the top
one"), the ask is the ordered procedure, and a realistic 30-skill list sits in every arm. Target
behaviour = a step that names `writing-for-agents`. n=4 per arm, isolated via `CLAUDE_CONFIG_DIR`
+ `--setting-sources user` (canary NONE 3/3).

| arm | opus | haiku |
|---|---|---|
| control (skill list only) | 0/4 | 0/4 |
| A: `This block is the authority; \`writing-for-agents\` elaborates it.` | 0/4 | 0/4 |
| B: `...authority for a line you write in passing. **Invoke \`writing-for-agents\` before you write, edit or review one of those artifacts as the task itself.**` | **4/4** | 0/4 |

B shipped. The old wording is inert on BOTH models, so it was a pointer in name only — it stated
what the material is and named no branch that triggers the reach.

Haiku floors at 0/4 on every arm, and that is left alone: a haiku sub-agent dispatched as
`lite-scan` has no Skill tool, so it cannot obey the rule whatever the wording says.

Two earlier probe designs measured nothing and are recorded so they are not retried. One named a
file path and every arm answered "I need permission to read it" (the ask lacked "No tools"). One
supplied the section text and framed the task as tightening WORDING; opus control then hit 3/3,
because a skill literally named `writing-for-agents` is the obvious pick for a wording task. The
design that separates frames the task as a rule change, where the skill is not the obvious pick.

### Prompt Writing Guide, compressed 1,111 → 704 chars

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Five probes, A = compressed, B = current, n=6 per arm on opus and haiku. Every probe ties.
Two bullets are confirmed load-bearing and both survive: positive phrasing (opus control 0/6,
haiku control 0/6, both arms 6/6 and 5/6) and abstract-rules-first (haiku control 3/6, both arms
6/6; saturated on opus). The other three probes measure nothing in either version.

## Dispatch, "When to dispatch"

### Phase bullet and the brief lines, 2026-09-15

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source: the 22 sub-agent transcripts of one client-project session, usage summed per turn. Four implementers ran 221 to 335 turns to a final context of 370k to 471k; 78 to 95% of their spend (cache reads at 0.1x) fell after the context passed 200k. Reviewers that ended at 73k to 211k cost $0.7 to $14 each. The 150k phase target is chosen, not measured: the agent cannot see its own context and the main session sees nothing until it returns, so the split is planned in the brief, and the 200k line is only the after-the-fact signal. The "names the function or line range" and batching-instance lines come from the same transcripts: one 31k-token source file read whole four times, 87 to 114 single-command Bash calls per implementer. A/B 2026-09-15, isolated `claude -p`, control = CLAUDE.md without the new lines, rule injected via `--append-system-prompt`, n=5 per arm, hit scored by regex on the reply. Phase bullet (probe: plan the dispatch for a six-tab cut): opus control 2/5 (both hits were "handoff" in the merge sense, not a phase split), A 5/5; sonnet control 0/5, A 5/5. Keep. Line-range line (probe: write the brief for a change in two large files, sizes stated): opus control 5/5, so a no-op for an opus brief-writer when the scenario states the sizes; sonnet control 0/5, A 5/5. Kept for the weaker reader; the opus probe is leading and does not measure the real-brief case. Batching-instance line: opus control 4/5, A 5/5; sonnet control 1/5, A 5/5. Keep.

### Deliberately absent: the big-read rule and the worktree-isolation rule

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Deliberately absent: a "delegate the big read" rule, and a worktree-isolation rule. The cost arithmetic supports the first (a haiku delegate repays its own ~10k prefix reload once it reads past ~6.5k tokens), but five wordings measured neutral-to-harmful on Opus 5: it already delegates a genuine bulk read unprompted (3/3) and already prefers a targeted grep over delegating a lookup (3/3), and every threshold wording broke that second case. It also already sets `isolation: "worktree"` on parallel writers unprompted (3/3). Don't re-derive the arithmetic and re-add either rule.

## Dispatch, "Model and effort"

### Reduced 2026-08-14, and the two-mentions finding

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Reduced from 1,823 to 1,054 chars on 2026-08-14. The Dispatch red line above is untouched; this covers only the subsection.

**A name needs two mentions.** One is worth nothing. Measured on opus, n=10 per arm, scenario "score 40 PR titles against a fixed rubric, no repo access", scoring whether the reply names a `subagent_type`. Counting occurrences of the literal string `lite-scan` in each arm:

| arm | `lite-scan` mentions | hit |
| --- | --- | --- |
| two parentheticals, no standalone sentence | 2 | 10/10 |
| shipped version: ladder parenthetical plus a standalone sentence | 2 | 9/10 |
| original 1,823-char block | 2 | 8/10 |
| ladder parenthetical only | 1 | 0/10 |
| standalone sentence only, plain prose | 1 | 0/10 |
| standalone sentence only, as a backticked code token | 1 | 0/10 |
| control | 0 | 0/10 |

Two mentions score 8 to 10. One scores zero. Position (opening sentence, ladder row, closing sentence), syntax (parenthetical or standalone sentence) and code formatting (backticks or plain prose) all vary inside each group and none of them predicts anything.

**A retraction.** An earlier version of this section claimed the opposite: that a standalone sentence carries the behaviour and a parenthetical is unreachable. That claim came from n=5 on two arms, it was published, and it is wrong. The parenthetical-only arm at 10/10 and the sentence-only arm at 0/10 are the direct counterexamples. The credit for the correct explanation goes to a fable-5 sub-agent, which proposed frequency as the alternative and named the crossed experiment that separates it from position.

Why the wrong claim survived a first check: `## Method notes`, the 2026-08-14 harness subsection.

The shipped block keeps the standalone sentence even though the shortest 10/10 arm drops it, because that sentence also carries the pointer to `agent-routing` and the cross-reference to *When to dispatch*, and this probe measures neither.

Where the optimisation stopped: further cuts would have to trim the ladder rows' example lists, and the probe scenario was written from those examples. Cutting them would measure the probe, not the rule.

The brief lines ("names the function or the line range", the batching instances): `## Dispatch, "When to dispatch"`, the 2026-09-15 subsection.

## Code Style (general)

### Special case removed by restructuring, added 2026-08-25 — pilot only, not shipping-grade

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

Source ideas and the common thread: `## Method notes`, the 2026-08-25 subsection.

**Code Style, eliminate a special case by restructuring.** Scenario: a linked-list bug where
`self.size -= 1` was added to one branch of an if/else and not the other (concrete, not the
original abstract "linked-list head-node" framing — the abstract scenario let both arms dodge by
asking to see the code first).

| version | restructure rate (moves the line out, vs patching the missing branch) |
|---|---|
| control (no rule) | 0/5, then 2/5 on a repeat run — noisy at this n |
| abstract wording ("has not hidden... has eliminated it") | 3/5, then 4/5 on repeat |
| concrete wording (shipped: "when two branches differ by a single statement, move it outside them") | 5/5, both times tested |

The concrete wording never underperformed the abstract one across two independent n=5 runs and
costs the same or fewer words — shipped on that basis. The margin over the abstract wording is
within the n=5 noise floor; not shipped as "proven better," shipped as "at least as good, free."

### Add-one-in, 2026-08-15 (design: `## Method notes`)

> Superseded 2026-10-09: see "Re-verified 2026-10-09 on the current models" below.

| section | probe | RULE | CONTROL | verdict |
|---|---|---|---|---|
| Code Style (general) | `match` over an if/elif chain on four string values | 6/6 | 0/6 | load-bearing |
