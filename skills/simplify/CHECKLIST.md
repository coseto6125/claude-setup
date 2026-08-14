# Review Checklist

The shared rungs for [`simplify`](SKILL.md) and any skill that points here. A section is done when **every** rung under it has ended as either a finding or an explicit "clear" — a partial sweep is not a review.

## Spec (intent)

Applies only when a spec source resolved; with none, record "no spec available" and move on. This axis reports on its own and is never merged into the others: code can follow every convention, pass every correctness rung, and still implement the wrong thing, so a clean sweep elsewhere must not read as spec conformance.

1. **Missing or partial requirements** — something the spec asked for that the diff doesn't deliver; quote the spec line
2. **Scope creep** — behaviour in the diff nobody asked for; quote the hunk and name the spec section it fails to trace to
3. **Implemented but wrong** — a requirement the diff appears to cover, where the implementation contradicts what the spec described

## Correctness (bugs)

1. **Logic errors** — inverted conditions, off-by-one, wrong operator, dead branches that should be live
2. **Boundary/empty cases** — empty input, zero/one element, max sizes, saturating vs wrapping arithmetic
3. **Error-handling gaps** — swallowed errors, unwrap/expect on fallible paths reachable in production, partial-failure states left inconsistent
4. **Null/None/undefined flows** — optional values dereferenced on paths where absence is possible
5. **Concurrency** — racy check-then-act, shared state without synchronization, lock ordering, await points invalidating earlier reads
6. **Resource lifecycle** — leaks (files, sockets, listeners), double-free/double-close, missing cleanup on early return
7. **Contract breakage** — callers relying on the OLD behavior of a changed function; `ecp impact --target X --direction upstream` enumerates them, verify each one survives the change
8. **Security** — injection (SQL/shell/path), unvalidated external input crossing a trust boundary, secrets in logs

## Reuse

1. **Existing utilities that replace new code** — graph first (`ecp find "upsert bot" --repo .`, `ecp inspect --name BotInfo --repo .`) finds matches grep misses; reach for grep once the graph comes back empty
2. **New function duplicating existing functionality** — name the existing one at file:line
3. **Inline logic an existing utility covers** — hand-rolled string manipulation, manual path handling, custom env checks, ad-hoc type guards

## Quality

1. **Redundant state** — duplicates existing state, cacheable-derivable values, observers that could be direct calls
2. **Parameter sprawl** — new params instead of restructuring existing ones
3. **Copy-paste with variation** — near-duplicate blocks needing a shared abstraction (`ecp find` confirms whether one is already canonical)
4. **Leaky abstractions** — exposing internals or breaking abstraction boundaries (`ecp inspect` shows the boundary)
5. **Stringly-typed code** — raw strings where constants / enums / branded types exist
6. **Unnecessary JSX nesting** — wrapper elements adding no layout value
7. **Nested conditionals 3+ deep** — flatten with early returns, guard clauses, lookup tables
8. **Nested ternaries** — replace with `match`/switch or if-else chains
9. **WHAT-comments** — delete (identifiers say it); keep only non-obvious WHY

**Readability guardrail** — a fix must make the code *easier to read*, not merely shorter. Reject clarity-for-line-count trades: dense one-liners, over-clever collapses, merging distinct concerns, dropping an abstraction that earned its place.

## Efficiency

1. **Unnecessary work** — redundant computation, repeated reads, duplicate API calls, N+1
2. **Missed concurrency** — independent operations run sequentially
3. **Hot-path bloat** — new blocking work in startup / per-request / per-render paths; `ecp impact --target X --direction upstream --repo .` shows whether it sits in one
4. **Recurring no-op updates** — unconditional store updates in polling loops; verify wrappers honour same-reference returns
5. **TOCTOU existence checks** — operate directly and handle the error instead of pre-checking
6. **Memory** — unbounded structures, missing cleanup, listener leaks
7. **Overly broad ops** — reading whole files / loading all items when a portion suffices
