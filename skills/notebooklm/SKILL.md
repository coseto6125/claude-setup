---
name: notebooklm
description: "Offload a large external read to Gemini Notebook (NotebookLM) through the `nlm` CLI, so only its answers enter this context. Use before you read external material too big to hold in context: a PDF or report over about 30 pages, a long transcript or YouTube video, or more than five web pages for one question."
---

# NotebookLM offload

Gemini Notebook reads the sources on Google's side. You send questions and read only its answers. Each answer is a lead, not a fact: verify every fact you act on against its source.

## Before the first call

Run `nlm login --check`. When it fails, ask the user to run `! nlm login`, which opens a browser. You cannot log in for them. When a query reports a quota error, run `nlm usage`; an auth error there means `nlm login` again, not an empty quota.

## Steps

1. Create one notebook per investigation: `nlm notebook create "<topic> <YYYY-MM-DD>" --json`. Keep its id.
2. Add every source, and wait for processing:
   - `nlm source add <id> --url "<url>" --wait` for a web page or a YouTube video
   - `nlm source add <id> --file <path> --wait` for a local PDF, docx, md, txt or audio file
3. Ask one question per call: `nlm notebook query <id> "<question>" --json`. Ask for the exact figure, version, date or quote the task needs, never for a general summary. Follow up in the same thread with `--conversation-id <cid>`.
4. Verify each fact you will act on. Export the cited source with `nlm source content <source-id> --output <scratchpad>/<name>.txt`, then grep the file for the passage. Never read the whole export into context.
5. In your report, mark which facts you verified and which came from the notebook alone.
6. Delete the notebook when the investigation ends: `nlm notebook delete <id> --confirm`.

## Use something else

| Material | Use |
|---|---|
| Code in a repo | `ecp`, then grep |
| Library, framework or API docs | `ctx7` |
| A source under about 30 pages | read it directly; the round trip costs more than it saves |

Never upload client files, credentials, or anything from a private repo: `nlm` sends the source to Google. Ask the user first.

Full CLI reference: `nlm --ai`.
