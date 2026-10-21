# Skill mechanics

This file is the skill branch of [`writing-for-agents`](SKILL.md). It covers frontmatter, the invocation choice and router skills. `SKILL.md` covers everything else.

## Invocation

The two choices trade the two loads.

- A **model-invoked** skill keeps a `description`. The agent can fire it on its own, and other skills can reach it. The user can still type its name. The description is the skill's top-level context pointer, and it stays loaded at all times. A model-invoked skill that holds only reference is one home for shared reference, because several skills can invoke it. Mechanics: omit `disable-model-invocation`. Write a model-facing description with the trigger branches. The pointer rules in `SKILL.md` apply in full.
- A **user-invoked** skill hides its description from the agent. Only the user can invoke it, by typing its name. No other skill can invoke it. It costs no context load and spends cognitive load: the user must remember that it exists. Mechanics: set `disable-model-invocation: true`. The `description` becomes a one-line summary for the human, with no trigger list.

Pick model-invocation only when the agent or another skill must reach the skill. Make a skill that only fires by hand user-invoked.

Two user-invoked skills cannot share reference that lives inside either one, because neither can fire the other. Put that reference in a plain file outside the skill system, and point at it from both.

## Splitting by invocation

The invocation cut of splitting (the sequence cut lives in `SKILL.md`): split off a model-invoked skill when you have a distinct leading word that should trigger it on its own — a trigger word you actually use in your prompts — or another skill must reach it. You pay context load for the new always-loaded description, so that independent reach has to be worth it.

## Router skills

When user-invoked skills grow past what the user can remember, write a **router skill**. A router skill is one user-invoked skill that names the others and when to reach each one. The user then remembers one skill. A router can only hint. It cannot fire the others, because they have no description.
