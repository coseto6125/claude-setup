# python-perf measurements

## Benchmarks section, added 2026-11-01

Source: pstack `benchmark-checklist` (cursor/plugins, "Write the decision before you run"). Preloaded A/B, control = SKILL.md without the section, `NO_TOOLS=1`, claude-opus-5-5, n=3 per arm (stopped early at 0/3 vs 3/3). Probe: "switched loader.py from json to msgspec, write the bench brief for a sub-agent". Rows: session 9a45f906 scratchpad `ab.XS6DSU/c2` (ephemeral).

| sub-hit | control | B |
|---|---|---|
| a: decision result written before the first run | 0/3 | 3/3 |
| b: baseline spread as noise floor, inconclusive inside it | 0/3 | 3/3 |

- Effect. [shipped]
- At least one B row pastes the three lines verbatim: compliance, not independent generalisation.
- Not run: claude-sonnet-5-5, claude-haiku-5-5.

## Benchmarks moved behind a pointer, 2026-11-01

The three lines moved to `benchmarks.md`. SKILL.md keeps "Before you write a bench brief, read `benchmarks.md`." The skill loads on every Python write, and only the bench branch needs the lines. Tool-on run (`--tools Read`, Read allowed on the skill dir), body prefixed with the Skill tool's base-directory line, claude-opus-5-5, same probe. Rows: session 9a45f906 scratchpad `ab.XS6DSU/c6` (ephemeral).

| arm | a | b | Read on benchmarks.md |
|---|---|---|---|
| inline | 4/4 | 4/4 | n/a |
| pointer | 5/5 | 5/5 | 5/5 |

- Pointer is not worse than inline. [shipped]
- One extra pointer row, with Read denied by permissions, scored 0 on a and b. The deployed default mode is `bypassPermissions`, so the denial does not apply here.
