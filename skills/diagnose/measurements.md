# diagnose measurements

## Description trigger, 2026-10-15

The live description is V1: "Debug a failing test or wrong output. Invoke the moment it appears, before your first edit, and again when a fix leaves it red or a brief says debug." A rewording is a behaviour change: measure it again.

n=10 per cell, synthetic Python shop repo, a Skill tool_use with skill "diagnose" counts as invoked. Rows and scripts: session c64f7175 scratchpad `ab-e4-diagnose.md` and `diag-ab.3pw7G8/`.

| Probe | Model | Previous description (three branches) | V1 |
|---|---|---|---|
| Brief says "debug" | claude-sonnet-5-5, sub-agent | 0/10, paired rerun 0/10 | 9/10, paired rerun 10/10 |
| First fix leaves it red | claude-opus-5-5, main session | 0/10 | 10/10 |
| First fix leaves it red | claude-sonnet-5-5, sub-agent | 0 of 9 applicable | 1 of 8 applicable |
| Red test during a feature brief | claude-sonnet-5-5, sub-agent | 0 of 8 applicable | 0 of 8 applicable (probe confounded: the cause was visible before the red) |
| One-line typo (guard) | claude-sonnet-5-5, sub-agent | 0/10 false fires | 0/10 false fires |
| One-line typo (guard) | claude-opus-5-5, main session | 0/10 | invoked 10/10, all 10 stopped at the fit check |

Open: sonnet does not follow the implicit moment branches. In the same probes sonnet still fixed the root cause without the skill: 20/20 runs removed the shadowing package, 0 edited a test. On the feature probe it updated two expected values that the brief made correct, added tests, deleted no assertion, and reported the change with how to revert it.

Invoking is not following: in the V1 runs that invoked, 2 of 29 ran a phase marker. The rest judged the fit check passed after reading the code.
