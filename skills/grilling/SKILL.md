---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format each question like so:

```
❓ **Q1 · <question title>**

<question body, might be multiple paragraphs. State the stakes and what the
decision hinges on, then stop. Every choice goes in the list below, never inline.>

- **[a]**: <choice, one line>
- **[b]**: <choice, one line>
- **[c]**: <choice, one line>

➡️ **選 [b]**：<why this one, and what the other choices cost>
```

Keep the list-item dash before each `**[a]**:` label: a bare `[a]:` at column 0 parses as a link-reference definition and disappears. Read a bare letter in the user's reply (`Q18 B`) as that question's choice. A choice that needs more than one line gets a second indented line under its bullet. Separate consecutive questions with a blank line and a `---` rule.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment, look it up yourself, and never ask the user for it. Query code structure through `ecp`. Read a single file or config value directly. Dispatch a sub-agent on the cheapest tier in the CLAUDE.md Dispatch section only for a lookup larger than one query. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
