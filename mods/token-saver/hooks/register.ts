import { atom, read, update } from 'claude-code'
import type { Register, StateDollar } from 'claude-code'

// Skills unused in a week of sessions (2026-09-25 to 2026-10-02), plus docx / pdf / xlsx (two uses or fewer
// ever, ~1.9k chars of listing): the listing keeps the name and a short hint, and the full SKILL.md still
// loads when the Skill tool calls the name. The docx / pdf / xlsx hints routed like the originals on
// claude-opus-5-5, first tool call, n=5 per scenario (2026-10-02).
const LAZY_SKILLS: Record<string, string> = {
  'anthropic-skills:built-in-browser': 'the Claude desktop in-app browser pane (mcp__Claude_Browser__* tools).',
  'anthropic-skills:chrome-browser': 'Claude in Chrome, the browser extension (mcp__claude-in-chrome__* tools).',
  'anthropic-skills:computer-use': 'control desktop apps through the Claude desktop app (mcp__computer-use__* tools).',
  'anthropic-skills:deep-research': 'multi-source research synthesized into a narrative report.',
  'anthropic-skills:docs': 'Claude Docs, editable shared documents (mcp__claude_ai_Claude_Docs__* tools).',
  'anthropic-skills:docx':
    'Word .docx / .dotx files: create, read or edit. A document request that names no file format goes to Claude Docs instead.',
  'anthropic-skills:google-workspace': 'create or change a Google Docs, Sheets or Slides file.',
  'anthropic-skills:pdf': 'PDF files: read or extract, merge, split, fill forms, create, OCR.',
  'anthropic-skills:xlsx':
    'spreadsheet files (.xlsx, .xlsm, .csv, .tsv) when the deliverable is a spreadsheet file. A Google Sheets file goes to google-workspace.',
  'anthropic-skills:import-memory': "import another AI assistant's memory export.",
  'anthropic-skills:morning': 'the morning brief, only when the user asks for it by name.',
  'anthropic-skills:pptx': 'PowerPoint .pptx / .potx files.',
  'anthropic-skills:skill-creator': 'create, edit or evaluate a skill.',
}

const DOCS_HEADER = '## claude.ai Claude Docs\n'
// What follows a server's section in an MCP instructions delta: the next server, the disconnect notice, or
// the closing ambient-context line.
const SECTION_END = /\n+(?=## |The following MCP servers have disconnected|This is ambient context)/
const DOCS_DENY =
  'The Claude Docs MCP server instructions were deferred until its first call. Read them, then send the call again.'

const docsInstructions = atom({ plugin: 'token-saver', key: 'docsInstructions' } as const, '')
// The loops (`main`, or a subagent's id) that have read docsInstructions since their last compaction.
const docsDelivered = atom({ plugin: 'token-saver', key: 'docsDelivered' } as const, {})

// The remaining-budget reminder repeats a figure the system prompt already states; it shows again once the
// budget falls below this share of the largest figure seen in the session.
const BUDGET_SHOW_BELOW = 0.2
const tokenBudgetMax = atom({ plugin: 'token-saver', key: 'tokenBudgetMax' } as const, 0)

// The per-request "output style is active" reminder repeats the style the system prompt already holds.
// Switched off 2026-10-02; flip to false if lang-drift-scan.py shows progress notes before compaction drifting
// above 12% (5.8% on 2026-09-26..10-02, re-counted 2026-10-03 with the fixed scanner).
const DROP_STYLE_REMINDER = true

// After a text block to the user drifts into English, the style reminder comes back with this note until a
// Chinese block clears it: drift is sticky, and a reminder on a schedule did not stop it.
const DRIFT_NOTE =
  'Your last text block to the user was in English. Write the next one, and every one after it, in the language the `# Language` section names.'
const langDrift = atom({ plugin: 'token-saver', key: 'langDrift' } as const, false)

const CJK = /[\u3400-\u9fff\u3000-\u303f\uff00-\uffef]/g
const LATIN = /[A-Za-z]/g
const CODE = /```[\s\S]*?```|`[^`]*`/g
// lang-drift-scan.py counts a block as English under 5% CJK; this flags under 15%, which also catches an
// English note quoting a Chinese term (2026-09-26..10-02: 5 of the 7 main-loop blocks in that band were
// English). A Chinese note is often short, so 10 CJK characters decide it; undefined for a block too short.
const isEnglish = (text: string) => {
  const prose = text.replace(CODE, '')
  const cjk = prose.match(CJK)?.length ?? 0
  const latin = prose.match(LATIN)?.length ?? 0
  if (latin >= 60 && cjk < latin * 0.15) return true
  return cjk >= 10 ? false : undefined
}

const loopOf = (e: { agentId?: string }) => e.agentId ?? 'main'
// update() retries a write that another hook raced and throws after a bound, and the main loop and parallel
// subagents fire these hooks at once: write only when the value changes.
const clearLoop = async ($: StateDollar, loop: string) => {
  if ((await read($, docsDelivered))[loop]) await update($, docsDelivered, loops => withLoop(loops, loop, false))
}
const withLoop = (loops: Record<string, true>, loop: string, on: boolean) => {
  const { [loop]: _, ...rest } = loops
  return on ? { ...rest, [loop]: true as const } : rest
}

const shortenSkillListing = (text: string) =>
  text
    .split('\n')
    .map(line => {
      const name = line.match(/^- ([^\s:]+(?::[^\s:]+)*): /)?.[1]
      return name && Object.hasOwn(LAZY_SKILLS, name) ? `- ${name}: ${LAZY_SKILLS[name]}` : line
    })
    .join('\n')

// Cuts the Claude Docs section out of an MCP instructions delta. `rest` is null when nothing but the
// delta's own header and closing line remains.
const splitDocsSection = (text: string) => {
  const start = text.indexOf(DOCS_HEADER)
  if (start < 0) return undefined
  const tail = text.slice(start)
  const end = tail.search(SECTION_END)
  const docs = (end < 0 ? tail : tail.slice(0, end)).trimEnd()
  const rest = (text.slice(0, start) + (end < 0 ? '' : tail.slice(end).replace(/^\n+/, ''))).trimEnd()
  const hasNews = /\n## |The following MCP servers have disconnected/.test(rest)
  return { docs, rest: hasNews ? rest : null }
}

// Write and Edit inputs by tool_use_id, so a result's path is shortened only when it is the path the call
// named; an expanded `~` or relative path stays whole.
const filePaths = new Map<string, string>()

const shortenFileResult = (text: string, path: string) => {
  const short = `…/${path.slice(path.lastIndexOf('/') + 1)}`
  for (const [lead, tail] of [
    ['File created successfully at: ', ''],
    ['The file ', ' has been updated'],
  ]) {
    const head = lead + path + tail
    if (text.startsWith(head)) return lead + short + tail + text.slice(head.length)
  }
  return text
}

const dedupeJson = (text: string, edit: (o: any) => boolean) => {
  let o
  try {
    o = JSON.parse(text)
  } catch {
    return text
  }
  return o && typeof o === 'object' && edit(o) ? JSON.stringify(o) : text
}

const dedupeResult = (tool: string, text: string, path: string | undefined) => {
  switch (tool) {
    case 'Write':
    case 'Edit':
      return path ? shortenFileResult(text, path) : text
    case 'TaskStop':
      return dedupeJson(text, o => {
        if (o.message !== `Successfully stopped task: ${o.task_id} (${o.command})`) return false
        o.message = `Successfully stopped task: ${o.task_id}`
        return true
      })
    case 'SendMessage':
      return dedupeJson(text, o => {
        if (!o.pin || o.pin.name !== o.pin.id) return false
        delete o.pin.name
        return true
      })
    default:
      return text
  }
}

export const register: Register = on => {
  on('prompt.attachment', { type: 'skill_listing' }, async ($, e, next) => {
    const r = await next(e)
    return r.text ? { ...r, text: shortenSkillListing(r.text) } : r
  })

  on('prompt.attachment', { type: 'total_tokens_reminder' }, async ($, e, next) => {
    const r = await next(e)
    const left = Number(r.text?.match(/<total_tokens>(\d+) tokens left<\/total_tokens>/)?.[1])
    if (!Number.isFinite(left)) return r
    const seen = await read($, tokenBudgetMax)
    const max = Math.max(seen, left)
    // The budget only falls, so this writes once per session; a lost race leaves `max` right for this request.
    if (left > seen) await update($, tokenBudgetMax, m => Math.max(m, left)).catch(() => {})
    return left > 0 && left >= max * BUDGET_SHOW_BELOW ? { ...r, text: null } : r
  })

  on('prompt.attachment', { type: 'output_style' }, async ($, e, next) => {
    const r = await next(e)
    if (r.text && (await read($, langDrift))) return { ...r, text: `${r.text}\n${DRIFT_NOTE}` }
    return DROP_STYLE_REMINDER ? { ...r, text: null } : r
  })

  // Only the main loop talks to the user; a subagent's report is English by design.
  on('session.append', { door: 'response' }, async ($, e, next) => {
    if (e.agentId === undefined) {
      for (const block of e.message.content) {
        if (block.type !== 'text') continue
        const english = isEnglish(block.text as string)
        // A lost write race is harmless: the next text block sets the flag again.
        if (english !== undefined && english !== (await read($, langDrift)))
          await update($, langDrift, () => english).catch(() => {})
      }
    }
    return next(e)
  })

  on('prompt.attachment', { type: 'mcp_instructions_delta' }, async ($, e, next) => {
    const r = await next(e)
    const split = r.text ? splitDocsSection(r.text) : undefined
    if (!split) return r
    if ((await read($, docsInstructions)) !== split.docs) await update($, docsInstructions, () => split.docs)
    // A delta that brings the section again (connect, reconnect, resume) means this loop has not read it.
    await clearLoop($, loopOf(e))
    return { ...r, text: split.rest }
  })

  // The first Claude Docs call of each loop is refused with the instructions, so the model reads them before
  // any Docs call acts, however the tool was loaded.
  on('tool.call', { tool: /^mcp__claude_ai_Claude_Docs__/ }, async ($, e, next) => {
    const docs = await read($, docsInstructions)
    const loop = loopOf(e)
    if (!docs || (await read($, docsDelivered))[loop]) return next(e)
    await update($, docsDelivered, loops => withLoop(loops, loop, true))
    return { deny: `${DOCS_DENY}\n\n${docs}` }
  })

  // Compaction may summarise the instructions away; a precomputed summary counts too, as one extra copy
  // costs less than a Docs call without them.
  on('session.compact', async ($, e, next) => {
    const r = await next(e)
    if ('messages' in r) await clearLoop($, loopOf(e))
    return r
  })

  on('session.end', async ($, e, next) => {
    if (Object.keys(await read($, docsDelivered)).length) await update($, docsDelivered, () => ({}))
    return next(e)
  })

  on('tool.call', { tool: ['Write', 'Edit'] }, ($, e, next) => {
    filePaths.set(e.tool_use_id, e.file_path)
    return next(e)
  })

  on('session.append', { door: 'tool-result' }, ($, e, next) => {
    if (e.origin.kind !== 'tool') return next(e)
    const tool = e.origin.tool
    const content = e.message.content.map(block => {
      if (block.type !== 'tool_result') return block
      const id = block.tool_use_id as string
      const path = filePaths.get(id)
      filePaths.delete(id)
      if (block.is_error) return block
      const c = block.content
      if (typeof c === 'string') return { ...block, content: dedupeResult(tool, c, path) }
      if (!Array.isArray(c)) return block
      return { ...block, content: c.map(b => (b.type === 'text' ? { ...b, text: dedupeResult(tool, b.text, path) } : b)) }
    })
    return next({ ...e, message: { ...e.message, content } })
  })
}
