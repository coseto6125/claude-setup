---
name: context-audit
description: Audit what fills the context window, examine usage and dependencies, and recommend changes that fit the user's workflow.
disable-model-invocation: true
argument-hint: "[tool or skill names to price]"
license: MIT
---

# Context audit

This skill turns a context audit's reasoning into a reusable workflow: identify sources, measure costs, examine usage and dependencies, then weigh savings against the capabilities the user values. It produces recommendations, not a preset cleanup list. Read [`KNOBS.md`](KNOBS.md) when selecting a setting. These rules hold for the whole run:

- Every number names its evidence source and measurement method. An estimate carries the label `estimate`; unavailable measurements stay `unmeasured`.
- Every recommendation connects the evidence to this user's tasks and preferences, and names the capability or convenience it affects. Low usage alone does not establish low value.
- Discover paths, installed tools and skills from the current environment. A previous user's choices, thresholds and installed items are examples, not defaults for another user.

Use the session's available tools to inspect evidence directly; this skill requires no bundled scripts. Write the ledger in the scratchpad as you go: one row per item, with its source. The ledger is the deliverable of Step 6.

## Step 1: Baseline

Read the conversation for the user's goal, typical tasks, preference for automatic discovery versus explicit commands, and capabilities they want to preserve. Ask a focused question only when missing information would change a recommendation; record unresolved preferences rather than inventing them.

Use `/context all` when available. Record its category totals and check them against the header total. If it is missing, ask for it while continuing the inventory; mark token costs `unmeasured`. Done when the user's goal and known workflow preferences are recorded, and baseline categories are measured or explicitly missing.

## Step 2: Inventory the sources

Inspect the current environment and configuration to identify:

- every CLAUDE.md on the load chain with its size, the `@` files it imports, and `<ancestor>/.claude/CLAUDE.md` duplicates
- the memory index file for this project
- the hook commands per event and available records of their injected output. Reading a hook is not executing it; run one for measurement only after inspecting it and establishing that execution fits the audit's scope.
- every user and project skill with its visibility state and description length
- the knobs already set in settings

Done when each category from Step 1 maps to the files or tools that fill it. Bundled skills and built-in tools have no file on disk, so their numbers come from the `/context all` lines. A category with no source found is written in the ledger as `unattributed`.

## Step 3: Price the tools

Choose candidates from the user's request and the inventory: high measured cost, possible duplication, or uncertain workflow value. Use the available `/context` breakdown first. When an isolated before/after comparison would resolve a decision, hold the model, version, prompt and other settings constant, and record those conditions. Additional model calls are optional. A headless result does not establish interactive cost, and an inconclusive delta stays `unmeasured`. Done when each candidate tool has a measured cost or the word `unmeasured` in the ledger.

## Step 4: Prove usage

Locate the current installation's available transcripts and command history. Inspect a relevant sample for each candidate tool or skill, distinguishing actual tool calls, model-invoked skills and user-typed commands from quoted mentions. Parse structured records when calculating counts or timestamps.

Record history coverage, relevant task types and whether the skill was installed during that period. Deduplicate session identities when reporting session counts; use invocation timestamps rather than file modification dates for recency. Missing history, a new installation or infrequent seasonal work leaves usefulness uncertain. Done when each candidate has usage evidence with its coverage limits, or an explicit `unknown`.

## Step 5: Check dependencies

For each skill considered for manual invocation, disabling or removal, inspect references in loaded instructions, other skills and available tool descriptions. Determine what each relevant caller requires and whether the proposed visibility still supports it. Text matches and visibility guards are clues, not proof that a workflow remains usable. Done when each proposed restriction has a dependency assessment and any unresolved dependency is recorded as a reason to defer it.

## Step 6: Decide

Fill the ledger: item, measured or estimated tokens, usage and dependency evidence, relevant user preference, recommendation, tradeoff, knob and scope. Recommendations are `keep`, `manual`, `off`, `remove`, `deny`, `exclude`, or `investigate`. Weigh these options against the user's workflow:

1. Recommend `keep` when automatic discovery, a dependency, an upcoming task or an infrequent but important use justifies availability. Model-initiated use can serve the user even without visible output.
2. Recommend `manual` when the user prefers explicit invocation for that capability, can find and invoke it, and callers do not need automatic discovery. A low call rate alone does not select this option.
3. Recommend `off` for an unwanted capability the user may want to restore. Consider `remove` only when uninstalling fits the user's goal and installation ownership, dependencies and restoration are understood. Disabling a caller does not by itself make its skill unwanted.
4. Recommend `deny` when restricting a tool fits the user's tasks and the resulting loss of capability is acceptable. Consider both recent use and future need; use no universal recency or frequency cutoff.
5. Recommend `exclude` only after checking that the instruction file is redundant in meaning and scope, with no unique guidance lost. For memory and global instructions, identify useful consolidation opportunities while preserving the user's intended behavior; size alone is not a deletion criterion.
6. Use `investigate` when evidence or preferences are insufficient. State the smallest observation or question that would distinguish the options.

Show the ledger with measured savings where available, uncertainties, and the capability or convenience each change affects. Done when the recommendations explain how they fit this user. An advice-only audit ends here. For requested implementation, match each proposed change to existing authorization and ask only about changes not yet authorized.

## Step 7: Apply and verify

Apply only authorized rows in the intended configuration scope, using settings supported by the installed Claude Code version. Preserve unrelated values, retain a recoverable copy, and validate edited settings with a JSON parser. Clearing a visibility override does not uninstall a skill; use the installation's supported removal method for an authorized `remove` row. Then:

1. Repeat any available cost measurement under the same conditions as the baseline.
2. Check representative workflows for the affected capabilities, including manual invocation and retained dependencies where relevant.
3. Tell the user to restart the session and run `/context all` to compare with Step 1. Report how to restore the previous settings.

Done when authorized changes and available verification results are reported. If a restart or user-run check is still needed, label verification pending; issuing restart instructions is not proof of savings or preserved behavior.
