# catchup measurements

## Whole skill vs no skill, 2026-11-01

Source: pstack `ketchup` (cursor/plugins), merged without visuals, `/bro` voice and word counts. Preloaded A/B, control = no skill text, B = SKILL.md body, `NO_TOOLS=1`, claude-opus-5-5, n=5 per arm. Probe: summarised chat with four open calls (one raised before the user's last message), two PRs sharing a merge call, one self-doable task; user asks "catch me up, what do you need from me?". Rows: session 9a45f906 scratchpad `ab.XS6DSU/c5` (ephemeral). All 10 rows read by hand; the scorer matched each one.

| sub-hit | control | B |
|---|---|---|
| all four calls listed | 5/5 | 5/5 |
| every call carries a pick | 0/5 | 5/5 |
| every call carries a risk or gain/cost | 0/5 | 5/5 |
| the call raised before the last user message appears | 5/5 | 5/5 |
| the self-doable task kept out of the calls | 5/5 | 5/5 |

- Pick and risk: effect. [shipped]
- "Include every open call, also one raised before…", "Work you can do yourself is not a call" and "Never cut an item": no effect detected for this model and probe. The probe had four calls, so the no-cut rule was never under length pressure. Nominated, not deleted.
- Not run: the Gather step with tools (live `gh` and `ListAgents` checks), claude-sonnet-5-5, claude-haiku-5-5, a probe with 15+ calls.

## Sixteen open calls, claude-sonnet-5-5, 2026-11-01

Same arms (control = no skill text, B = SKILL.md body), `NO_TOOLS=1`, claude-sonnet-5-5, n=5. Probe: 16 open calls (6 PRs, 3 option choices, 3 access requests, 2 irreversible actions, 2 questions raised before the last user message) plus 3 self-doable tasks. Pick and risk scored by hand. Rows: session 9a45f906 scratchpad `ab.XS6DSU/c12.plWiwH` (ephemeral).

| sub-hit | control | B |
|---|---|---|
| all 16 listed as their own item | 5/5 | 5/5 |
| every call carries a pick | 0/5 | 4/5 |
| every call carries a risk or gain/cost | 0/5 | 2/5 |
| both older questions appear | 5/5 | 5/5 |
| self-doable tasks kept out | 5/5 | 5/5 |
| mean length | 2629 chars | 4160 chars |

- Pick: effect. Risk: partial effect on sonnet (claude-opus-5-5 was 5/5 at four calls). Control gave no pick on access requests or irreversible actions.
- "Never cut an item" and "include every open call": saturated on both models, at 4 and at 16 calls. Nominated for deletion; untested at 30+ calls.
- Deleted 2026-11-01, after both runs: "Include every open call, also one raised before the user's last message.", "Work you can do yourself is not a call." and the bullet "Never cut an item or shrink it to save length. A count or a link never replaces an item." Kept "Never invent a call to fill the reply." (never probed).
- Reworded 2026-11-01 at the user's request, to a positive form: "Never invent a call to fill the reply." became "Trace each call to its source: a message in this chat, a sub-agent report, or a live check. Check the source, and leave it out of the reply." Unmeasured: no probe has tested invented calls (a transcript with zero open calls would).
- Deleted 2026-11-01, the same day: the "Trace each call to its source" sentence. Gather steps 1 to 3 already name the sources (own work, sub-agent reports, other-session messages, live checks), so the sentence restated them. Unmeasured; re-add it only if a zero-call probe shows invented calls.

## "unknown" moved into Write step 4, claude-sonnet-5-5, 2026-11-01

"Write "unknown" for a fact you do not have" moved from Gather into Write step 4, which now names a change, evidence and risk line per item and says to keep a line as "unknown". Same 16-call probe, tools ON (deployed tool set), n=5 per arm, old = the SKILL.md before the move. Scored by hand by one sonnet scorer over 13 non-option items per row. Rows: session 9a45f906 scratchpad `ab.XS6DSU/c16.xF24Ss` (ephemeral).

| sub-hit | old | new |
|---|---|---|
| every call carries a pick | 5/5 | 5/5 |
| missing change lines (of 65) | 5 | 4 |
| missing evidence lines (of 65) | 10 | 1 |
| missing risk lines (of 65) | 20 | 4 |
| rows with no missing line | 0/5 | 1/5 |
| mean length | 3651 chars | 4524 chars |

- Effect on evidence and risk. [shipped] The remaining misses sit on the CSV question raised before the last user message.
- Measure this rule with tools ON. With `NO_TOOLS=1` the new wording turned 3 of 8 rows into fake `gh` / `ListAgents` calls with no reply (old wording: 0 of 10), so a tool-off run under-counts it.
