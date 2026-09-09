---
name: authority-check
description: Consult BEFORE writing code that carries authority — a new route or endpoint, an auth or permission check, a tenant or org lookup, a webhook handler, a model-callable tool, a fetch of a URL someone else supplied, a file upload, a query built from input, or anything that mints, reads, or grants a session or a role. Turns one design question into one line of code, so the guard ships with the feature instead of arriving as an audit finding months later. Reach here while ADDING; `simplify` reviews the diff afterwards.
---

# Authority check

Two questions, asked once, before the code exists.

1. **Who can reach this?** Name the least-privileged caller who can. Not the caller you have in mind — the least one the code permits. "Anyone with the URL" is an answer. So is "any member of any tenant".
2. **What do they get by reaching it?** Data, an action, a spend, a fact about who exists. "Nothing" is an answer, and it ends the check.

If question 2 has an answer and question 1 says "someone who should not", the fix belongs in this commit. Not a TODO, not a follow-up: **a guard costs one line now and a chain of four findings later.**

## What to decide, by what you are writing

| Writing… | The one decision, now | Where the answer lives |
|---|---|---|
| A route | which decorator or middleware guards it | on the handler |
| A tenant-scoped query | the tenant goes in the `WHERE`, from the session | in the SQL |
| A privilege grant | which operator path triggers it — never a login, signup, or callback | at the call site |
| A refusal on an untrusted path | every reason returns the same status and body | one shared constant |
| A signed blob | the subject it is issued to, re-checked at redemption | in the payload |
| A webhook handler | verify the signature over the raw body, before decoding | first lines of the handler |
| A model-callable tool | tenant, account and permission come from the session, never from the schema | the tool's signature |
| A fetch of a supplied URL | resolve, then refuse private addresses; re-check each redirect | in the fetch helper |
| An upload or archive | the size, count and path bounds | at the entry point |
| A query from input | the driver's placeholder, not a formatted string | in the call |
| A dev-only convenience | do not write it as a route; write it as a CLI command | outside the app |

## Three rules that make it survive

- **Default closed.** A new parameter that widens access defaults to the safe value, so the caller that forgets it lands on the safe side. `email_verified: bool = False`, not `True`.
- **Delete rather than guard.** A convenience route behind `if IS_DEV` is one edit, one inverted boolean, or one misread env value away from being a production route. If it only helps development, it belongs in a CLI command or a test fixture.
- **Put the answer in the code.** A decision recorded in a PR description is gone in a month. A decision recorded as a check, a default, or a two-line comment naming the caller it excludes is still there when someone else edits the function.

## When the answer is not obvious

Open the surface's file under `~/.claude/skills/simplify/security/` — that directory carries the depth, the detection commands, and the look-alikes that are safe to leave alone. `SURFACES.md` routes to the right one.

Structural questions go to `ecp`, not to reading files: `ecp routes` for what is already exposed, `ecp impact --target <guard> --direction up` for who wears a guard today, `ecp tool-map --category http` for where the code already talks outward.

## What this is not

Not a review. It asks two questions about code you are about to write, and it is done. Reviewing a finished diff — every rung, every look-alike, a confidence score — is `simplify`'s job, and doing it here costs more than it catches.
