# Audit exemptions

One line per exemption: `<skill> | <rule> | <reason>`. A finding that matches is counted, not
printed. Give the reason in full, because the next reader decides whether it still holds.

computer-use | rule 3 | Orca overwrites this from stablyai/orca on `orca skills update`, so an edit here cannot survive. It teaches judgement calls, not fixed-answer steps.
orca-cli | rule 3 | Same upstream overwrite as computer-use.
orchestration | rule 1 | Same upstream overwrite. The 813-char description is Orca's, not ours.
peer-agent | rule 3 | Teaches when to launch, poll and gate a peer agent. Every step ends in a judgement, so no script can hold the answer.
ui-ux-pro-max | rule 1 | The noun opening was measured, not assumed: the routing probe "build a landing page and choose its colours, fonts and layout" reaches it 3/3 on opus.
humanizer | rule 2 | Orca overwrites this from stablyai/orca on `orca skills update`, so an edit here cannot survive. The 35 tells are also a flat peer-set: the completion criterion is every pattern checked, so moving some behind a pointer makes the agent load only part of the set and miss the rest.
eli5 | rule 3 | Merged with i-have-adhd on 2026-09-08. Part 1 calibrates an explanation to the audience and Part 2 holds ten always-on behaviour rules, each ending in a judgement about the current turn. No fixed-answer step for a script to hold.
eli5 | rule 2 | 242 lines because the merge kept two measured bodies whole. Leave-one-out on haiku (n=5, 2026-08-21) showed the four audience tables are load-bearing: without them the skill and the bare control both fell back to book-index analogies 0/5. Part 1 is a real disclosure candidate, since a bare `/eli5` never reaches it — but moving the tables behind a pointer is the same shape of change as deleting them, so validate it with `validate-prompt-rules` before splitting.
