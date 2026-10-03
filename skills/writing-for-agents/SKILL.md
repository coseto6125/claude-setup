---
name: writing-for-agents
description: 'Use when writing or reviewing any document an agent reads: a skill, AGENTS.md, CLAUDE.md, a sub-agent prompt, a tool description, or a prompt file the project feeds to a model, including a local model smaller than haiku.'
---

Reference for any document an agent reads: a skill, an `AGENTS.md` or `CLAUDE.md`, a sub-agent prompt, a doc reached by a pointer. The packaging differs. The writing does not. The levers below make the agent take the same _process_ on every run. They do not make it produce the same output.

When the document is a skill, read [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md) for frontmatter, invocation choice, and router skills.

When the reader is a local model smaller than haiku, read [`SMALL-MODELS.md`](SMALL-MODELS.md). Several levers here invert for that reader.

## Context pointers

A **context pointer** is a reference in the agent's context. It names material outside the context, and it states the condition to reach that material. A skill's description is a pointer. A line in `AGENTS.md` that names a doc is a pointer too.

The pointer's wording decides when the agent reaches the material, and how reliably. The target does not. A must-have target behind a weak pointer is a variance bug. Sharpen the wording first. Inline the material only after the sharper wording fails.

A pointer does two jobs. It states what the material is. It lists the **branches** that trigger the reach. A branch is a distinct case that the document handles, so different runs take different paths through it.

Write each trigger as a **moment**: an event the agent can see without judgement ("Before you rename a symbol", "After two failed attempts at the same problem"). A trigger that names a **category** ("when you are stuck", "for code-structure questions") makes the agent classify its own situation first, and the rule dies at that step. This applies to the trigger of every rule, not only to pointers.

> Measured 2026-08-13, haiku, 2 x n=15: five rules with category triggers scored 0 to 7 of 15. The same five with moment triggers scored 5 to 15 of 15, and the rewrite was 135 tokens shorter.

Every word of an always-loaded pointer costs on every turn. Prune a pointer harder than a body:

- **Front-load the leading word.** The pointer is where that word does its triggering work.
- **Write one trigger per branch.** Synonyms that rename one branch are one branch written twice. Collapse them, and keep only the branches that differ.
- **Cut the identity the body already carries.**

## The two loads

Every document and every pointer spends one of two budgets:

- **Context load** is the cost on the agent's window. An `AGENTS.md` line, a skill description, and anything else that sits in context every turn spend tokens and attention whether or not they fire.
- **Cognitive load** is the cost on the human: which documents exist, and when to reach for each. The human is the index. This cost buys human agency. Spend it where human judgement matters, and remove it where human judgement does not.

Material behind a pointer pays only the pointer's line in context. Material with no pointer rides entirely on cognitive load.

## Information hierarchy

A document holds two content types. **Steps** are the ordered actions the agent performs. **Reference** is the definitions, rules and facts the agent consults on demand. The two mix freely: all steps (a recipe), all reference (a review's rules, this skill), or both.

The core decision is where each piece sits on the **information hierarchy**. The hierarchy ranks material by how immediately the agent needs it.

1. **In-file step** is the primary tier: what the agent does, in order.
2. **In-file reference** is consulted on demand. It is often a flat peer-set, such as every rule of a review on one rung. A flat peer-set is a fine arrangement, not a smell.
3. **Disclosed reference** sits in a separate file behind a context pointer. The agent loads it only when the pointer fires. The file can sit beside the document, or anywhere that any document can point at.

Push too little down and the top bloats. Push too much down and you hide material the agent needs. That tension is the whole decision.

**Progressive disclosure** is the move down the ladder, out of the main file and behind a pointer, so the top stays legible. It protects the hierarchy first and saves tokens second. Branching gives the cleanest test: inline what every branch needs, and disclose what only some branches reach. In a document with steps, reference that belongs behind a pointer buries those steps, and the agent then attends to them at random. That makes disclosure a variance lever, not only a legibility one.

**Co-location** is the within-file companion. The ladder decides how far down a piece sits. Co-location decides what sits beside it. Keep a concept's definition, rules and caveats under one heading, so that reading one part brings its neighbours with it. The test: the document reads like documentation written for the agent. Co-location differs from duplication. Duplication repeats one meaning in two places. Scattering fragments one meaning across many places.

**Sprawl** is the failure mode here. The document is too long, even when every line is live and unique. Attention thins across the excess, and each extra line is one more line to keep relevant. The ladder is the cure. Disclose reference behind pointers, and split by branch or by sequence, so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a **completion criterion**: the condition that tells the agent the work is done. Two properties make the criterion a lever.

**Clarity** answers one question: can the agent tell done from not-done? A vague bound such as "understanding reached" invites **premature completion**. The agent ends the step before the work is done, and its attention slips to _being done_. The **post-completion steps**, the visible steps still ahead, supply that pull. The criterion's clarity is the resistance. Defend in this order:

1. Sharpen the bound, because that fix is local and cheap.
2. Split the sequence to hide the later steps, only when the bound stays fuzzy _and_ you observe the rush.

Hiding works only across a real context boundary, such as a hand-off or a subagent dispatch. An inline call leaves the later steps in context and clears nothing.

**Demand** is how much the criterion requires. "Every modified model accounted for" forces thorough work. "Produce a change list" does not. Demand drives **legwork**, the digging the agent does inside the work. Legwork stays latent in the wording, and you do not write it as its own step. Demand is not step-bound. "Every rule applied" binds a body of flat reference the way "every step done" binds a sequence. That is how an all-reference document still carries an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## When to split

A split into two documents spends one of the two loads. Split only when the cut earns it.

- **By sequence.** Split a run of steps when the post-completion steps tempt the agent to rush the step in front of it. Hidden later steps drive more legwork on the current task. The reverse also holds: a merge exposes each step's later steps, and invites premature completion.
- **By invocation.** This cut is skill-specific. See [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md).

## Leading words

A **leading word** is a compact concept that already lives in the model's pretraining, and that the agent thinks with while it runs the document. _Lesson_, _fog of war_ and _tracer bullets_ are leading words. The word anchors a whole region of behaviour in the fewest tokens, because it recruits priors the model already holds. A word you coin yourself works if you define it clearly. A coined word recruits no priors, so you pay in definition tokens what a pretrained word gives free. Reach for an existing word first.

Repeat the word as a token, never as a sentence. It then accumulates a distributed definition. One mention is not enough.

> Measured on claude-opus-5, n=10 per arm: a `subagent_type` named once was picked 0/10, in every position and syntax. Named twice, it was picked 8 to 10 of 10.

A leading word anchors twice. In the body it anchors _execution_: the agent reaches for the same behaviour every time the word appears. Inside flat reference the word focuses attention on a class of thing to look for. In a pointer it anchors _invocation_. Put the same word in your prompts, your docs and your codebase. The agent then links that shared language to the material, and reaches it more reliably.

Hunt for passages that refactor into leading words. A triad spelled out at three sites is one such passage. A pointer that spends a sentence to gesture at one idea is another. Each one collapses into a single token:

- "fast, deterministic, low-overhead" becomes _tight_ (a _tight_ loop).
- "a loop you believe in" becomes _red_. A fuzzy gate becomes a binary observable state: the loop goes _red_ on the bug, or it does not.

The result is fewer tokens and a sharper hook for the agent's thinking. Assume every document carries restatements that leading words retire, and go find them.

**Class and instance.** A class sentence names the whole category ("name each input's atypical states"). An instance list names members ("empty, absent, a list where a scalar is expected"). Each one covers what the other misses. The instances make the agent recognise the named members. The class sentence carries the rule past the end of the list. Write the class sentence in the always-loaded file. Add the instance list where a haiku or sonnet reader loads the same text, such as an implementer's prompt. When each instance carries its own concrete prescription, such as an analogy per audience, keep the instances for every reader.

> Measured 2026-09-11, one plant, n=5 per arm: claude-opus-5 control 0/5, class-only 5/5, class+list 5/5. Haiku control 0/5, class-only 0/5, class+list 4/5. A list-only rule scored 0/6 outside its list until a class sentence was added (6/6). Haiku 2026-09-09, n=15: four audience tables 15/15, the class sentence alone 2/15.

**Negation** is the failure mode beside this lever. A prohibition of a vague behaviour ("don't be verbose", "avoid a generic look") drags that behaviour into context and makes it more available. The negation is a weak modifier, and the strongly-activated concept overruns it. State the target behaviour instead ("write one-line comments").

A prohibition earns its place in two cases:

- A hard guardrail that has no positive form.
- A demonstrated failure with a concrete form. Name the exact command or pattern the agent otherwise produces (`awk -F,`, `split(',')`). The named instance is what makes the ban work.

Pair every prohibition with the positive target. Before you rewrite an existing red line as a positive, A/B both wordings with `validate-prompt-rules`. Keep the negative if the rewrite measurably leaks.

> Measured 2026-08-21, claude-opus-5, n=12: "Never field-split a delimited format by hand (`awk -F,`, `split(',')`, `cut -d`)" scored 12/12. A positive parser rule with a moment trigger and no named command scored 0/12. Anthropic's Opus 5.5 guidance reaches the same form for frontend design: a list of named defaults to avoid works, and a vague "avoid a generic look" does not.

## Sentence style

Write every sentence to **ASD-STE100**, the aerospace standard for Simplified Technical English. `CLAUDE.md`'s **Writing discipline** holds the core rules: one term per concept, one idea per sentence, active voice, present tense, articles kept, normative sentences under 20 words, a long enumeration as a table. This section adds the rules that one leaves out:

- Keep a noun cluster to three words.
- Replace a phrasal verb with the single plain verb. Write "start the job", not "spin up the job".
- Write two sentences instead of one semicolon. STE bans that one mark, and permits every other one.
- Put a sequence of actions on separate lines, one action per line.

**Ambiguity** is the failure mode here: the agent can read a sentence two ways, or the sentence runs so long that the action inside it is buried. Either way the agent guesses, and the run varies.

Language splits two ways in one document. Write the document itself in English, and keep its rules in English. The agent's user-facing output is a separate choice, so name that output language as an instruction inside the document. `CLAUDE.md`'s Language rule holds the authority on which output goes to which language.

STE's rules split in two, and only one half is checkable here. The **structural** rules describe sentence shape, so you apply them from the description alone. The **lexical** rules come from ASD's approved dictionary, which this skill does not carry. Apply the lexical rules as a direction of travel. Hold one term per concept inside your own document, and claim no dictionary compliance. A defined leading word survives this rule, because STE admits technical names. Coin the word once, define it, then spend that one token on that one meaning everywhere.

> Rule numbers and the semicolon detail come from ASD-STE100 Issue 9 (Jan 2025): 53 rules in 9 sections, over a dictionary of ~900 approved words. Public summary, including the structural/lexical split: https://github.com/danyuchn/asd-ste100-skill

Apply STE to the sentences, not to the document's shape. The hierarchy, the disclosure and the completion-criterion levers still decide what goes where.

## Pruning

- Keep each meaning in a **single source of truth**: one authoritative place, so a behaviour change is a one-place edit. **Duplication** puts the same meaning in more than one place. It costs maintenance and tokens, and it lifts a meaning's prominence past its real rank. A leading word repeats a token on purpose. Duplication repeats the meaning by accident. Its cross-artifact form is **derived-mirror drift**: two documents that express one policy disagree. Name the authority, then align the mirror or remove it. An always-loaded summary of a canonical policy is worth keeping aligned, and is not automatically a copy to delete.
- The **environment** is a source of truth too: `package.json` scripts, config files, the directory layout, `--help` output. A document that restates the environment is a **cache**, a copy of a lookup. A cache earns its load only when the lookup is expensive. Cache what the agent cannot find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses.
- Check every line for **relevance**: does the line still bear on what the document does? A line loses relevance in two ways. It never bore on the task, because it is exposition or a branch that belongs behind a pointer. Or it goes stale as the behaviour or the world it describes changes. Without a pruning discipline the default fate is **sediment**: stale layers settle because adding feels safe and removing feels risky.
- A measurement goes stale with its model. Label every measurement with the model ID it ran on, never an alias such as `opus`: an alias moves to the next model at a release. After a model release, treat each measured status (load-bearing, no-op, saturated) as unverified until you run it again on the new model.
- Hunt **no-ops** sentence by sentence. A no-op is an instruction the model already obeys by default, so it pays load and says nothing. The test is one question: does this line change behaviour against the default? The test is model-relative. Two people who disagree about a no-op disagree about the default, and they settle it by running the document with `validate-prompt-rules`. A null result reads _no effect detected for this model and probe set_. That is grounds to nominate the line for deletion, and never proof the line is inert. When a sentence fails the test, delete the whole sentence rather than trim words from it. A leading word too weak to beat the default, such as _be thorough_, is a no-op too. Delete it, and put the demand in the completion criterion instead ("every modified model accounted for").
- A **rationale clause** is a no-op at inference: the rule moves behaviour, and the "why" appended to it does not. Keep a why only where a human maintainer would otherwise delete the rule, and put it in a `>` blockquote that cites the measurement. One sentence shape looks like rationale and is instruction: a sentence that closes an escape the sentence before it opened ("None of them lets the report name the problem and stop there").

## Reviewing a document

A review of a document you did not just write is its own branch. Seven recurring modes, each defined in a section above:

- **premature completion**
- **duplication**, and its cross-artifact form **derived-mirror drift**
- **sediment**
- **sprawl**
- **no-op**
- **negation**
- **ambiguity**

For a full review or a material rewrite, account for every one of the seven, and name each one as present, absent, or not applicable. For a scoped edit, check the touched meaning and its coupled artifacts, and report only actionable findings.

## Finishing a change

Before you change a sentence, look for its measurement: a `>` blockquote beside it, `maintainer-notes.md`, or a `measurements.md` next to the document. A measured wording has no slack. A shorter paraphrase of it is a behaviour change, not an edit.

A change is done when both hold:

- `audit.py` reports no new finding for the document.
- Every changed sentence with a measured wording is measured again with `validate-prompt-rules`, or your report names it as unmeasured.

`audit.py --all` checks every skill against the measurable rules. `audit.py refs` reports cross-references that point at a removed or user-invoked skill. **Call them, do not read them.** The findings they print are the whole contract, and the source is large.
