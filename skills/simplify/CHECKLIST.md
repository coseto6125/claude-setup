# Review Checklist

The shared rungs for [`simplify`](SKILL.md) and any skill that points here. A section is done when **every** rung under it has ended as either a finding or an explicit "clear" — a partial sweep is not a review.

## Confidence

Every finding carries a score 0–100 against these anchors:

- **0** — false positive, pre-existing, or something the linter catches (typo, missing import, type error, formatting)
- **25** — possibly real, unverifiable
- **50** — real but trivial, with no project rule behind it
- **75** — very likely real and reachable in production, or an explicit CLAUDE.md violation
- **100** — certain bug, data corruption, or hard crash

Score 0 for anything in these classes: a line outside the diff · anything lint or typecheck catches · a nitpick a senior engineer would let pass · a generic test-coverage / docs ask with no rule behind it · a security ask that names no unauthorised caller (the Security section sets that bar) · code already carrying `# noqa` or `# type: ignore` · a deliberate behaviour change that is the point of the change.

The gate sits where the reader decides, so each skill states its own: [`simplify`](SKILL.md) fixes at 70, because a local fix is cheap to undo. `pr-review-multiagent` posts at 75, because a PR comment is public.

**A finding that clears the gate carries its fix.** The fix is the concrete change: the edited line, the command to run, the block to delete. "It is small", "the code works today", and "the change is too big to apply here" are the reader's reasons to decline that fix. None of them lets the report name the problem and stop there. A finding that stays unapplied carries its fix as a proposal. A finding that never matched a rung is governed by the score-0 list above instead.

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
11. **Unexercised fallback** — a fast path with a fallback: `or_else`, a `None =>` arm, a cached probe. Run the same assertion on both branches. Force the fallback with the missing file or env var it keys on. A fallback that predates the diff still earns its judgement against the caller that reaches it now
12. **Mirror drift** — a sentinel, cache key, or validator that must resolve the same way as the reader it guards. Open both and compare the resolution order (`ecp find "<the other half>"` locates the other half). Each half reads as correct alone, so a mismatch fails silently
13. **Recalled contracts** — shell quoting, CLI flag semantics, or library behaviour written from recall. Run the real thing once (`bash -c`, `--help`, `ctx7`), then build the tokenizer or the flag table from that output
14. **Test that cannot go red** — a test shipped with a fix pins that fix only when it fails without it. Revert the fix in the working tree, run that test, and require the failure. Read the failure message too: it names the defect, or the test watches something else. Two shapes stay green either way. The setup fails for its own reason before the guarded line runs. Or the assertion watches an artifact the unfixed path never produces. A fix whose signature change stops the test compiling takes the same proof from the released binary instead

## Security (authority and trust)

Reads who may reach a code path, what they obtain by reaching it, and which input the path believes.

This section reads the diff, so it finds the hole the diff opens. A hole that already exists is caught by a standing test that pins the repo's anonymous route surface, not by a review. Dependency CVEs belong to the `dep-audit` skill, so they are out of scope here.

A finding names **the caller who should not reach it** and **the authority or data they obtain**. Without that pair it is a generic ask, and scores 0.

Walk a group only when the diff can touch it: a diff that adds no route skips *Who may act*, and a diff that reads no external input skips *What the path believes*.

These rungs are Layer 1: what to look for. When a rung fires, or when the diff touches a surface no rung covers, open [`security/SURFACES.md`](security/SURFACES.md) — it probes which surfaces this repo actually has, and points at one depth file per present surface for how to prove a finding and which look-alikes to leave alone. A surface the probe does not find is skipped, and the report says so.

### Who may act

1. **Route authority** — every added or changed route states its authentication and its authorization. Name the decorator, the middleware, or the inline check. A route with neither is anonymous, and that is a finding unless the diff says anonymous is the intent.
2. **Privilege grant** — code that raises a caller's role, tenant scope, or plan runs on an operator-driven path, never on a login, signup, or OAuth-callback path. An identifier the caller supplies never selects the grant.
3. **Tenant isolation** — a handler derives the tenant from the session, then checks that session's account against that tenant. A resource identifier from the path or the body is scoped to that tenant inside the query, not compared after the row comes back.
4. **Refusal uniformity** — on a path where the caller is not yet trusted, every refusal reason returns the same status and the same body. Refusals that differ confirm which tenants, accounts, and resources exist.

### What the path believes

5. **Trust-boundary claims** — a claim from an external provider (email, phone, role, entitlement) is used only where the provider also states it verified the claim. An unverified claim never links, merges, or elevates an existing record.
6. **Signed-blob replay** — a signed state, token, or nonce carries the account it was issued to, and the handler re-checks that account's rights when it redeems the blob. A valid signature proves the blob's origin, not the redeemer's standing.
7. **Inbound webhook authenticity** — the handler verifies the platform signature over the raw body before it decodes that body, compares in constant time, and drops a delivery id it already processed.
8. **Model-supplied tool arguments** — an argument the model produced carries data, never authority. Tenant scope, account identity, and permission reach the tool from the turn's session, and the tool reads them there.
9. **Injection** — SQL, shell, path, and template input crosses its boundary through the parameterized API, not through string building.
10. **Outbound fetch targets** — a server-side fetch of a caller-supplied URL resolves the host first, then refuses loopback, link-local, and private ranges. It re-checks on every redirect, because the first response picks the second target.

### What it spends and leaks

11. **Secret handling** — secrets stay out of logs, error bodies, URLs, and fixtures. A cookie or token that carries authority sets `Secure`, `HttpOnly`, and `SameSite`.
12. **Anonymous cost** — a route reachable without a session, that spends money or does work the caller sizes, states its per-caller ceiling.
13. **Convenience paths** — a route, flag, or env branch that exists to make development easier ships deleted, not runtime-guarded. A guard is one edit away from being a production route.

## Reuse

1. **Existing utilities that replace new code** — graph first (`ecp find "upsert bot" --repo .`, `ecp inspect --name BotInfo --repo .`) finds matches grep misses; reach for grep once the graph comes back empty
2. **New function duplicating existing functionality** — name the existing one at file:line
3. **Inline logic an existing utility covers** — hand-rolled string manipulation, manual path handling, custom env checks, ad-hoc type guards

## Quality

1. **Altitude** — a special case layered on shared infrastructure means the fix sits too shallow; name the underlying mechanism to generalize instead. A second site of the same pattern that the diff judges unaffected is a finding unless the report names the consumers of that site's value it checked; a symptom that looks fine at the site is not a check. A special case that also breaks a stated CLAUDE.md rule (Code Style's restructuring rule, for instance) files once, under Conventions — not here too.
2. **Redundant state** — duplicates existing state, cacheable-derivable values, observers that could be direct calls
3. **Parameter sprawl** — new params instead of restructuring existing ones
4. **Copy-paste with variation** — near-duplicate blocks needing a shared abstraction (`ecp find` confirms whether one is already canonical)
5. **Leaky abstractions** — exposing internals or breaking abstraction boundaries (`ecp inspect` shows the boundary)
6. **Stringly-typed code** — raw strings where constants / enums / branded types exist
7. **Unnecessary JSX nesting** — wrapper elements adding no layout value
8. **Nested conditionals 3+ deep** — flatten with early returns, guard clauses, lookup tables
9. **Nested ternaries** — replace with `match`/switch or if-else chains
10. **WHAT-comments** — delete (identifiers say it); keep only non-obvious WHY
11. **Unverified claims** — a comment that asserts a fact about the world, not intent: "output is unchanged", "these layouts share a path". It carries the command that proves it. Run that command, mark the sentence as an assumption, or delete it
12. **Ambient test state** — a new test reads env vars, cwd, process-global statics, or a shared test binary. Name what it reads, then pin it or remove it. A pass counts as evidence once its reason is established

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
