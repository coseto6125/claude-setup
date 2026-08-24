# Review Checklist

The shared rungs for [`simplify`](SKILL.md) and any skill that points here. A section is done when **every** rung under it has ended as either a finding or an explicit "clear" — a partial sweep is not a review.

## Confidence

Every finding carries a score 0–100 against these anchors:

- **0** — false positive, pre-existing, or something the linter catches (typo, missing import, type error, formatting)
- **25** — possibly real, unverifiable
- **50** — real but trivial, with no project rule behind it
- **75** — very likely real and reachable in production, or an explicit CLAUDE.md violation
- **100** — certain bug, data corruption, or hard crash

Score 0 for anything in these classes: a line outside the diff · anything lint or typecheck catches · a nitpick a senior engineer would let pass · a generic test-coverage / security / docs ask with no rule behind it · code already carrying `# noqa` or `# type: ignore` · a deliberate behaviour change that is the point of the change.

The gate sits where the reader decides, so each skill states its own: [`simplify`](SKILL.md) fixes at 70, because a local fix is cheap to undo. `pr-review-multiagent` posts at 75, because a PR comment is public.

## Spec (intent)

Applies only when a spec source resolved; with none, record "no spec available" and move on. This axis reports on its own and is never merged into the others: code can follow every convention, pass every correctness rung, and still implement the wrong thing, so a clean sweep elsewhere must not read as spec conformance.

1. **Missing or partial requirements** — something the spec asked for that the diff doesn't deliver; quote the spec line
2. **Scope creep** — behaviour in the diff nobody asked for; quote the hunk and name the spec section it fails to trace to
3. **Implemented but wrong** — a requirement the diff appears to cover, where the implementation contradicts what the spec described

## Correctness (bugs)

1. **Logic errors** — inverted conditions, off-by-one, wrong operator, dead branches that should be live
2. **Removed invariants** — for every line the diff DELETES or replaces, name the guard, validation, error path, or test case it enforced, then find where the new code re-establishes it; unfound is a finding
3. **Boundary/empty cases** — empty input, zero/one element, max sizes, saturating vs wrapping arithmetic
4. **Error-handling gaps** — swallowed errors, unwrap/expect on fallible paths reachable in production, partial-failure states left inconsistent
5. **Null/None/undefined flows** — optional values dereferenced on paths where absence is possible
6. **Language pitfalls** — the classic footguns of the diff's language: Python mutable default args and late-binding closures, JS falsy-zero and `==` coercion, Go nil-map write and range-var capture, float equality, timezone/DST drift
7. **Concurrency** — racy check-then-act, shared state without synchronization, lock ordering, await points invalidating earlier reads
8. **Resource lifecycle** — leaks (files, sockets, listeners), double-free/double-close, missing cleanup on early return
9. **Wrapper routing** — a new or changed cache, proxy, decorator, or adapter must reach the wrapped instance directly, not back through a registry, session, or global that re-enters it; check it forwards every method its callers use
10. **Contract breakage** — callers relying on the OLD behavior of a changed function; `ecp impact --target X --direction upstream` enumerates them, verify each one survives the change
11. **Security** — injection (SQL/shell/path), unvalidated external input crossing a trust boundary, secrets in logs

## Reuse

1. **Existing utilities that replace new code** — graph first (`ecp find "upsert bot" --repo .`, `ecp inspect --name BotInfo --repo .`) finds matches grep misses; reach for grep once the graph comes back empty
2. **New function duplicating existing functionality** — name the existing one at file:line
3. **Inline logic an existing utility covers** — hand-rolled string manipulation, manual path handling, custom env checks, ad-hoc type guards

## Quality

1. **Altitude** — a special case layered on shared infrastructure means the fix sits too shallow; name the underlying mechanism to generalize instead. A special case that also breaks a stated CLAUDE.md rule (Code Style's restructuring rule, for instance) files once, under Conventions — not here too.
2. **Redundant state** — duplicates existing state, cacheable-derivable values, observers that could be direct calls
3. **Parameter sprawl** — new params instead of restructuring existing ones
4. **Copy-paste with variation** — near-duplicate blocks needing a shared abstraction (`ecp find` confirms whether one is already canonical)
5. **Leaky abstractions** — exposing internals or breaking abstraction boundaries (`ecp inspect` shows the boundary)
6. **Stringly-typed code** — raw strings where constants / enums / branded types exist
7. **Unnecessary JSX nesting** — wrapper elements adding no layout value
8. **Nested conditionals 3+ deep** — flatten with early returns, guard clauses, lookup tables
9. **Nested ternaries** — replace with `match`/switch or if-else chains
10. **WHAT-comments** — delete (identifiers say it); keep only non-obvious WHY

**Readability guardrail** — a fix must make the code *easier to read*, not merely shorter. Reject clarity-for-line-count trades: dense one-liners, over-clever collapses, merging distinct concerns, dropping an abstraction that earned its place.

## Conventions (project rules)

Read every CLAUDE.md that governs a changed file: the user-level `~/.claude/CLAUDE.md`, the repo root, and any CLAUDE.md or CLAUDE.local.md in a directory above a changed file. A directory's CLAUDE.md binds the files at or below it. With none above a changed file, record "no project rules apply".

1. **Stated rule broken** — quote the rule and the line that breaks it, and name the CLAUDE.md path so the report cites both
2. **Skill-owned rule broken** — a rule a language or stack skill states (`python-perf` for Python); quote it the same way

A convention finding carries a rule quote and a line quote. Anything short of that pair is a style preference, so leave it out.

## Efficiency

1. **Unnecessary work** — redundant computation, repeated reads, duplicate API calls, N+1
2. **Missed concurrency** — independent operations run sequentially
3. **Hot-path bloat** — new blocking work in startup / per-request / per-render paths; `ecp impact --target X --direction upstream --repo .` shows whether it sits in one
4. **Recurring no-op updates** — unconditional store updates in polling loops; verify wrappers honour same-reference returns
5. **TOCTOU existence checks** — operate directly and handle the error instead of pre-checking
6. **Memory** — unbounded structures, missing cleanup, listener leaks
7. **Captured-scope retention** — a long-lived object built from a closure holds its whole enclosing scope alive; prefer a class that copies the fields it needs
8. **Overly broad ops** — reading whole files / loading all items when a portion suffices
