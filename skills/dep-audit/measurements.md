# dep-audit measurements

## 2026-10-27, manifest-edit bumps in scope; bot PRs in the inventory

Text-decision probes, tools off, `preloaded.sh`, CLI 2.1.311, `claude-opus-5-5`, n=5 per arm. Archive: `~/.claude/prompt-runs/2026-10-27-ab-retro-r1`. Origin: a session filed tantivy (git pin → crates.io 0.27) and tree-sitter-dart 0.3 as follow-ups "needs its own PR"; the user rejected both, and had to ask for the open dependabot PRs.

| probe | old | new |
|---|---|---|
| step 1 inventory lists open bot PRs | 0/5 | 5/5 |
| tantivy bumped with no "stop if it grows past minimal" escape | 0/5 | 5/5 |
| dart 0.3 port done in this run | 5/5 | 5/5 (saturated, not measured) |
| break: user said "security only", clap 4→5 waits | 5/5 | 5/5 |
| break: dart 0.3 blocked upstream, deferred | 5/5 | 5/5 |

- Load-bearing: the step 1 bot-PR sentence and "The size of the change is not a reason." in step 4.
- The "dependency commits merged since the last release tag" branch was not scored.
