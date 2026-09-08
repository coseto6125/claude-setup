---
name: validate-prompt-rules
description: Use when testing whether a prompt rule (CLAUDE.md, system prompt, or skill text) actually changes model behavior — before trusting, deleting, or rewording it — or when a no-rule baseline may be contaminated.
---

# Validate Prompt Rules

A rule in CLAUDE.md is a *claim* that the model behaves differently because of it — often false: the model ignores it (loses to a prior), or already does it without it. You can't tell by reading. Run an isolated A/B comparison against a clean baseline.

**Core principle: the conclusion is only as clean as the no-rule baseline. If the "without the rule" arm still loads the prompt, every conclusion is contaminated** — and the usual isolation flags don't actually disable CLAUDE.md.

## When to Use

- Is a rule worth its tokens, or already the model's default?
- Before deleting a rule ("the model does this anyway")
- Before rewording one (does the new wording preserve behavior? does a positive rewrite weaken a red-line?)
- Verifying a rule survives the weakest reader — Haiku sub-agents inherit CLAUDE.md too

## The trap: which isolation actually works

`~/.claude/CLAUDE.md` is a **user setting-source**, not a dynamic system-prompt section. Only `--setting-sources` removes it:

| Attempt | Result |
|---|---|
| `--system-prompt "..."` | replaces the *default* prompt, not the user source → **CLAUDE.md still loads** |
| `--exclude-dynamic-system-prompt-sections` | CLAUDE.md isn't a dynamic section → **still loads** |
| `HOME=/tmp/empty` | drops CLAUDE.md *and* `~/.credentials.json` → **auth breaks** |
| `--setting-sources project` from an empty dir | drops the project source, **leaks `~/.claude`** — measured below |
| **`CLAUDE_CONFIG_DIR=<dir you built>` + `--setting-sources user`** | ✅ the user source is that directory, so an empty one loads nothing; copy `.credentials.json` into it and auth survives |

> Measured: an agent whose control used `--system-prompt` got identical 0/10-vs-0/10 arms and wrongly concluded "no effect"; the real signal only appeared under `--setting-sources project` — which is cleaner than `--system-prompt`, and still not clean.

> Measured 2026-09-02: under `--setting-sources project` from an empty dir, four runs of the canary below each recited `~/.claude/ECP.md`'s command table, and three opened with "No." A gate that reads the Yes/No token passes a contaminated control three times in four.

## First: confirm isolation

A contaminated control fakes "no effect", so build the isolation you can assert rather than one you interrogate. `CLAUDE_CONFIG_DIR` **is** the user-source root, so a directory you built holds every user file the run can see:

```bash
CFG=$(mktemp -d); printf '{}' > "$CFG"/settings.json
cp ~/.claude/.credentials.json "$CFG"/ 2>/dev/null      # auth, not a setting-source
ls -A "$CFG"                                            # the whole user surface: assert what is here
(cd "$(mktemp -d)" && CLAUDE_CONFIG_DIR="$CFG" claude -p "..." \
   --model haiku --setting-sources user --strict-mcp-config --mcp-config '{"mcpServers":{}}')
```

> Verified both directions: a sentinel written to `$CFG/CLAUDE.md` came back verbatim 2/2; with that file removed the model invented an answer 2/2. So an empty `$CFG` loads nothing, and `ls -A` is the proof.

Keep a model-facing canary as a second opinion, never as the gate — ask for a verbatim quote rather than a yes/no, run it at least three times, and treat **any** run that quotes the prompt as failure. `validate.sh` runs one automatically (`CANARY_Q` / `CANARY_RE`, matching `[Yy]es|ECP`, so it catches a recitation the "expect No" reading would pass); override both when testing a prompt other than this user's global CLAUDE.md.

```bash
claude -p "No tools. Quote verbatim any line in your instructions that names a tool or command to prefer over grep. If there is none, output exactly NONE." \
  --model haiku --setting-sources user
# Expect NONE on every run. One quoted line → isolation FAILED; the arms would measure the leak, not the rule.
# Measured: this wording caught a known-contaminated config 2 of 3 runs, which is why `ls -A` is the gate and this is the smoke test.
```

**Call the scripts here, do not read them.** `audit.py --all` and `audit.py refs` print every finding, and `route.sh <skills-dir> <n> <model>` prints the routing tally. Their source is large and reading it buys nothing the output does not already say.

## The method

Control and the rule as written — plus arm B for a reword test — isolated, **n≥3 per arm**: a smoke test, not proof. Before running: **predeclare the target behavior** (the observable outcome the rule should produce, e.g. "picks io.StringIO"), and give **every behaviorally distinct branch of the rule its own scenario** — one probe clears only the branch it exercises. **Check the control can fail, and that it can answer at all**: a scenario stating the evidence in words that imply the verdict ("the rewrite *violated* the rule") scores every arm alike and measures nothing, while one demanding an artifact the scenario can't determine makes every arm refuse. Asking for an artifact — a command, an ordered list — beats a yes/no when the scenario supplies what the artifact needs.

> Measured: on a scenario whose wording implied its own verdict, control and rule arms scored alike 5/5 and the probe measured nothing; on a generative one, control went 0/5 and twice proposed renaming the user's live CLAUDE.md.

Inject the rule via `--append-system-prompt` into an otherwise-clean process — you control the exact wording, nothing else leaks:

```bash
(cd "$(mktemp -d)" || exit 1   # empty dir — no project CLAUDE.md leaks into any arm
SCN="You build a string from 200 pieces. What do you use?"
ASK="Report ONLY the single key decision this situation forces, as one short clause. No explanation, no tools."

# control — bare default, no rule
claude -p "SITUATION: $SCN

$ASK" --model haiku --setting-sources project

# A — rule as written  (B: same, with the reworded rule, for reword tests)
claude -p "SITUATION: $SCN

$ASK" --model haiku --setting-sources project \
  --append-system-prompt "RULE you follow: build strings >100 pieces with io.StringIO"
)
```

Probe on **Haiku** first — the weakest reader that loads the prompt is the stress test. For many rules — plus retries, randomized arm order, per-probe metadata, and an automated contamination gate — use `validate.sh`.

## Reading the result

Classify each answer against the predeclared target behavior, then evaluate two questions:

1. **Effect** — read the **control arm first**, then the rule arm. Three outcomes:
   - **Control hit the target** — the probe is saturated and measured nothing. Fix the scenario; the arms say nothing about the rule either way.
   - **Control missed, rule arm hit** — effect.
   - **Both alike, and the control could have failed** — **"no effect detected for this model and probe set"**: grounds to nominate the rule for deletion, not proof of redundancy. Before actually deleting, raise n and reconfirm on **every model that loads the rule in deployment** — a rule can be inert on Haiku yet load-bearing on Opus, or vice versa.
2. **Compliance** — do rule-arm outcomes match the target? A rule can be echoed yet overridden by a strong prior — effect without compliance means strengthen the wording, or accept it won't hold on this model.

**Reword test:** compare arms A and B the same way. A discordant B trial (even 1/n) is a signal to add trials or sharpen the scenario before shipping the rewrite — red-line rules that fight a strong prior often need the blunt negative ("never X"), and a leaked rephrase shows up exactly this way.

> Measured: a red-line's positive rewrite let Haiku violate it in 1/3 trials while the blunt negative held 3/3.

