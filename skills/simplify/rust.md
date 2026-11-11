# Rust rungs

Rungs for a diff that changes a `.rs` file or a `Cargo.toml`. [`CHECKLIST.md`](CHECKLIST.md) names the owner of each section. Adapted from BeautifulRust `rust-review` (MIT, Copyright (c) 2026 Morgan Linton; see `~/.claude/skills/rust-best-practices/LICENSE`).

The rules behind each rung, and their reasoning, live in `~/.claude/skills/rust-best-practices/` (`SKILL.md`, `references/`). Cite the rule in the finding's why: an API Guidelines code such as `C-GETTER`, a Microsoft guideline code such as `M-PANIC-ON-BUG`, an Effective Rust item number, or a clippy lint name.

**Before the first rung, record two facts in the ledger:**

1. **Library or application.** A crate is a library when another crate uses its `pub` items, or when its `Cargo.toml` publishes it. Name the evidence: the `lib.rs`, the dependent crate, or the `publish` key.
2. **Edition and `rust-version`**, from `Cargo.toml`. A fix never needs a feature above them.

## Rust correctness

1. **Unsoundness** — an `unsafe` block without a `// SAFETY:` comment; `transmute` to cast an enum or extend a lifetime; `unsafe impl Send` or `Sync` that silences the compiler; a safe function that reaches undefined behaviour through a sequence of safe calls
2. **Reachable panic** — slice indexing or integer overflow on a value that outside input reaches. Correctness 4 owns `unwrap` and `expect`; Correctness 6 owns `as` casts
3. **Trait contract** — a hand-written `Ord` beside a derived `PartialEq`, or a `Hash` that disagrees with `Eq`. `BTreeMap`, `HashMap`, `sort` and `dedup` then misbehave silently
4. **Lock hazard** — a `MutexGuard` held across `.await` or returned to a caller; a user closure called under a lock; a poisoned lock recovered with `into_inner`; a lock guard moved out of a `match` scrutinee while an arm acts on the checked state (the `rust-perf` skill has the probe)
5. **Lost `Send`** — a public type or a returned future that a changed line makes `!Send`, such as an `Rc` or a `RefCell` borrow held across `.await`
6. **Destructor** — a `Drop` impl that panics, blocks, or can fail

## Rust API and idiom

On application code, walk rungs 1, 6 and 7, and record the rest `n/a: application code`.

1. **Error types** — a library's public error is `()`, `String`, `Box<dyn Error>` or `anyhow::Error`; an error enum lacks `Display` and `std::error::Error`; a `map_err(|_| ..)` drops the cause; a wrapper error has no `source()`
2. **Parameters** — `&String`, `&Vec<T>` or `&Box<T>` where `&str`, `&[T]` or `&T` fits; a `bool` parameter in a public signature; ownership taken and then cloned, or a borrow cloned internally to get ownership
3. **Visibility and evolution** — a public field that should be private; `Rc`, `RefCell` or `Arc` in a public signature; a third-party type in the public API; a public enum or struct that crosses a crate boundary without `#[non_exhaustive]`
4. **Missing std traits** — `Debug` on a public type, `Display` on an error, `Default` beside a zero-argument `new()`, `FromStr` in place of an ad-hoc `from_str`
5. **Naming** — a `get_` prefix on a getter; an `as_`, `to_` or `into_` prefix that does not match the cost and ownership of the conversion
6. **Borrow-checker clone** — a `.clone()` that a changed line adds only to end a borrow, so later changes to the original are lost
7. **Idiom** — check-then-unwrap (`if x.is_some() { x.unwrap() }`); `HashMap` iteration order that reaches output or a test assertion; `#![deny(warnings)]` in source; `#[allow]` without a reason
8. **Docs** — a public item of a library without docs; a missing `# Errors`, `# Panics` or `# Safety` section; a doc example that calls `unwrap()` in place of `?`

When the crate has no `[lints]` table, name in the summary the lints from `~/.claude/skills/rust-best-practices/lints/lints.toml` that would have caught a finding of this review. Propose them, and leave the project's lint config unchanged.
