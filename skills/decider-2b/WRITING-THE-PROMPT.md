# Writing the prompt for Decider-2B

The practical half of [`SKILL.md`](SKILL.md): what to put in `instructions`, what to put in each
`criteria` sentence, and how to change either one. Every rewrite below carries the number it
produced, from https://github.com/coseto6125/decider-tetris.

## The two places text goes

`instructions` is one block, read once per question. It says what a good option is.
`criteria[id]` is one option, read against its siblings. It says what this option does.

The division is strict. **The instructions say what matters. The option says what happened.** A
fact that belongs in every option belongs in neither: it separates nothing and costs attention.

## The instructions

One paragraph. Name the goals in one sentence, then give the reason for the single goal whose cost
is not obvious.

```
Pick where to drop this piece in a game of Tetris. A good placement clears rows, traps no cell,
keeps the stack low, keeps the surface flat, opens no one-wide gap and sits against a wall rather
than in the middle. A trapped cell stays trapped until every row above it is cleared.
```

That is 53 words and it is the best measured version. What the measurements say about changing it:

- **A ranked list plays far worse than a flat sentence.** The same goals as "First… Second…
  Third… Fourth…" scored 0 rows against 41.
- **A goal the options already report still needs naming.** Every option had said "It sits against
  the left wall" from the start, and the instructions had never said a wall was good. Adding that
  clause took the run from 3894 to level with the baseline. The fact was already there; the
  preference was in no sentence the model read.
- **Length costs.** Every instruction block that grew lost. The three losing high-stack variants
  ran 72 to 82 words against the 53-word original.
- **State-dependent instructions work, and the ordering inside them decides how much.** Swapping in
  a second block once the state passes a threshold gained. Which clause leads it mattered more than
  the swap: the same clause placed first, second, and absent produced 6,018, 15,514 and 16,714.

## The option sentence

One fact per sentence. Short sentences, in a fixed order, so the same fact always appears in the
same position.

```
Traps nothing. Clears one row. It fills the lowest part of the stack. It sits against the right
wall. It lowers the top of the stack. It leaves the surface as uneven as it is now. It opens a
one-wide gap.
```

Four rules, each measured.

**State a change, not a level.** A level saturates: over a long run every option read "The stack is
high" exactly where the decision mattered. The same fact as a change keeps separating options at
any level.

| | rows |
|---|---|
| "The stack is high" | 139 |
| "It raises the top of the stack by two rows" | 243 |

**Grade the change when the plain form saturates.** Three-way wording collapses in the same way a
fixed band does. If the typical value sits at ten, a change of two and a change of eight both read
"more uneven". Give the large change its own words.

**Spell the number out to the point where it stops mattering.** "Several" covered everything above
four, so burying five cells and burying twelve read alike — and twelve was how the runs ended. The
word list now runs to ten, then "more than ten".

**Say the loss as a loss.** A sentence meant as the cost of an option gets read as its merit when
it names a virtue. "It fills the only column deep enough for an I piece" appeared on the option
that ended a run, beside two sentences that praised it. Rewritten as "It gives up the only column
deep enough for an I piece", it reads as the cost it is.

## Changing the prompt

The rule that governs every edit: **rewrite a sentence, do not add one.** Adding lost on six
attempts out of six. Rewriting is the only change that has ever gained.

That rule is not about length alone. A new sentence competes for attention against the ones already
there, and the ones already there are carrying the facts that matter. So the edit loop is:

1. Name the quantity you think the model is missing.
2. Correlate it against the sentences already present, over a few thousand real options. Five of
   six candidate "missing" facts turned out to sit between 0.91 and 1.00 with a sentence already
   written. Stop there when it does.
3. Pick the existing sentence that carries it worst, and rewrite that one.
4. Screen it with no model call: on real states, how often does the new wording give two options
   different text where the old wording gave them the same? A rewrite that separates nothing cannot
   change an answer.
5. Only then run the task end to end.

Two rewrites that passed step 4 and still lost are worth reading, because they lost the same way.
Both told the model to notice a property of where the option lands. Both times it complied, and
complying was the mistake: told not to raise the stack, it chose the flat placements that cover
cells; told to notice how low it lands, it landed low, into the pockets that then get covered.
Buried cells rose from 0.52 to 0.70 and 0.83, and the runs fell from 16,714 to 6,018 and 11,768.

**A property you name becomes a property it optimises.** Name only the ones you want optimised to
their limit.

## What not to send

- **A grid.** The board as 20 rows of text scored 41 pieces against 86 without it. The model's own
  card reports the same weakness on positional lookups. The same grid as TOON was worse again: 60
  pieces, because the per-element index markers add tokens without adding structure it can use.
- **One option alone.** Rating each option with its own yes/no question scored 11 rows against 18,
  and ran four times slower. An option rated alone has nothing to be better than. The model's
  strength is comparison.
- **Options sorted best-first.** 844 rows against 822 for the enumeration order. It flips individual
  picks and carries nothing, and it costs you the reproducibility that a fixed order gives.
