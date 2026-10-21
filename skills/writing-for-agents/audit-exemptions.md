# Audit exemptions

One line per exemption: `<skill> | <rule> | <reason>`, where `<rule>` is `rule N` or `ref <name>` for an `audit.py refs` finding. A finding that matches is counted, not
printed. Give the reason in full, because the next reader decides whether it still holds.

computer-use | rule 3 | Orca overwrites this from stablyai/orca on `orca skills update`, so an edit here cannot survive. It teaches judgement calls, not fixed-answer steps.
orca-cli | rule 3 | Same upstream overwrite as computer-use.
orchestration | rule 1 | Same upstream overwrite. The 813-char description is Orca's, not ours.
peer-agent | rule 3 | Teaches when to launch, poll and gate a peer agent. Every step ends in a judgement, so no script can hold the answer.
ui-ux-pro-max | rule 1 | The noun opening was measured, not assumed: the routing probe "build a landing page and choose its colours, fonts and layout" reaches it 3/3 on opus.
eli5 | rule 3 | Merged with i-have-adhd on 2026-09-08. Part 1 calibrates an explanation to the audience and Part 2 holds ten always-on behaviour rules, each ending in a judgement about the current turn. No fixed-answer step for a script to hold.
eli5 | rule 2 | 242 lines because the merge kept two measured bodies whole. Leave-one-out on claude-haiku-4-5 (n=5, 2026-08-21; not re-run on a current model, so unverified per writing-for-agents Pruning) showed the four audience tables are load-bearing: without them the skill and the bare control both fell back to book-index analogies 0/5. Part 1 is a real disclosure candidate, since a bare `/eli5` never reaches it — but moving the tables behind a pointer is the same shape of change as deleting them, so validate it with `validate-prompt-rules` before splitting.
seo-hreflang | ref en-uk | `en-uk` is the skill's example of an invalid locale code, not a skill name.
seo-cluster | ref blog-write | The step runs only under "If claude-blog IS installed"; the skill tests for that plugin first and has a branch for its absence.
agent-routing | ref claude-api | `claude-api` is a skill bundled with Claude Code, absent from the bundled-skills cache that `refs` reads.
external-writing | ref <project skill> | A project-level skill; the sentence names it only for the project where it exists.
