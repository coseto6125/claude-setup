---
name: decider-2b
description: How to call and tune a local Decider-2B (system-one) endpoint — the /v1/systemone wire shape, the option-order pull and when to re-read, what belongs in a red line instead of the prompt, and the measurement discipline that separates a real gain from a sampling accident. Use when building on a local decision model, writing or rewriting the options and instructions it reads, or judging whether a prompt change actually helped.
---

# Decider-2B

A 2B model that answers a typed question in one forward pass and returns calibrated probabilities.
It does not reason, plan or count. It ranks described options. Everything below is measured on the
v8 checkpoint; the reproduction is https://github.com/coseto6125/decider-tetris.

## Calling it

`POST /v1/systemone`. One request carries several questions, and each question carries its options
as `criteria`, a map from the id the model answers with to the sentence it reads.

```json
{"state": {"piece": "T", "surface": "flat"},
 "questions": {"move": {"type": "choice",
                        "instructions": "Pick where to drop this piece.",
                        "criteria": {"r0c3": "Traps nothing. Clears one row.",
                                     "r1c7": "Traps two cells. Clears no rows."}}}}
```

The answer carries `choice`, `confidence` (calibrated), and `probabilities` over the ids. Types are
`choice`, `noul` (yes/no/unknown) and `score`.

The contract takes up to 255 options. The card reports the accuracy drop on full label sets, and
training used at most ten candidates per example, so group long lists into questions of ten to
twenty and run the group winners against each other.

Serving the open checkpoint: `LocalDecider(checkpoint)` puts the checkpoint's own `decider` package
on `sys.path`, so the weights directory must carry its `*.py` files, not only the safetensors. It
captures a CUDA graph for 78 shapes before the first answer, about a minute on an 8 GB card. After
that, about 43 ms per question.

Writing or rewriting the `instructions` block or the option sentences is its own job, with its own
worked rewrites and the numbers each one produced: [`WRITING-THE-PROMPT.md`](WRITING-THE-PROMPT.md).

## What this checkpoint is like

Four properties, each measured, each costing rows when ignored.

**Concrete and short beats complete.** Adding a sentence to an option or to the instructions lost
on six attempts out of six. Rewriting a sentence already there is the only change that has ever
gained. The same four goals written as a ranked list ("First… Second… Third…") scored 0 against 41
for one short sentence.

**A saturating fact is no fact.** A sentence true of nearly every option separates nothing. "The
stack is high" read the same on every option in the regime where the choice decided the outcome.
Rewriting it as a change from the current state — "It raises the top by two rows" — keeps its edge
at any level. Before writing a fact, ask what fraction of options will carry it identically.

**The option order pulls the score.** Asking one position twelve times under twelve orders: the
picks that held had a mean top-two gap of 0.34, and the picks that flipped had 0.12. The model
separates similar options by less than the pull of the leading position. Read the list once
forwards, and only when the top two are within 0.15 read it once backwards and add the two
distributions. That costs about 1.3 questions per decision, involves no random draw, and keeps one
input producing one answer.

**Actionability is not usefulness.** An instruction that fires on nearly every option competes with
every other goal in the prompt. One that fires rarely and decides the outcome when it does is worth
more. Measured by ranking one clause three ways in the same prompt: absent, second, first. The cost
rose monotonically with its rank.

## Where the logic goes

Put arithmetic in code and judgement in the model. Code deletes; it does not persuade.

A **red line** removes an option that can never be right, before the model sees it. On the measured
task the red lines took 22.8 reachable options down to 3.3, and every gain after the first came
from a new red line rather than from better wording. Three that generalise:

- An option that is dominated on the one thing that is irreversible is never right. Delete it.
- A red line that leaves one option is the code playing, not the model. Relax it there, and gate
  the relaxation on the state where the trade actually reverses.
- One step of lookahead is arithmetic, not judgement. Delete the option that leaves the next input
  with no good move at all.

Before writing a new fact, check it is not already carried. Correlate the quantity against the
sentences already present. On the measured task five of the baseline's six features sat between
0.91 and 1.00 with an existing sentence, and the two attempts to write the loose one as its own
sentence both lost. **The model usually sees enough. What it cannot do is weigh.**

## Judging a change

**Make the run deterministic first, and prove it.** One input plus one option order must give one
answer. Python randomises string hashing per process, so a tie broken by iteration over a set makes
one seed produce different runs: measured at 3894, 1863 and 322 on one configuration. Run the same
input under two `PYTHONHASHSEED` values and compare. Every comparison made before determinism holds
is unusable.

**Check whether the headline number is saturated.** A number pinned at its ceiling cannot show a
difference. Divide the metric by its theoretical maximum. When it sits at the maximum, the metric is
a restatement of how long the run lasted, and you need a second measure with more samples in it.

**Agreement with a strong baseline does not predict the outcome.** Measured directly: the variant
with the best agreement produced the worst run. Score on the outcome, never on how often the model
matched a reference decision.

**Screen before you spend.** A rewrite can only change an answer where it gives two options
different text. Counting that costs no model call and rules out the rewrites that cannot matter.

**One run against one run proves nothing** when the outcome is heavy-tailed. Two samples of one
process differ by two times about a third of the time. Rank the change three ways instead, or run
the same configuration on several inputs. A monotone response across three levels is evidence; a
single pairwise win is not.

## v8 and v10

v10 continues v8 with calibration-aware reinforcement learning on browser click tasks and on games
with an exact probability law. Its card reports the browser gain in sampled play, not in the argmax.
Measured on the same task, same flags, one run each: mean confidence 0.578 to 0.649, second readings
0.397 to 0.256 of the decisions that reached it, and no cleaner a result. v10 is the more decisive model and about ten
per cent cheaper per decision. Do not assume it is the better judge without measuring your own task.
