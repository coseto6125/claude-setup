---
name: writing-for-agents
description: 'Use when writing or reviewing any document an agent reads: a skill, AGENTS.md, CLAUDE.md, a sub-agent prompt, a tool description, or a prompt file the project feeds to a model.'
---

Reference for any document an agent reads: a skill, an `AGENTS.md` or `CLAUDE.md`, a doc reached by a pointer. The packaging differs. The writing does not. The same levers make each one predictable. Predictable means the agent takes the same _process_ every run. It does not mean the agent produces the same output.

When the document is a skill, read [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md) for frontmatter, invocation choice, and router skills.

## Context pointers

A **context pointer** is a reference held in the agent's context. It names material that sits outside the context, and it encodes the condition to reach that material. A skill's description is a pointer. A line in `AGENTS.md` that names a doc is the same object.

The pointer's _wording_ decides when the agent reaches the material, and how reliably. The target does not. A must-have target behind a weak pointer is a variance bug. Sharpen the wording first. Inline the material only after the sharper wording fails.

A pointer does two jobs. It states what the material is. It lists the **branches** that trigger the reach. A branch is a distinct case the document handles, so different runs take different paths through it.

Every word of an always-loaded pointer costs on every turn. Prune a pointer harder than a body:

- **Front-load the leading word.** The pointer is where that word does its triggering work.
- **Write one trigger per branch.** Synonyms that rename a single branch are one branch written twice. Collapse them, and keep only the branches that genuinely differ.
- **Cut the identity the body already carries.**

## The two loads

Every document and every pointer spends one of two budgets:

- **Context load** is the cost on the agent's window. An `AGENTS.md` line, a skill description, and anything else that sits in context every turn spend tokens and attention whether or not they fire.
- **Cognitive load** is the cost on the human: which documents exist, and when to reach for each. The human is the index. Do not minimise this cost. It is the price of human agency. Spend it where human judgement matters, and remove it where human judgement does not.

Material behind a pointer escapes context load, and pays the pointer's own line instead. Material with no pointer rides entirely on cognitive load.

## Information hierarchy

A document holds two content types. **Steps** are the ordered actions the agent performs. **Reference** is the definitions, rules and facts the agent consults on demand. The two mix freely: all steps (a recipe), all reference (a review's rules, this skill), or both.

The core decision is where each piece sits on the **information hierarchy**. The hierarchy ranks material by how immediately the agent needs it.

1. **In-file step** is the primary tier: what the agent does, in order.
2. **In-file reference** is consulted on demand. It is often a flat peer-set, such as every rule of a review on one rung. A flat peer-set is a fine arrangement, not a smell.
3. **Disclosed reference** sits in a separate file behind a context pointer. The agent loads it only when the pointer fires. It spans a sibling file in the same folder through external reference that lives anywhere, and that any document can point at.

Push too little down and the top bloats. Push too much down and you hide material the agent needs. That tension is the whole decision.

**Progressive disclosure** is the move down the ladder, out of the main file and behind a pointer, so the top stays legible. It is not primarily a token optimisation. It is how you protect the hierarchy. Branching gives the cleanest test: inline what every branch needs, and disclose what only some branches reach. In a document with steps, in-file reference that belongs behind a pointer buries those steps, and the agent then attends to them at random. That makes disclosure a variance lever, not only a legibility one.

**Co-location** is the within-file companion. The ladder decides how far down a piece sits. Co-location decides what sits beside it. Keep a concept's definition, rules and caveats under one heading, so that reading one part brings its neighbours with it. The test: the document reads like documentation written for the agent. Grouped material reads that way, and scattered material does not. Co-location differs from duplication. Duplication repeats one meaning in two places. Scattering fragments one meaning across many places.

**Sprawl** is the failure mode here. The document is simply too long, even when every line is live and unique. Attention thins across the excess, and each extra line is one more line to keep relevant. The ladder is the cure. Disclose reference behind pointers, and split by branch or by sequence, so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a **completion criterion**: the condition that tells the agent the work is done. Two properties make the criterion a lever.

**Clarity** answers one question: can the agent tell done from not-done? A vague bound such as "understanding reached" invites **premature completion**. The agent ends the step before the work is done, and its attention slips to _being done_. The **post-completion steps**, the visible steps still ahead, supply that pull. The criterion's clarity is the resistance. Defend in this order. Sharpen the bound first, because that fix is local and cheap. Split the sequence to hide the later steps only when the bound is irreducibly fuzzy _and_ you observe the rush. Hiding works only across a real context boundary, such as a hand-off or a subagent dispatch. An inline call leaves the later steps in context and clears nothing.

**Demand** is how much the criterion requires. "Every modified model accounted for" forces thorough work. "Produce a change list" does not. Demand drives **legwork**, the digging the agent does inside the work. Legwork stays latent in the wording, and you do not write it as its own step. Demand is not step-bound. "Every rule applied" binds a body of flat reference the way "every step done" binds a sequence. That is how an all-reference document still carries an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## When to split

A split into two documents spends one of the two loads. Split only when the cut earns it.

- **By sequence.** Split a run of steps when the post-completion steps tempt the agent to rush the step in front of it. Hidden later steps drive more legwork on the current task. Watch the reverse case: a merge exposes each step's later steps to what follows, and invites premature completion.
- **By invocation.** This cut is skill-specific. See [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md).

## Leading words

A **leading word** is a compact concept that already lives in the model's pretraining, and that the agent thinks with while it runs the document. _Lesson_, _fog of war_ and _tracer bullets_ are leading words. Repeat the word as a token, never as a sentence. It then accumulates a distributed definition. It anchors a whole region of behaviour in the fewest tokens, because it recruits priors the model already holds. A word you coin yourself works if you define it clearly. A made-up word recruits no priors, so you pay in definition tokens what a pretrained word gives free. Reach for an existing word first.

A leading word anchors twice. In the body it anchors _execution_. The agent reaches for the same behaviour every time the word appears. Inside flat reference the word focuses attention on a class of thing to look for. In a pointer it anchors _invocation_. Put the same word in your prompts, your docs and your codebase. The agent then links that shared language to the material, and reaches it more reliably.

Hunt for passages that refactor into leading words. A triad spelled out at three sites is one such passage. A pointer that spends a sentence to gesture at one idea is another. Each one collapses into a single token:

- "fast, deterministic, low-overhead" becomes _tight_ (a _tight_ loop).
- "a loop you believe in" becomes _red_. A fuzzy gate becomes a binary observable state: the loop goes _red_ on the bug, or it does not.

You win twice: fewer tokens, and a sharper hook for the agent to hang its thinking on. Assume every document carries restatements that leading words retire, and go find them.

**Negation** is the failure mode beside this lever. A prohibition drags the forbidden behaviour into context, and makes it _more_ available, not less. _Don't think of an elephant_, and the elephant is all there is. The negation is a weak modifier, the strongly-activated concept overruns it, and the ban half-reads as an instruction to do the thing. Prompt the **positive** instead. State the target behaviour ("write one-line comments"), so you never speak the banned one. A prohibition earns its place only as a hard guardrail that you cannot phrase positively. Even then, pair it with the positive target, so attention lands on what to do. Before you rewrite an existing red line as a positive, A/B both wordings with `validate-prompt-rules`, and keep the negative if the rewrite measurably leaks.

## Sentence style

Write every sentence to **ASD-STE100**, the aerospace standard for Simplified Technical English:

- Give each word one meaning, and each meaning one word. Pick a term and reuse it, instead of rotating synonyms.
- Write in the active voice and the present tense, with simple verb forms. "The agent reads the file", not "the file is to be read".
- Put one instruction in one sentence. Keep a procedural sentence under 20 words, and a descriptive one under 25.
- Keep the articles and prepositions that mark structure (`the`, `of`, `that`). Keep a noun cluster to three words.
- Replace a phrasal verb with the single plain verb. Write "start the job", not "spin up the job".
- Write two sentences instead of one semicolon. STE bans that one mark, and permits every other one.
- Put a sequence of actions on separate lines, one action per line.

**Keep every hedge at its original strength.** A sentence that promotes _may_ to a fact states a different claim, so let it run long instead.

> Measured inert on Claude models: control preserved the hedge 15/15 on haiku and on opus, even under a 10-word cap. Kept because the failure is real for other writers, and because the cost of the wrong direction here is a false claim.

**Ambiguity** is the failure mode here: the agent can read a sentence two ways, or the sentence runs so long that the action inside it is buried. Either way the agent guesses, and the run varies.

Language splits two ways in one document, and authors conflate them. Write the document itself in English, and keep its rules in English. The agent's user-facing output is a separate choice, so name that output language as an instruction inside the document. `CLAUDE.md`'s Language rule holds the authority on which output goes to which language.

STE's rules split in two, and only one half is checkable here. The **structural** rules describe sentence shape, so you apply them from the description alone. The **lexical** rules are defined by ASD's approved dictionary, which this skill does not carry. Apply the lexical rules as a direction of travel. Hold one term per concept inside your own document, and claim no dictionary compliance. A defined leading word survives this rule, because STE admits technical names and approved technical verbs. Coin the word once, define it, then spend that one token on that one meaning everywhere.

> Rule numbers and the semicolon detail come from ASD-STE100 Issue 9 (Jan 2025): 53 rules in 9 sections, over a dictionary of ~900 approved words. Fuller public summary, including the structural/lexical split this section borrows: https://github.com/danyuchn/asd-ste100-skill

Apply STE to the sentences, not to the document's shape. The hierarchy, the disclosure and the completion-criterion levers still decide what goes where.

## Pruning

- Keep each meaning in a **single source of truth**: one authoritative place, so a behaviour change is a one-place edit. **Duplication** puts the same meaning in more than one place. It costs maintenance and tokens, and it inflates a meaning's prominence on the ladder past its real rank. Duplication is the accidental inverse of a leading word, which repeats a token on purpose and never the meaning. Its cross-artifact form is **derived-mirror drift**: two documents that express one policy disagree. Name the authority, then align the mirror or remove it. An always-loaded summary of a canonical policy is worth keeping aligned, and is not automatically a copy to delete.
- The **environment** is a source of truth too: `package.json` scripts, config files, the directory layout, `--help` output. A document that restates the environment is a **cache**, a copy of a lookup. A cache earns its load only when the lookup is expensive. Cache what the agent cannot find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses. Leave the one-file and one-command lookups to the environment, where they cannot go stale.
- Check every line for **relevance**: does the line still bear on what the document does? A line loses relevance in two ways. It never bore on the task, because it is mere exposition, or a branch that belongs behind a pointer. Or it goes stale as the behaviour or the world it describes changes. A shorter document is easier to keep relevant. Without a pruning discipline the default fate is **sediment**: stale layers settle because adding feels safe and removing feels risky, until you must core down through them to find what is still live.
- Hunt **no-ops** sentence by sentence. A no-op is an instruction the model already obeys by default, so it pays load and says nothing. The test is one question: does this line change behaviour against the default? The test is model-relative, not reader-relative. Two people who disagree about a no-op disagree about the default, and they settle it by running the document, not by debate. Run the document isolated with `validate-prompt-rules`. A null result reads _no effect detected for this model and probe set_. That is grounds to nominate the line for deletion, and never proof the line is inert. When a sentence fails the test, delete the whole sentence rather than trim words from it. The test also grades leading words. A word too weak to beat the default, such as _be thorough_ when the agent is already thorough-ish, is a no-op. The fix is a stronger word such as _relentless_, not a different technique.

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

## Auditing a skill you wrote

`audit.py --all` checks every skill against the measurable rules; `audit.py refs` reports cross-references that point at a skill which was removed or is user-invoked only. **Call them, do not read them** — the findings they print are the whole contract, and the source is large.
