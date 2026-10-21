# Measurements behind agent-routing/SKILL.md

## 2026-10-21, from memory subagent-goes-idle-without-reporting

Re-measured 2026-10-21 over transcripts since 2026-10-05 (scan in session 292270f4, scratchpad `idle.do4c6k/`). Bucket A = CLI 2.1.295 to 2.1.303 (492 sessions, 662 completions). Bucket B = 2.1.304+ (64 sessions, 28 completions, under one day of data).

- Idle with no report: retired. 0 cases in 662 completions on 2.1.295+. The 2026-08-23 shape (four of five agents idle with only `{"type":"idle_notification"}`) is no longer seen. Ask-back with SendMessage stays the fallback if it returns.
- Truncation is channel-specific. The Agent `finished` notification never truncates (194 results over 3k chars in A, max 17,837, all whole). Only the teammate idle channel (`<teammate-message>` idle_notification) still cuts at about 3k with `[result truncated - ask the agent for the rest via SendMessage]` (19 of 320 in A).
- Report files from Agent-tool sub-agents are refused (seen 2026-10-21, session 207afb98). The harness blocked a general-purpose sub-agent's `REPORT.md` write with "Subagents should return findings as text, not write report files". Data files (.tsv, .py, .sh) still wrote.
- Waiting forever on its own background job: still real. 19 stalls in A (6 agent files, mostly session c7da8904); none in B, but B has only 17 background-command absorptions, too few to say. Mechanism: the completion notification is enqueued but absorbed only when the sub-agent's next turn starts for another reason. CLI 2.1.295+ also sends the parent `Agent "X" is waiting on its own background work` (A 5, B 3). The CLAUDE.md wait-loop rule's sub-agent foreground clause targets this. Re-check once B has a few hundred completions.
- Second lesson (2026-10-09): `lite-scan` on haiku marked items "clear" while its own notes said the query was "not run" (a rung that says "check whether X already exists"). `lite-scan` suits counting and inventory, not cross-referencing.

Lessons the memory stated, with their status on 2026-10-22:
- For teammates and named agents that report through idle notifications, keep "write the full report to `<scratchpad>/<name>.md`, end with the path plus a three-line summary" in the spawn prompt. [superseded 2026-10-22: agent-routing/SKILL.md asks for a report under 2,500 characters or numbered parts; that worked in session de4c5c82]
- For an Agent-tool sub-agent, ask for the report in its reply (it arrives whole) and ask for files only for data; a brief that asks for a report file costs a refused call and a retry. [shipped 2026-10-22: agent-routing/SKILL.md, A sub-agent's report]
- When the parent gets `Agent "X" is waiting on its own background work`, check `ps -eo etimes,args | grep '[c]laude -p'` and the run dir's newest write time, then SendMessage the agent that the job ended. [shipped 2026-10-22: agent-routing/SKILL.md, A sub-agent's report]
