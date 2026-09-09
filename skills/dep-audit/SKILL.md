---
name: dep-audit
disable-model-invocation: true
description: Upgrade every dependency in a repo to latest across its package ecosystems, audit API/ABI breakage against the repo's real usage, pin behavior flips behind tests, and evaluate core-package alternatives. Runs only when you type "dep-audit".
---

# Dependency audit and upgrade

Refresh all dependencies in a repo with evidence. The scope of one run covers manifests, lockfiles, version comments beside pins, and the minimal adaptation code the upgrades demand. Everything else goes on a follow-up list.

Rules that bind the whole run:

- Create a branch or worktree before the first edit. Base it on main.
- Every claim you record cites a source URL, or carries the word UNVERIFIED.
- Before you act on a finding from a helper agent, run its check yourself and keep the raw output.

## 1. Inventory

List each ecosystem in the repo with its manifest path, lockfile path, and full map of currently locked versions. Parse lockfiles programmatically; never eyeball them.

Scan every lockfile against the advisory database in the same pass:

```
osv-scanner scan source --lockfile <path> [--lockfile <path> ...] --format json
```

One command covers every lockfile. The scan reads transitive packages, which the registry-version map alone leaves in the background.

| Ecosystem | Manifest | Lockfile | Latest version | Upgrade |
|---|---|---|---|---|
| Python (uv) | `pyproject.toml` | `uv.lock` | `pypi.org/pypi/<pkg>/json` | `uv lock --upgrade && uv sync` |
| Python (poetry) | `pyproject.toml` | `poetry.lock` | PyPI JSON API | `poetry update` |
| Node | `package.json` | `package-lock.json` | `registry.npmjs.org/<pkg>`, tag `latest` | `npm update`; majors need a manifest edit first |
| Rust | `Cargo.toml` | `Cargo.lock` | `crates.io/api/v1/crates/<name>`, field `max_stable_version` | `cargo update && cargo build` |
| Go | `go.mod` | `go.sum` | `proxy.golang.org/<module>/@latest` | `go get -u ./... && go mod tidy` |

Query registries concurrently. Record failures as unknown; an unknown never counts as up to date.

Done when: every ecosystem has both paths and a version map, every installed package has a registry answer or an unknown marker, and the advisory scan output is recorded package by package.

## 2. Classify

For each outdated package record: current version, target version, semver distance, direct or transitive.

A bump is **notable** when any holds: it updates a direct dependency; it is a major bump; the repo imports the package; **the step 1 scan reports an advisory against the locked version**. Only notable bumps earn changelog reading in step 3.

Transitive packages stay in scope. A lockfile-only package with an advisory is notable and gets the full audit. A lockfile-only package with no advisory skips step 3, and still moves under the ecosystem-wide upgrade in step 4.

Done when: every notable bump has a line in the audit ledger.

## 3. Audit notable bumps

Grep each package's import and call sites first; the usage surface decides relevance.

From release notes or changelogs, answer two questions per notable bump:

1. Which breaking changes touch this repo's usage surface? Cover API signatures and ABI details such as wheel tags for each interpreter flavor the project runs.
2. Which new features give a measurable speed, safety, or resource win?

Done when: every notable bump answers both questions with citations or UNVERIFIED markers.

## 4. Upgrade

Run the table's ecosystem-wide upgrade command inside the worktree first, so transitive packages move together with the direct ones. Drop to a per-package upgrade only for a package whose ecosystem-wide bump fails a gate, and write the reason that package stays behind. Then run the repo's gates through the project's environment: tests, lint, typecheck.

Triage each failure: regression or pre-existing. Prove pre-existing on the base commit before fixing.

Run the suite serially when fixtures share one database or schema. Parallel workers corrupt session-scoped setup and produce fake errors.

Done when: all gates pass on the upgraded tree, or each remaining failure has a root-cause note, and every package still behind its latest version carries a written reason.

## 5. Pin behavior flips

An upgrade can flip an observable default. Decide per flip: keep the old behavior or adopt the new one. Then write the test that fails under the rejected option, apply the smallest change that passes it, and rerun the test.

Record each decision next to the code as a comment naming the upstream change.

Done when: every detected flip has a decision note plus a passing test that fails under the rejected option.

## 6. Alternatives scan

Run only when the user asks about replacements. Cover core packages: server, driver, serializer, cache, logging.

Gather live data: downloads (`pypistats.org/api/packages/<pkg>/recent`), last release date, cadence. Label facts `[live]`, training recall `[memory]`. A challenger needs evidence of functional parity plus a meaningful speed, safety, or resource gain before you propose it.

Give a verdict per package:

- KEEP, with the reason and the datum behind it.
- EVALUATE, with the candidate, migration cost, and a revisit trigger such as a dormancy threshold.

Re-run every number you plan to publish yourself; a spot check beats a forwarded claim.

Done when: every core package carries KEEP or EVALUATE backed by at least one live datum.

## 7. Report

Re-run the step 1 advisory scan on the upgraded lockfiles. Report zero remaining advisories, or one line per remaining advisory naming the reason it stays.

Deliver four tables: upgrades applied, breaking-change findings, adopted wins, flagged risks with triggers. Split commits by unit: bumps in one, behavior pins in another. Leave the branch unpushed; hand the diff to your review gate.
