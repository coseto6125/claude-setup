---
name: rust-perf
description: Rust performance measurement and the Rust traps that pass review — A/B under binary-layout noise, profiling without perf, rayon's memory cost, lock-guard scope. Use when optimising, benchmarking, or reviewing Rust code, when a Rust perf claim needs proof, and before delegating Rust work to a sub-agent.
---

# Rust Performance and Review Traps

The model writes correct Rust syntax. It fails in two other places: it declares an optimisation a win without a measurement that can see it, and it accepts a change that reads as an improvement but drops a guarantee. This skill covers both.

When you delegate Rust work to a sub-agent, paste the relevant lines into its prompt. A sub-agent without the Skill tool cannot load this file.

## Measure before you claim

A proposed fix is a hypothesis. That includes a follow-up's `next-action`, a commit message that argues from ratios, and your own first guess. Profile the stage costs first, then pick the fix.

1. **Compute the ceiling.** Count the operations the change removes and multiply by their unit cost. When the ceiling is inside the noise, drop the change without building it.
   > Measured: a skip justified by "81% of nodes have no calls" had a ceiling of 84M cheap compares, about 20 ms of 6.85 s (0.3%). The A/B read noise.
2. **Find the real stage.** Instrument each phase with a temporary `eprintln!("[t] phase {:?}", t.elapsed())` patch. Remove the patch before the commit. This works where `perf`, `strace` and `valgrind` are absent (WSL2 has no PMU).
3. **Split aggregated telemetry.** Read a median per repo and per mode. One busy repo can own the whole tail of a mixed median.
4. **Subtract the fixed cost.** Process start, `mmap` of the data file and subprocess spawns count against every run. Measure them once and report the query cost without them.

### A/B protocol

- Build release binaries only. Debug and release differed 5x on the same hook, so a debug number predicts nothing.
- Interleave the runs of every binary. Report the median and p10.
- Record peak RSS with `/usr/bin/time -f "%e s %M KB"`.
- Diff stdout between the binaries. A faster binary with different output is a bug, not a win.
- Gate the result on three conditions: stdout identical, RSS not up, wall time down beyond noise.

### Layout noise needs a third binary

A change to unrelated code moves the binary layout. The layout alone moves wall time by about ±3%. A two-binary A/B therefore cannot see a regression under 5%.

> Measured: one change read +5%, +1% and +3.5% across three rounds. A binary whose hot path was byte-identical to the baseline ran 4 ms faster than the baseline.

Use three binaries and one control workload:

| Binary or workload | Content |
|---|---|
| `base` | the main branch |
| `new` | the change |
| `variant` | the change, with the changed hot function restored byte-identical to `base` |
| control workload | a heavy query that never enters the changed code |

Read the result this way:

- `variant` matches `base`, and all three binaries are flat on the control workload: the difference is real and sits in that function.
- `variant` is as slow as `new`: the difference is layout noise.

Rebuild `variant` after every edit to the change. A stale `variant` contaminates the comparison.

## Parallelism costs memory

Parallelise a stage only when the profile shows that the stage is more than 30% of wall time.

`rayon` on allocation-heavy work keeps each thread's heap resident, because the allocator (mimalloc) retains per-thread memory. Check RSS on every parallel change, not only wall time.

> Measured: parallel parse on 16 threads gave 3.1 s to 2.9 s wall (-7%) and 138 MB to 350 MB RSS (600 MB without chunking). The change was dropped.

A parallel map with a serial merge must produce byte-identical output to the serial path. Write an equivalence test that compares both paths before you measure speed.

## Traps that pass review

### A `match` scrutinee holds its lock guard

```rust
match m.lock().unwrap().state() { ... }   // the guard lives until the match ends
let s = m.lock().unwrap().state();         // the guard drops at the semicolon
match s { ... }
```

The temporary in a scrutinee lives to the end of the whole `match` statement. Binding it to a local first releases the lock at the semicolon. When an arm acts on the state the scrutinee checked, that early release opens a check-then-act race: another thread can change the state between the check and the act. Request changes on this move unless the arms are independent of the checked state.

When the code does not show whether an arm depends on the hold, run a probe: print `m.try_lock().is_ok()` inside the arm, for both forms.

### Lints that replace review rules

These two lints are off by default. Enable them in `[workspace.lints.clippy]` instead of relying on a reviewer:

| Lint | Catches |
|---|---|
| `wildcard_enum_match_arm` | a `_ =>` arm that silently absorbs a new enum variant |
| `undocumented_unsafe_blocks` | an `unsafe` block without a `// SAFETY:` comment |
