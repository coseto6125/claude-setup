# RTK - Rust Token Killer

A PreToolUse hook rewrites bash commands to `rtk <cmd>`, which compacts output. It costs no tokens and needs no action from you.

- When rtk refuses a command (compound `find` predicates, `-exec`, anything it does not model), run the native command or `rtk proxy <cmd>` and move on.
- In a pipeline the hook attaches rtk to the consuming stage. Write `rtk` yourself on the producing stage when that is the stage worth compacting.
- Savings reports live in `rtk gain`, `rtk gain --history`, and `rtk discover`. Run one only when the user asks about token savings.
