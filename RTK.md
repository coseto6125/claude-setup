# RTK - Rust Token Killer

A PreToolUse hook rewrites bash commands to `rtk <cmd>`, which compacts output.

- When rtk refuses a command (compound `find` predicates, `-exec`, anything it does not model), run the native command or `rtk bypass <cmd>`.
- When rtk output ends in an `rtk recall <hash>` hint, run that command with `--grep <regex>` before you re-run through `rtk bypass`.
- In a pipeline the hook attaches rtk to the consuming stage. Write `rtk` yourself on the producing stage when that is the stage worth compacting.
- Run `rtk gain`, `rtk gain --history` or `rtk discover` only when the user asks about token savings.
