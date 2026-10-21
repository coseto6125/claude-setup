# Measurements behind `rust-perf/SKILL.md`

## Moved from SKILL.md, 2026-10-17
Each entry sat beside the rule it names. The rule text stays in SKILL.md.

### Measure before you claim

Rule: 1. **Compute the ceiling.** Count the operations the change removes and multiply by their unit cost. When the ceiling is inside the noise, drop the change witho…

Measured: a skip justified by "81% of nodes have no calls" had a ceiling of 84M cheap compares, about 20 ms of 6.85 s (0.3%). The A/B read noise.

### Layout noise needs a third binary

Rule: A change to unrelated code moves the binary layout. The layout alone moves wall time by about ±3%. A two-binary A/B therefore cannot see a regression under 5%.

Measured: one change read +5%, +1% and +3.5% across three rounds. A binary whose hot path was byte-identical to the baseline ran 4 ms faster than the baseline.

### Parallelism costs memory

Rule: `rayon` on allocation-heavy work keeps each thread's heap resident, because the allocator (mimalloc) retains per-thread memory. Check RSS on every parallel chan…

Measured: parallel parse on 16 threads gave 3.1 s to 2.9 s wall (-7%) and 138 MB to 350 MB RSS (600 MB without chunking). The change was dropped.
