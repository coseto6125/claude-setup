# Audit exemptions

One line per exemption: `<skill> | <rule> | <reason>`. A finding that matches is counted, not
printed. Give the reason in full, because the next reader decides whether it still holds.

computer-use | rule 3 | Orca overwrites this from stablyai/orca on `orca skills update`, so an edit here cannot survive. It teaches judgement calls, not fixed-answer steps.
orca-cli | rule 3 | Same upstream overwrite as computer-use.
orchestration | rule 1 | Same upstream overwrite. The 813-char description is Orca's, not ours.
peer-agent | rule 3 | Teaches when to launch, poll and gate a peer agent. Every step ends in a judgement, so no script can hold the answer.
ui-ux-pro-max | rule 1 | The noun opening was measured, not assumed: the routing probe "build a landing page and choose its colours, fonts and layout" reaches it 3/3 on opus.
humanizer | rule 2 | Orca overwrites this from stablyai/orca on `orca skills update`, so an edit here cannot survive. The 35 tells are also a flat peer-set: the completion criterion is every pattern checked, so moving some behind a pointer makes the agent load only part of the set and miss the rest.
i-have-adhd | rule 3 | Ten always-on behaviour rules, each ending in a judgement about the current turn. No fixed-answer step for a script to hold.
