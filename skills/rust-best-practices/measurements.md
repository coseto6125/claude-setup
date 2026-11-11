# Measurements and upstream sync for `rust-best-practices`

## Upstream

Fork of https://github.com/morganlinton/BeautifulRust, plugin version 1.4.0, synced at commit `c6f56d2` (2026-10-26). MIT; `LICENSE` here and in `rust-port/` is the upstream file.

Three upstream skills map to three local homes:

| Upstream | Local home |
|---|---|
| `skills/rust-best-practices/` | this skill, one inline `SKILL.md` |
| `skills/rust-port/` | `~/.claude/skills/rust-port/` |
| `skills/rust-review/` | `~/.claude/skills/simplify/rust.md`, opened in simplify Phase 1 and named in `CHECKLIST.md` |
| `lints/lints.toml`, `lints/clippy.toml` | `lints/` here, verbatim |

Upstream `evals/` are not copied. Clone upstream into the scratchpad to run them.

## Local divergences

Keep these on the next sync. Each one is deliberate.

| Where | Upstream | Local | Reason |
|---|---|---|---|
| description | fires on any mention of Rust, including debug and explain | fires before writing or refactoring | 29.5 KB per Rust touch; review belongs to `simplify`, debug to `diagnose` |
| §2 fmt | `cargo fmt` | `rustfmt --edition <e> <changed files>` | measured 2026-10-27: `cargo fmt -- src/a.rs` also reformatted `src/b.rs` |
| §2 clippy, test | whole workspace | `heavy-run -- ... -p <crate>` | machine-wide CPU lock on this host |
| §2 lints | suggest upstream lints for a project without `[lints]` | propose two or three lints that caught a problem, edit config only on request | `pedantic`, `unwrap_used`, `as_conversions`, `print_stdout` flood an existing crate |
| §10 docs | `///` on every public item | library crates only; apps match surrounding density | global CLAUDE.md comment-density rule |
| §12 perf | "Design for usability first and optimize after measuring" | pointer to `rust-perf` | this workspace is performance-first; `rust-perf` owns measurement |
| §11 tests | "Write a failing test before fixing a bug" | removed | global CLAUDE.md Test Discipline states it |
| §3 clone | "Don't clone to make the borrow checker stop complaining" and its §13 item | removed | A/B below |
| rust-port §6 | write `PORTING.md` | notes in the reply or PR body | workspace rule: create docs only on request |
| rust-review | standalone review skill, report only | rungs inside `simplify`; pointer in Phase 1 | `simplify` is the one review skill; it fixes what it finds. A pointer only in `CHECKLIST.md` reached 1/3 runs |

## A/B 2026-10-27

Archive: `~/.claude/prompt-runs/2026-10-27-2026-10-27-rust-fork-skill-ab`. Every arm preloads the real CLAUDE.md and skill list, so the control is not bare. Graders read code; nothing was compiled.

| Case, `claude-sonnet-5-5`, n=3 | control | fork (split layout) | upstream verbatim |
|---|---|---|---|
| semver (10) | 21/30 | 26/30 | 21/30 |
| logsum (8) | 22/24 | 21/24 | 23/24 |
| refactor (12) | 18/36 | 31/36 | 36/36 |

- The local description fired 15/15 on the writing cases. Upstream's fired 4/9, and missed semver 3/3. It fired 0/3 on "add a `len` method". "審一下這個 Rust diff" went to `simplify` 3/3.
- The split layout lost refactor points. A run that opened `api-design.md` scored 12/12, a run that did not scored 7/12. The file opened in 3 of 15 loads (`claude-opus-5-5` 0/6). The layout is now inline again, and `audit-exemptions.md` records rule 2.
- §3 clone section: on two borrow-conflict tasks the skill loaded 0/8 times, and control chose a clone-free fix 6/7. No effect detected; deleted, given the earlier harm of the same rule in `rust-perf`.
- Review probe, `simplify` on the rust-review module, 7 issues: control 15/21, fork 16/21. The `CHECKLIST.md`-only pointer reached `rust.md` in 1/3 runs, so the pointer moved to Phase 1.

## A/B round 2, 2026-10-27

Archive: `~/.claude/prompt-runs/2026-10-27-rust-fork-skill-ab-r2`. Same preload, CLI 2.1.311, cases and grader brief as round 1; 6 round-1 runs blinded in as anchors agreed on every assertion.

| Case, `claude-sonnet-5-5`, n=3 | R1 control | R1 upstream | R2 fork inline |
|---|---|---|---|
| semver (10) | 21/30 | 21/30 | 28/30 |
| logsum (8) | 22/24 | 23/24 | 23/24 |
| refactor (12) | 18/36 | 36/36 | 32/36 |
| total | 61/90 | 80/90 | 83/90 |

- Refactor on `claude-opus-5-5`, n=2: fork inline 24/24, against R1 control 13/24.
- One sonnet refactor run in three kept the old API (8/12). Upstream redesigned 3/3.
- Review probe with the Phase 1 pointer, sonnet n=3: `rust.md` opened 3/3, issues named 19/21 (R1 control 15/21). The bool parameter on `report` is still missed 2/3.
- Not re-run on the inline skill: the clone probe and the routing probes.
