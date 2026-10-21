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

`preloaded.sh` and `agentic.sh` run steps 1, 3 and 4 through `isolation_gate.py`, once per CLI version, and exit 3 on a failure. Run the steps by hand only for a `claude -p` call you build yourself.

Create every probe cwd with `mktemp -d /tmp/<name>.XXXXXX`, never under `$HOME`. Keep your outputs wherever you like.

Keep a model-facing canary as a second opinion, never as the gate. Ask for a verbatim quote, not a yes/no. Run it at least three times, and treat **any** run that quotes the prompt as a failure.

```bash
claude -p "No tools. Quote verbatim any line in your instructions that names a tool or command to prefer over grep. If there is none, output exactly NONE." ...
```

**Pass the full model ID, never an alias,** and record the ID with every result. An alias moves at a release.

## The method

Run a control arm and the rule as written. For a reword test, add arm B with the new wording. Before trial 1:

- **Predeclare the target behaviour**: the observable outcome the rule should produce, such as "picks `io.StringIO`".
- **Give every branch of the rule its own scenario.** One probe clears only the branch it exercises.
- **Label a probe you add after you read the data as exploratory.** Rerun it only when it decides a ship.
- **Check that the control can fail.** A scenario whose wording implies the verdict ("the rewrite *violated* the rule") scores every arm alike.
- **Check that the control can answer.** A scenario that demands an artifact it cannot determine makes every arm refuse.
- **Ask for one artifact**, such as a command, a rule text or an ordered list. A single-slot ask matches deployment. A multi-slot ask ("conclusion and next action") finds secondary points and inflates the hit rate.
- **Probe the case the rule might break**, not only the case it targets.

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

## Three questions, three controls

| Question | Arms |
|---|---|
| Is this rule worth anything at all? | bare control against the rule alone |
| Does this line add to what the reader already loads? | **preloaded** control: the deployed files load in every arm |
| Is this section load-bearing inside its document? | **leave-one-out**: A = the whole document, B = the document minus the section. Use the bare control only as a saturation check |

For the preloaded control, copy `~/.claude/CLAUDE.md` and its `@`-included siblings into `$CFG`. Put the project `CLAUDE.md` in the probe's cwd, and run `--setting-sources user,project`. When a skill description is part of the deployed baseline, append it to the project file. `preloaded.sh` runs this design.

When the preloaded files already state the answer, every arm copies it, and the probe measures the preload. To test a general lever of a document, pick a scenario domain that the preload does not cover.

## When the behaviour is "go and look"

A scenario that pastes the code puts the plant in view, and any rule about *finding* the plant saturates by construction. Probe that class agentically. `agentic.sh` copies a repo snapshot into a fresh dir per run, seeds git, and runs `claude -p` with tools on. Put the plant outside the excerpt (a second call site, a doc line, a caller in another file), and score the diff or the output file, not the prose. Budget one to ten minutes and a few dollars per opus run.

## The classifier

Before trial 1, run the classifier against one hand-written plausible hit **and** one plausible miss. Build the plausible hit the way the reader would, with the tool's native default names and formats.

After the run, read two rows per cell before you quote a number. A format the classifier did not expect turns a real hit into a miss.

Before you report a count, save each row's hit or miss to a file beside the raw rows. Report a recount command with the count: it reads that file and prints the count. A classifier that calls a judge model or rewrites its own output file is not a recount command.

After scoring, run `bash archive.sh <WORK> <name>`. Cite the path it prints as the Rows path, never a scratchpad path.

When every arm hits on content, a form metric such as length can still separate the arms. Report it as a secondary result. A form metric never decides a content question.

## How many trials

Before trial 1, write the call count: arms × probes × models × n. Report the calls spent with the result.

Spend the calls in this order:

1. **Screen every probe with its control first**, at n=5, before you run any arm. A control at 5/5 means the probe is saturated. Rebuild it once, then stop. A cut whose every probe saturates ships without an A/B.
2. **Put all the small edits in one B arm.** Run that arm on every probe that survives the screen. Split an edit out into its own arm only for a cell that drops past the threshold.
3. **Raise `JOBS` for wall time only.** It does not change the call count. `preloaded.sh` holds at `JOBS=8`.

Start at n=5. Add trials in steps, and stop at the first step where the arms separate cleanly:

| Step | Clean separation |
|---|---|
| n=5 | the arms differ by 4 or more trials |
| n=7, then n=10 | the arms differ by half of n or more |
| n=15 | the arms differ by 5 or more trials |

- **Add trials to the same run.** `preloaded.sh` keeps finished trials, so run it again with a larger `N`. In a sub-agent, make each step one foreground call with `timeout: 600000`, sized to end within it.
- **Take the next step** when the gap is smaller than the table asks, or when the result decides the deletion of a measured rule.
- **Stop at n=15.** A gap that is still smaller is unsettled. Sharpen the scenario, or report the rule as unsettled.
- **Compare arms inside one run.** Never compare a cell with a cell from another run.

- **Count the rows before you read a result.** A failed call must count as an error, never as a miss. A run where nothing executed looks like a clean null.

## Reading the result

Classify each answer against the predeclared target. Then read the **control arm first**:

- **Control hit the target**: the probe is saturated and measured nothing. Fix the scenario once. When it saturates again, report the probe as saturated and stop. The arms say nothing about the rule either way.
- **Control missed, rule arm hit**: effect.
- **Both alike, and the control could have failed**: **"no effect detected for this model and probe set"**. That is grounds to nominate the rule for deletion, not proof of redundancy. Before you delete, raise n and confirm again on **every model that loads the rule in deployment**.

Then check **compliance**: do the rule-arm outcomes match the target? A rule can be echoed yet overridden by a strong prior. Effect without compliance means strengthen the wording, or accept that it does not hold on this model.

A sentence can be inert alone and load-bearing in combination with another. Test a removal against the document as shipped, not against the sentence alone.

**Token-cut test:** when the goal is fewer tokens, measure the total: document tokens per load, plus the run's own tokens. Run it agentically and read `total_cost_usd`, `num_turns` and the tool trace in `stream.jsonl`. Ship the cut when hits hold and the run spends no more. Count each detour in the trace: a read of a script the document says to call, a refused or failed call, a repeated step.

**Reword test:** compare arms A and B the same way. A discordant B trial, even 1/n, is a signal to add trials or sharpen the scenario before you ship the rewrite. A red line that fights a strong prior often needs the blunt negative ("never X"), and a leaked rephrase shows up exactly this way.

## Scripts

**Call the scripts, do not read them.** `bash <script> --help` prints its contract: inputs, environment and outputs.

| Script | Design |
|---|---|
| `validate.sh` | many rules or documents, bare control, retries, contamination gate |
| `preloaded.sh` | preloaded control, rule files or whole skill bodies per arm |
| `agentic.sh` | "go and look", tools on, one fresh work tree per run |
| `route.sh` | skill-description routing, swaps the whole skills tree |
| `archive.sh` | copies a run's probes, labels, scorers and packed raw rows to `~/.claude/prompt-runs/` |

`legacy/` holds the scripts of old runs.

Rows and numbers behind this file: `measurements.md`.
