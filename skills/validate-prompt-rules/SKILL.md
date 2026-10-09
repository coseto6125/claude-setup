---
name: validate-prompt-rules
description: Use when testing whether a prompt rule (CLAUDE.md, system prompt, or skill text) actually changes model behavior — before trusting, deleting, or rewording it — or when a no-rule baseline may be contaminated.
---

# Validate Prompt Rules

A rule in a prompt is a *claim* that the model behaves differently because of the rule. The claim is often false: the model ignores the rule because a prior wins, or the model already does it without the rule. Reading cannot tell you which. Run an isolated A/B comparison against a clean baseline.

**Core principle: the conclusion is only as clean as the no-rule baseline.** If the "without the rule" arm still loads the rule, every conclusion is contaminated.

## When to use

- Before you delete a rule because "the model does this anyway".
- Before you reword, shorten or move a rule that carries a measurement.
- Before you rewrite a red line as a positive.
- After a model release, for each rule whose status was measured on the previous model.
- When two arms tie and the baseline may load the rule.

## Isolation

`~/.claude/CLAUDE.md` is a **user setting-source**. Skills load in `-p` too. Only this combination removes both:

| Attempt | Result |
|---|---|
| `--system-prompt "..."` | replaces the *default* prompt, not the user source: **CLAUDE.md still loads** |
| `--exclude-dynamic-system-prompt-sections` | CLAUDE.md is not a dynamic section: **still loads** |
| `HOME=/tmp/empty` | drops CLAUDE.md *and* `~/.credentials.json`: **auth breaks** |
| `--setting-sources project` from an empty dir | leaked `~/.claude` 4/4 on 2026-09-02 |
| `--setting-sources user,project` with the probe cwd under `$HOME` (a scratchpad included) | the CLI walks up from the cwd and loads the live `~/.claude/CLAUDE.md` and `~/.claude/rules/` as project files |
| an empty `CLAUDE_CONFIG_DIR` without `--disable-slash-commands` | the CLI writes `skills/synced/` into it during the run, and 25 bundled and claude.ai skills load (2.1.280) |
| **`CLAUDE_CONFIG_DIR=<dir you built>` + `--setting-sources user` + `--disable-slash-commands`** | the user source is that directory, and no skill loads. Copy `.credentials.json` into it, and auth survives |

```bash
CFG=$(mktemp -d); printf '{}' > "$CFG"/settings.json
cp ~/.claude/.credentials.json "$CFG"/                  # auth, not a setting-source
(cd "$(mktemp -d)" && CLAUDE_CONFIG_DIR="$CFG" claude -p "..." --model claude-haiku-5-5 \
   --setting-sources user --disable-slash-commands --strict-mcp-config --mcp-config '{"mcpServers":{}}')
```

Prove the isolation in both directions before trial 1:

1. Write a sentinel line to `$CFG/CLAUDE.md`. The model must quote it.
2. Remove the file. The model must answer NONE.
3. Ask the model to list every skill it can invoke. It must answer NONE.
4. From the probe cwd, with the trial's `--setting-sources`, ask for a line that exists only in the live `~/.claude/CLAUDE.md`. It must answer NONE.

Create every probe cwd with `mktemp -d /tmp/<name>.XXXXXX`, never under `$HOME`. Keep your outputs wherever you like.

> Measured 2026-10-09 on claude-haiku-5-5, one run, n=10 per side: one preloaded arm scored 6/10 with its cwd under `/tmp` and 0/10 with its cwd in a scratchpad under `$HOME`. The scratchpad cwd loaded the live `CLAUDE.md`.

> Verified 2026-10-09, CLI 2.1.295, on claude-haiku-5-5, claude-sonnet-5-5 and claude-opus-5-5: the sentinel came back with the file, and NONE came back without it. With `--disable-slash-commands`, the skill list returned NONE. Without it, the skill list returned 25 names on CLI 2.1.280.

Keep a model-facing canary as a second opinion, never as the gate. Ask for a verbatim quote, not a yes/no. Run it at least three times, and treat **any** run that quotes the prompt as a failure.

```bash
claude -p "No tools. Quote verbatim any line in your instructions that names a tool or command to prefer over grep. If there is none, output exactly NONE." ...
```

> Measured: this wording caught a known-contaminated config 2 of 3 runs. A gate that reads a Yes/No token passed a contaminated control 3 times in 4.

**Pass the full model ID, never an alias,** and record the ID with every result. An alias moves at a release.

## The method

Run a control arm and the rule as written. For a reword test, add arm B with the new wording. Before trial 1:

- **Predeclare the target behaviour**: the observable outcome the rule should produce, such as "picks `io.StringIO`".
- **Give every branch of the rule its own scenario.** One probe clears only the branch it exercises.
- **Check that the control can fail.** A scenario whose wording implies the verdict ("the rewrite *violated* the rule") scores every arm alike.
- **Check that the control can answer.** A scenario that demands an artifact it cannot determine makes every arm refuse.
- **Ask for one artifact**, such as a command, a rule text or an ordered list. A single-slot ask matches deployment. A multi-slot ask ("conclusion and next action") finds secondary points and inflates the hit rate.
- **Probe the case the rule might break**, not only the case it targets.

> Measured: on a scenario whose wording implied its own verdict, control and rule arms scored alike 5/5. On a generative one, the control went 0/5. A multi-slot ask turned a 1/5 into a 5/5.

Inject a rule with `--append-system-prompt` into an otherwise clean process. Inject a whole skill as the body the Skill tool delivers: the skill text first, then the scenario, in the prompt.

```bash
(cd "$(mktemp -d)" || exit 1
SCN="You build a string from 200 pieces. What do you use?"
ASK="Report ONLY the single key decision this situation forces, as one short clause. No explanation, no tools."
ISO=(--setting-sources user --disable-slash-commands --strict-mcp-config --mcp-config '{"mcpServers":{}}')
# control
CLAUDE_CONFIG_DIR="$CFG" claude -p "SITUATION: $SCN

$ASK" --model claude-haiku-5-5 "${ISO[@]}"
# A (B: the reworded rule)
CLAUDE_CONFIG_DIR="$CFG" claude -p "SITUATION: $SCN

$ASK" --model claude-haiku-5-5 "${ISO[@]}" \
  --append-system-prompt "RULE you follow: build strings >100 pieces with io.StringIO"
)
```

**Probe on the model that reads the artifact in deployment.** The main session reads `CLAUDE.md` and skills. A sub-agent reads its brief, and `CLAUDE.md` when it is a Claude Code agent. Add haiku when a haiku sub-agent reads the same text. A null on one model is no deletion licence for a rule that another model reads.

> Measured 2026-10-06 and 2026-10-09: the `ECP.md` explore-trigger paragraph was inert on claude-opus-5-5 (5/5 in every arm) and load-bearing on claude-haiku-5-5 (1/15 without it, 14/15 with it).

## Three questions, three controls

| Question | Arms |
|---|---|
| Is this rule worth anything at all? | bare control against the rule alone |
| Does this line add to what the reader already loads? | **preloaded** control: the deployed files load in every arm |
| Is this section load-bearing inside its document? | **leave-one-out**: A = the whole document, B = the document minus the section. Use the bare control only as a saturation check |

For the preloaded control, copy `~/.claude/CLAUDE.md` and its `@`-included siblings into `$CFG`. Put the project `CLAUDE.md` in the probe's cwd, and run `--setting-sources user,project`. When a skill description is part of the deployed baseline, append it to the project file. `preloaded.sh` runs this design.

When the preloaded files already state the answer, every arm copies it, and the probe measures the preload. To test a general lever of a document, pick a scenario domain that the preload does not cover.

> Measured 2026-09-23 on claude-opus-5-5: two probes on CSV splitting and on codex escalation scored 5/5 in all three arms, because the preloaded `CLAUDE.md` holds both rules word for word.

## When the behaviour is "go and look"

A scenario that pastes the code puts the plant in view, and any rule about *finding* the plant saturates by construction. Probe that class agentically. `agentic.sh` copies a repo snapshot into a fresh dir per run, seeds git, and runs `claude -p` with tools on. It leaves `diff.patch` and the tool trace. Put the plant outside the excerpt (a second call site, a doc line, a caller in another file), and score the diff, not the prose. Budget one to ten minutes and a few dollars per opus run.

> Measured 2026-09-11: the historical miss the rule targeted was fixed 3/3 by the preloaded control in a fresh session. The rule arm matched it and cost 30% more.

## The classifier

Before trial 1, run the classifier against one hand-written plausible hit **and** one plausible miss.

After the run, read two rows per cell before you quote a number. A format the classifier did not expect turns a real hit into a miss.

Before you report a count, save each row's hit or miss to a file beside the raw rows. Report a recount command with the count: it reads that file and prints the count. A classifier that calls a judge model or rewrites its own output file is not a recount command.

> Measured: a static `Http::timeout(` versus `->timeout(`, a test class named `…BatchTest`, and a copied `(bool)` cast each turned a real 5/5 into a reported 1/5. On 2026-09-23, "change the sentence back" missed a `revert|restore` pattern, and a negated "do not judge whether it is risky" tripped a `risky` miss pattern.

When every arm hits on content, a form metric such as length can still separate the arms. Report it as a secondary result. A form metric never decides a content question.

## How many trials

Start at n=5. Add trials in steps, and stop at the first step where the arms separate cleanly:

| Step | Clean separation |
|---|---|
| n=5 | the arms differ by 4 or more trials |
| n=7, then n=10 | the arms differ by half of n or more |
| n=15 | the arms differ by 5 or more trials |

- **Add trials to the same run.** `preloaded.sh` keeps finished trials, so run it again with a larger `N`.
- **Take the next step** when the gap is smaller than the table asks, or when the result decides the deletion of a measured rule.
- **Stop at n=15.** A gap that is still smaller is unsettled. Sharpen the scenario, or report the rule as unsettled.
- **Compare arms inside one run.** Never compare a cell with a cell from another run.

  > Measured 2026-10-09 on claude-haiku-5-5: five runs of one arm scored 8 to 11 of 15, inside sampling noise. A cwd change between two runs moved the same arm from 6/10 to 0/10.

- **Count the rows before you read a result.** A failed call must count as an error, never as a miss. A run where nothing executed looks like a clean null.

## Reading the result

Classify each answer against the predeclared target. Then read the **control arm first**:

- **Control hit the target**: the probe is saturated and measured nothing. Fix the scenario. The arms say nothing about the rule either way.
- **Control missed, rule arm hit**: effect.
- **Both alike, and the control could have failed**: **"no effect detected for this model and probe set"**. That is grounds to nominate the rule for deletion, not proof of redundancy. Before you delete, raise n and confirm again on **every model that loads the rule in deployment**.

Then check **compliance**: do the rule-arm outcomes match the target? A rule can be echoed yet overridden by a strong prior. Effect without compliance means strengthen the wording, or accept that it does not hold on this model.

A sentence can be inert alone and load-bearing in combination with another. Test a removal against the document as shipped, not against the sentence alone.

**Reword test:** compare arms A and B the same way. A discordant B trial, even 1/n, is a signal to add trials or sharpen the scenario before you ship the rewrite. A red line that fights a strong prior often needs the blunt negative ("never X"), and a leaked rephrase shows up exactly this way.
## Scripts

**Call the scripts, do not read them.** The output is the whole contract.

| Script | Design |
|---|---|
| `validate.sh` | many rules or documents, bare control, retries, contamination gate, `results.jsonl` |
| `preloaded.sh` | preloaded control, probe JSONs (`scenario`, `ask`, `hit_regex`, `scope`), rule files or whole skill bodies per arm |
| `agentic.sh` | "go and look", tools on, scores a diff |
| `route.sh <skills-dir> <n> <model>` | skill-description routing, swaps the whole skills tree |
| `ab.sh`, `tourney.sh` | legacy: `--setting-sources project` isolation, kept for old runs |

Rows and numbers behind this file: `measurements.md`.
