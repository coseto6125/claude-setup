---
name: gh-report
description: File bug reports, feature requests, or PRs against GitHub repositories we do not own. Use when the user asks to 回報上游, report upstream, 開 issue 給別人的 repo, asks "has anyone reported this?", or wants a PR on an external project.
---

# gh-report — file upstream reports that fit the target repo's rules

Many projects auto-close external Issues or unsolicited PRs, and route reports
through GitHub Discussions first. Discover the intake channel from the repo's
own files before you draft anything.

## Order of operations

1. **Dedupe first**, before you write a line of draft:
   - Search Issues with `gh search issues --repo OWNER/REPO "<keywords>" --limit 20`.
     Run 2 to 4 keyword variants: symptom words, component names, exact error strings.
   - Search Discussions separately:
     `gh api "repos/OWNER/REPO/discussions?per_page=100" --jq '.[] | "\(.number) [\(.category.name)] \(.title)"'`
   - For a behavior report, fetch the relevant source file from the default branch
     (`gh api repos/OWNER/REPO/contents/<path> --jq .content | base64 -d`) and confirm
     the defect still exists there. If main already fixes it, tell the user and stop;
     the remaining action is a release question, not a report.
   - Report the evidence to the user in this format:

     | Searched | Query | Result |
     |---|---|---|
     | Issues | `<query>` | N hits / none |
     | Discussions | category scan | N hits / none |
     | main branch | `<file>` | defect present / already fixed |
2. **Read the intake rules** on the default branch, and name each artifact
   present or absent before you go on:
   - `CONTRIBUTING.md` (root or `.github/`) covers who may open Issues and PRs,
     the mandated flow, and the PR policy.
   - `.github/ISSUE_TEMPLATE/config.yml` holds `blank_issues_enabled` and
     `contact_links`. The contact links name the real intake channel.
   - `.github/ISSUE_TEMPLATE/*.yml` forms define the sections, labels, and
     required fields a report must carry.
   - In a monorepo the templates sit at the repo root even when the affected
     package is a subdirectory. Report against the repo, and name the package inside.
3. **Route by what you found**, and record the chosen channel:
   - External issues auto-closed, or `blank_issues_enabled: false`, or template
     text like "maintainer work queue" → post to the Discussions category from contact_links.
   - PRs restricted to maintainers or vouched contributors → present findings only,
     and let the user decide about any further step.
   - Otherwise → follow the matching template.
4. **Draft to the template's field names.** Write one section per form field,
   with the same heading text, and fill every required field. Include version
   (`--version` output), OS, minimal repro steps, and expected versus actual
   behavior. Write in English, unless the repo's own artifacts use another
   language. Redact tokens and secrets.
5. **Confirm before posting.** Show the user the chosen channel, the full draft,
   and the dedupe table from step 1. Post only on explicit approval. Then report
   the resulting URL back, and link our mpm follow-ups both ways when related work exists.

## Worked example (2026-08-24, PrimeIntellect-ai/prime-agent)

`blank_issues_enabled: false`. Both templates said "maintainer work queue".
CONTRIBUTING said external issues get auto-closed and unsolicited PRs receive
no review. Everything therefore went to Discussions. The feature form wanted
Problem / Proposed solution / Alternatives considered. The bug form wanted
Description / Steps to reproduce / Expected behavior / Actual behavior /
Prime Agent version / Operating system. Drafts were reshaped to those exact
fields and posted as Discussions.
