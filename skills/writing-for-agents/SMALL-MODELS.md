# Writing for a small model

This file covers a local model smaller than haiku, such as Decider-2B or NanoJev, that reads a question and option
text and returns a choice. Several `SKILL.md` levers point the other way for this reader.

> Evidence: Decider-2B Q8_0, 71 real routing prompts in Traditional Chinese, 9 option sets of 5 to 10, one labeller,
> 2026-09-19. The same set tuned and scored every wording, so each count is optimistic, and a gap of 1 or 2 is noise.
> Scores are out of 71. Baseline: 55. The large model that the small model replaces: 60.

## Rules

1. **Keep the surface forms.** A small model matches strings more than intent. Frame each option in one English
   sentence, and quote a few phrasings that real users type, in their language. (Abstract intent sentence: 54 to 57.
   Invented phrasings: 60. Real-traffic phrasings: 63. Option text fully in the input language: not measured.)
2. **Cut each option to that one sentence.** Remove the cross-references between options ("prefer X over Y when …")
   and the long example lists. (55 to 62.)
3. **Remove context that does not bear on the decision,** such as a persona or a style guide. (Plus 1 to 2.)
4. **Put each rule in the option text that it governs.** The model mostly ignores a rule in the question, and the rule
   can flip a correct answer. (Plus 2, with one correct answer lost.)
5. **Give each kind of input to exactly one option.** Build the option text per option set. Example: on a social bot,
   drop the greeting clause from out_of_scope when companion_chat is present. (63 to 65.)
6. **Write a catch-all option narrowly.** State the exact condition that makes "ask a clarifying question" correct.
   General wording attracts picks.
7. **Hold a fixed budget.** Each option keeps one sentence and its current count of phrasings. The question keeps one
   sentence. Fix a miss by rewriting or swapping text: a new phrasing replaces an old one. The budget is a design
   choice, not a measured limit. It follows the trend above: cutting scored best, and adding scored least.
8. **Route low confidence to a larger model.** (Below 0.7: 13 to 16 prompts routed, 68 to 69 correct, above both
   models alone.)

## Review

Run the seven review modes of `SKILL.md` on every change. The budget adds no exemption. For this reader, check the
option set as one unit, because the model reads every option against every other:

| Check | What to find | Fix |
|---|---|---|
| Overlap | Two options that claim the same input | Give the input to one option (rule 5) |
| Contradiction | A question or option text that pulls against another option | Remove the losing clause |
| Dangling reference | Option text that names an option absent from this set | Remove the reference |
| No-op | Text whose removal changes no pick on the labelled set | Delete it |
| Sprawl | Text past the budget | Cut to the budget (rule 7) |

Test a no-op by deletion: remove the text, rescore, and keep the removal when the score holds.

## Levers from SKILL.md that change

- **Class and instance:** rule 1 makes the instance list required.
- **Leading words:** a small model holds fewer priors. Prefer the literal term that the input uses.
- **Negation:** not measured for this reader. Use the `SKILL.md` default.

## Completion criterion

A change is done when it stays inside the budget, passes every review check, scores on a labelled set, and scores
again on a held-out set. A wording that wins only on the tuning set is not done.
