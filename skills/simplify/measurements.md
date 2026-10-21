# Measurements behind `simplify/SKILL.md`

## 2026-10-22, CHECKLIST rung 2 "Removed invariants" widened to bypassed lines

Origin: retro of session de4c5c82. A Tier 1 self-review missed that a new `exit 1 && stdout` branch in rtk `run_diff` routed around the branch that forwarded git's stderr. codex and the free reader both found it. The rung asked only about deleted or replaced lines.

Text probes, CHECKLIST as the skill body, live CLAUDE.md preloaded, NO_TOOLS, CLI 2.1.306, 333 calls, 0 errors. Hit = the one-line finding names the lost side effect. Arms: control (old rung), long (shipped), mid (long without the parenthetical), short ("DELETES, replaces or bypasses").

| probe | model | control | long | mid | short |
|---|---|---|---|---|---|
| P1 rtk run_diff, stderr forward | claude-sonnet-5-5 | 1/15 | 6/15 | 2/15 | 1/15 |
| P1 | claude-opus-5-5 | 12/15 | 14/15 | 11/15 | 12/15 |
| P2c Python renderer, stderr write + metric | claude-sonnet-5-5 | 4/10 | 9/10 | 2/10 | 1/10 |
| P2c | claude-opus-5-5 | 5/15 | 15/15 | 11/15 | 3/10 |
| P4b TS in-flight id never cleared (a kind long does not name) | both | 5/5 | 5/5 | 5/5 | 5/5 |
| P3 clean bypass, no false claim | claude-sonnet-5-5 | 7/7 | 6/7 | 7/7 | 7/7 |

- On sonnet the parenthetical carries the whole effect: mid scores at control level. Keep the parenthetical.
- P4 and its rebuild saturated, so whether naming kinds helps or hurts unnamed kinds is unsettled. long did not hurt them.
- P2 (original) saturated. P2b planted a second, louder defect and measured nothing. The scorer was revised to v4 after reading the data, with 4 hand overrides. v4 moved 6 P2c rows from miss to hit and narrowed the gaps.
- Kept long by total token cost. The two added phrases cost about 20 tokens per CHECKLIST load (estimated at 1.3 tokens per word, not counted). The short arm saves most of them but scores at control level, and a miss costs a fix round. The 20-word limit serves clarity, not cost. A shorter rewrite ships only when a run shows equal hits.
- Rows: `~/.claude/prompt-runs/2026-10-22-r1-checklist-rung2-bypass`, `~/.claude/prompt-runs/2026-10-22-r1b-checklist-rung2-mid`.

## 2026-10-22, rung 14 sub-items 1 and 5, unmeasured

Same retro. A sonnet implementer copied the repo's `#[ignore]` pattern, so its tests never ran in CI. A RED run used a stale `target/debug/rtk`. Item 1 now says to rebuild the binary the test runs. Item 5 covers tests the CI command never selects. Shipped without an A/B.

## 2026-09-11, from memory guardrail-model-is-not-a-reviewer

Measured 2026-09-11 on a four-defect diff fixture (timing attack, SQL injection via f-string, DEBUG default flipped on, unbounded session cache) plus a clean control diff. The model measured was `nvidia/nemotron-3-super-120b-a12b:free` (the memory's description writes it `nemotron-3-super-120b:free`). `free-reader.py` now calls `nvidia/nemotron-3-ultra-550b-a55b:free`, which these rows do not cover. The 4-of-5 located, invented failure_scenario, 52-line 4/4 and 2034-line 2.3/4 rows are in "Phase 3: Tier the dispatch" below and in `maintainer-notes.md`, `## Method notes`.

- `nvidia/nemotron-3.5-content-safety:free` is a 4B guardrail classifier. Its output is fixed to `User Safety: safe/unsafe` plus harm categories, and OpenRouter lists no `tools` in its supported parameters. Given the diff and an explicit request for findings it answered `User Safety: safe`. It also rated an exfiltration of `process.env` to an external endpoint `safe`. It does flag natural-language prompt injection pasted into a code comment (`unsafe / Criminal Planning`).
- `nvidia/nemotron-3-super-120b-a12b:free` reviewed: 4/4 defects across runs on the 52-line fixture, `Clean, no findings` on the control, 262K context, free, `tools` supported. It was wired into `simplify` as the Tiers 1-2 free third reader.
- Recall falls with diff size. The same four defects buried in a 2034-line diff scored 3/4, 2/4, 2/4 across three runs. It kept the timing attack and the SQL injection every time and dropped the quieter cache-staleness and DEBUG-default findings. Output shrank (3000-5600 tokens against 6000-11600 on the small diff). Three calls in parallel left one hanging past 200 s, so a per-dimension fan-out is not the fix. Dilution lives in the pasted diff, not in the checklist, so narrowing the instruction would not address it.
- 88% of the completion budget is reasoning tokens (6010 of 6842 on one run, leaving 832 for the report). 8000 max_tokens truncated mid-finding; the helper uses 16000.
- An external agent CLI in `-p` mode as transport failed four of five attempts (200 s+ timeouts, empty output); the one success demoted the highest-severity finding to a blind spot. The helper calls the OpenRouter endpoint directly and reads `OPENROUTER_API_KEY`, falling back to `~/.prime/agent/models.json`.
- Toolless reader, three trials, a diff whose defects resolve only outside the hunk window: it located four of five planted defects every trial and fabricated the failure_scenario every trial. For one generator-returning function it gave three different wrong scenarios (`len(tags)`, `if tags:`, `tags.append`) at confidence 93-95, while the real break was a caller consuming the generator twice. The location was right all three times.
- Feeding back the touched files as a second turn corrected the scenarios but bought little once the scenarios are discarded, so the helper takes the context pack as an optional third argument.
- One defect survived every read with the refuting code in front of it: a lock held across a network call.

Lessons the memory stated, with their status on 2026-10-22:
- Do not evaluate a content-safety classifier as a reviewer again. [not shipped: this record is enough]

## 2026-09-10, from memory fix-of-fix-is-review-loop

One client project, 139 `fix` commits on Sep 3-10 2026 against 47 feats, classified by five sonnet agents from commit bodies (88 high / 47 medium / 4 low confidence). Bundled review commits count once, so AUDIT is under-counted.

| root cause | n | what would have caught it at first write |
|---|---|---|
| LOOKUP: existing helper, second source of truth, other instance, live site or doc not read | 33 | grep or `ecp impact` before writing |
| LOGIC: empty array, array-not-scalar, unicode whitespace, in-flight race, dependency-failure branch | 41 | an edge-case test |
| AUDIT: fail-closed on wrong not just empty, path traversal via locale, SSRF on redirect, header leak, a11y, PHP 7.4 syntax | 26 | a second reader |
| VISUAL | 16 | render |
| SPEC / ENV / REGRESSION / INFRA | 23 | ask, run in env |

44 commits repair an earlier fix. 43 sit in the same PR as the commit they repair, all within an hour, 24 within 10 minutes. That is the review loop committed granularly, not defects that escaped. The type case (`5812b4a` then `c31f34b`, two minutes apart): the first commit found the second `columnGap` site and judged it unaffected because scroll-snap hid the symptom; the second traced the value into `perView()` and the dot count and reversed the verdict. The miss was a wrong verdict on a found hit, judged from the visible symptom, not a lookup failure. The question to ask is "which consumers of that site's value did you check", not "did you look". Classification rows: session scratchpad `fixes/*.jsonl`, rubric `fixes/RUBRIC.md`. Whether rules could have prevented these: `maintainer-notes.md`, 2026-09-11 entry.

CHECKLIST Altitude already carries the consumer rule.

## 2026-09-01, from memory skips-look-like-passes

One project: after a change to `to_postgres.py` only four test files ran (112 passed); none needed a database, and the database container had been down all night. The full suite then showed 544 passed, 208 skipped, all `pytest.skip("<db> is not up")`. That repo (and one more) turn "dependency absent" into a skip on purpose, so a broken environment looks like all green, and `-q` shows only an `s` among the dots. Starting the container brings it back; the data sits on a named volume. Update 2026-09-11: that repo's `tests/conftest.py` now calls `pytest.fail` when the DB is unreachable and skips only when a no-DB environment variable is set, so that repo's trap is closed.

Lessons the memory stated, with their status on 2026-10-22:
- Run the full suite before you hand over a conclusion, and read the skip count, not only the passed count. A jump from 1 to 208 skips is an environment problem. [shipped 2026-10-22: simplify/CHECKLIST.md, Ambient test state]
- When you quote a test count, say which run it came from; "750 passed" measured three commits ago is not the current state. [shipped 2026-10-22: simplify/CHECKLIST.md, Ambient test state]

## 2026-08-31, from memory comment-claims-need-reading

Two rounds of review in one session each caught a comment I wrote without opening the code it describes.
- `_stable_premium` hashes the id **and the line**: it hashes only `product_id`, and the line only feeds the range of `_UNITS`. I had used the sentence to argue that the catalog upsert WHERE needs to compare only two columns.
- `required` **guarantees the key exists**, so the `.get(k, "")` default is dead code: `required` is only a JSON-schema request to the model, and when `executor` cannot decode the JSON, `args = {}`. That default was the only thing that blocked a KeyError, and the second example nearly led someone to delete the safety net.

A wrong mechanism description is worse than none because it looks verified. The fix was to compare against what the code writes (the catalog WHERE now compares every column in the SET), which needs no reasoning and does not go stale. CHECKLIST rung 11 (Unverified claims) already states the read-the-function rule.

## 2026-08-23, from memory review-the-fix-not-just-the-bug

`multi-screen-recorder`. A Tier-3 `simplify` fan-out found 3 defects. The fix was 110 insertions across 5 files. The same Tier-3 fan-out on the fix found 4 more defects, 3 introduced by the fix:
- a lock-scope "improvement" that removed an unwritten mutual exclusion;
- a timeout written as a default parameter, so all 5 call sites inherited a bound only 1 wanted, and the one it hurt was the path whose only job is telling the user where the salvaged file went;
- a fallback plumbed to one of the two call sites that needed it, leaving the default path with the defect the commit set out to fix;
- two variables that used to move together decoupled, so a guard tightened for one no longer tightened for the other.

A third round on the fix of the fix found 3 more (2 documentation, 1 pre-existing), so the curve was 3, 4, 3 and did not converge. That round found the root cause of the original mistake, a comment: `/// Creates <stem>.webm.part, never overwriting an existing recording. All three names this take can end up under are claimed together, ...` sat six lines above a check-then-act (`if final_path.exists() || partial_path.exists()`). Releasing a lock before a rename looked safe because the comment said the names were already reserved.

After three of my own rounds, the work went to codex as implementer with the gate written as acceptance criteria. It moved the invariant from "every caller holds a lock" to check-create-recheck inside the constructor, which let three lock scopes come back out. It also left four defects, one measured by the reviewer with a probe: the recheck sees a name come free only when freeing it produced a destination, and the zero-byte branch removes the file and produces nothing. Same ratio as my rounds. Codex volunteered eight attack points; none was the zero-byte hole. A different prior changes the solution, not the defect rate.

`SKILL.md` Phase 2 already tiers a fix diff and a peer's diff by their own size and risk.

Lessons the memory stated, with their status on 2026-10-22:
- Point the reviewers of a fix at what the fix did, so they attack it instead of rediscovering the original bug. [not shipped: the reviewer preamble is a measured wording; needs an agentic A/B]
- A peer's own list of attack points is a starting set, not a substitute for review. [not shipped: one case]
- When a review finds a defect that "obviously" should have been caught, look for the artifact that made it look right (a false comment is a cause, not only a gap). [covered: simplify/CHECKLIST.md, Unverified claims]

## 2026-08-10, from memory verifying-an-upgrade-not-a-schema

Verifying the ecp 0.9.1 to 0.9.3 upgrade. Four lessons, each hit in practice:
1. A fixture tests the schema; real old data tests the migration. The other side's fixture test asserted "`file` defaults to an empty string and does not fail the row", and was green, and the assertion asserted the defect itself. Running 40 inbox entries written by the real 0.9.1 binary showed `File:` empty on every one.
2. Ask what the data's distribution cannot cover. All 40 entries sat in one file, so "the dedupe key collapses and loses data" never showed. Changing one peer by hand to span two files showed 9 entries vanish as a group.
3. Write the criterion before the run, and make it a count. For the variants I fixed "bob one entry if the bug exists, two if fixed" in advance, so seeing three left no room for interpretation. A single entry cannot be the criterion: when 0.9.2 collapsed nine, the surviving one had normal timestamps and fields. Only the count shows something is missing.
4. Measure, do not infer. I called a 25-minute CI job "over an hour" because I used a computed time as "now" and did not check UTC. The other side had already written the number into its repo memory before I corrected it.

Common shape: a test or observation guards a contract lower than the real need, so green stops tracking whether the feature works.

Lessons the memory stated, with their status on 2026-10-22:
- Before you trust a cross-version check, ask "if this assertion is always true, does the user get what they need?" [covered: simplify/CHECKLIST.md, Test that cannot go red, and Format upgrade]
- A stale or wrong observation recorded as normal builds a blind spot: a memory "X is a known behaviour" makes the next real X get skipped. Test a memory by what remains after you remove "it was once broken": delete what git can tell you; keep what takes reading the whole module (unresolved gaps, where the real dispatch is, which comment is stale). [not shipped: the harness memory guidance owns memory hygiene]
- In a cross-session message, label each content item measured, inferred or guessed. The receiver writes it into long-term memory with no reliability mark; second-hand measured numbers are the most dangerous, since they read most like fact. [shipped 2026-10-22: agent-routing/SKILL.md, A sub-agent's report]

## 2026-09-08, from memory rule-rationale-clauses-are-noops

Fifth replication of the rationale no-op finding, on `CHECKLIST.md`. It separates an inert rationale sentence from a load-bearing one that looks identical. The rule under test forces a review finding to carry its concrete fix. Leave-one-out, haiku (claude-haiku-4-5 (inferred from the date; the memory says only the family)), n=15 per arm, control 1/15:

- Deleting "The reader rejects a change you wrote, and cannot accept one you never wrote." (the rationale) changed nothing: 4-vs-8 in one run, 7-vs-6 in the next. Deleted.
- Deleting "None of them lets the report name the problem and stop there." collapsed the rule to control level: 2/15 with the rationale still present; the two arms that also dropped it scored 2/15 and 3/15.

The load-bearing sentence closes an escape the preceding sentence opened; the inert one explains why the rule exists. Tone and position do not discriminate. On sonnet the whole comparison saturates: every wording 14-15/15 against a 6/15 control, so the difference shows only on the weakest reader. `simplify` dispatches `lite-scan` (model: haiku) for the Reuse dimension, so haiku is a deployment reader of this checklist.

## Moved from SKILL.md, 2026-10-17
Each entry sat beside the rule it names. The rule text stays in SKILL.md.

### Phase 3: Tier the dispatch

Rule: Launch exactly one, and only at Tier 1 or Tier 2: its recall falls as the diff grows, and parallel calls hang. A `TRUNCATED` line at the end of its report means…

Measured 2026-09-11 on the earlier `nemotron-3-super-120b-a12b:free`, not yet on ultra: 4 of 5 planted defects located per trial, every failure_scenario invented, a lock held across a network call missed in every read; 4 of 4 on a 52-line diff, 2.3 of 4 on a 2034-line one.
