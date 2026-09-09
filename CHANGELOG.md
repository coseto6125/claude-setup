# Changelog

Tagged versions start at v0.1.0. The history before it is untagged: see the git log for the
initial import, the live-config sync, and the skills README rebuild.

## v0.1.0 — 2026-09-09

### Changed

- `skills/eli5` Part 1 now infers the reader, and applies the ELI5 method at that reader's
  own level.
  - Step 1 opens on two axes. **Level** is the vocabulary the audience sets. **Method** is
    how the explanation is built, and it holds for every audience. An engineer keeps
    `mutex`, `backpressure` and `p99`, explained the ELI5 way.
  - The age-5 default is gone. When the request names no audience, the skill infers the
    reader from the material and from the words the user wrote, then names that reader in
    one line. A bare `ELI5` with no other signal still means age 5.
  - The frontmatter description follows the same change.

Measured on haiku with `validate-prompt-rules`, n=15 per arm, isolated through
`CLAUDE_CONFIG_DIR`:

| probe | no skill | before | after |
|---|---|---|---|
| engineer named, terms kept and ELI5 method used | 3/15 | 5/15 | 14/15 |
| no audience named, question written in engineer vocabulary | 13/15 | 5/15 | 14/15 |
| analogy drawn from a 15-year-old's world | 0/15 | pending | 15/15 |
| manager named, impact and a decision to take | 6/15 | pending | 15/15 |
| 8-year-old named, no surviving jargon | 15/15 | 15/15 | 15/15 |

The second row is why the default changed. `default to "Age 5"` scored 5/15 against a 13/15
no-skill control on a question written in engineer vocabulary: it pulled an engineer's
question down to a child's explanation.

### Measured, and left unchanged

- The four audience tables. Replacing them with one class-level sentence dropped the
  15-year-old analogy probe from 15/15 to 2/15, against a 0/15 control.
- The three worked examples. Removing them dropped the same probe from 28/30 to 17/30 over
  two rounds.
- Part 2 rule 9, which caps a list at five items. It is inert on haiku (5/15 against a 4/15
  control) and load-bearing on opus (14/15 against 8/15). Opus is the deployed reader, so
  the rule stays.

`pending` marks a before-number still running: those two probes were built after the
rewrite, so the old wording has not been through them yet. Both rows report the new
wording against a no-skill control, which is what the row's other two numbers say.
