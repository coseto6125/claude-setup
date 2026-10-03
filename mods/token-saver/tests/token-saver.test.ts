import { describe, expect, test } from 'claude-code/testing'

const ENGINE = { kind: 'engine' } as const
const SUMMARY = { role: 'user' as const, text: 'summary', toolUses: [] }

const LISTING = [
  'The following skills are available for use with the Skill tool:',
  '',
  '- simplify: This is the code review skill on this machine. Use it to review any changed code.',
  '- anthropic-skills:pptx: Use this skill any time a .pptx or .potx file is involved in any way.',
  '- anthropic-skills:docx: Use this skill whenever the user wants to create, read, edit Word documents.',
  '- constructor: A user skill whose name is also an Object.prototype key.',
  '- agent-routing',
].join('\n')

const DOCS = '## claude.ai Claude Docs\nClaude Docs: living docs you create and edit here.'
const OTHER = '## exec\nRun code in the sandbox.'
const HEAD = '# MCP Server Instructions\n\nThe following MCP servers have provided instructions for how to use their tools and resources:\n\n'
const GONE = 'The following MCP servers have disconnected. Their instructions above no longer apply:\nexec'
const AMBIENT = 'This is ambient context — do not narrate it to the user.'
const DOCS_TOOL = 'mcp__claude_ai_Claude_Docs__read'

const attachment = (type: string, text: string, agentId?: string) => ({ type, text, origin: ENGINE, ...(agentId ? { agentId } : {}) })
const passAttachments = (on: any) => on('prompt.attachment', (_$: any, e: any) => ({ text: e.text }))
const delta = ($: any, text: string, agentId?: string) => $.prompt.attachment(attachment('mcp_instructions_delta', text, agentId))

const docsCall = ($: any, agentId?: string) =>
  $.tool.call({ tool: DOCS_TOOL, tool_use_id: 'd1', id: 'x', ...(agentId ? { agentId } : {}) })
// A Docs call the engine ran answers `ran`; one the mod refused carries the instructions in its deny.
const answerDocs = (on: any) => on('tool.call', { tool: DOCS_TOOL }, () => ({ result: 'ran' }))
const wasRefused = (r: any) => r.deny !== undefined || (r.isError === true && /deferred until its first call/.test(r.text ?? ''))

const toolResult = (tool: string, content: unknown, isError = false, id = 't1') => ({
  door: 'tool-result' as const,
  origin: { kind: 'tool' as const, tool },
  uuid: 'u1',
  message: {
    type: 'user' as const,
    role: 'user' as const,
    content: [{ type: 'tool_result' as const, tool_use_id: id, content, ...(isError ? { is_error: true } : {}) }],
  },
})

// Returns a function that appends one tool-result row and gives back the content as it reached the engine.
// The test kit has no storage beneath the plugins, so the bottom hook records the row and the kit's
// "no implementation" rejection that follows is expected.
const keeper = (on: any) => {
  let kept: any
  on('session.append', (_$: any, e: any, next: any) => {
    kept = e.message.content[0].content
    return next(e)
  })
  return async ($: any, row: ReturnType<typeof toolResult>) => {
    kept = undefined
    await $.session.append(row).catch((err: Error) => {
      if (!/no implementation for session.append/.test(err.message)) throw err
    })
    return kept
  }
}

// Returns a function that runs a Write or Edit call with `file_path`, then appends its result text and
// gives back the text as kept. Call it before the test's first call on `$`: the kit takes hooks only then.
const files = (on: any) => {
  on('tool.call', { tool: ['Write', 'Edit'] }, () => ({ result: {} }))
  const store = keeper(on)
  return async ($: any, tool: 'Write' | 'Edit', path: string, text: string, isError = false) => {
    await $.tool.call({ tool, tool_use_id: 't1', file_path: path, content: 'x', old_string: 'a', new_string: 'b' })
    return store($, toolResult(tool, text, isError))
  }
}
const fileResult = ($: any, on: any, tool: 'Write' | 'Edit', path: string, text: string, isError = false) =>
  files(on)($, tool, path, text, isError)

describe('skill_listing', () => {
  test('test_skill_listing_lazy_skill_shortened_to_hint', async ($, on) => {
    passAttachments(on)
    const { text } = await $.prompt.attachment(attachment('skill_listing', LISTING))
    expect(text).toContain('- anthropic-skills:pptx: PowerPoint .pptx / .potx files.')
    expect(text).not.toContain('any time a .pptx')
  })

  test('test_skill_listing_rarely_used_skill_keeps_routing_cue', async ($, on) => {
    passAttachments(on)
    const { text } = await $.prompt.attachment(attachment('skill_listing', LISTING))
    expect(text).toContain('- anthropic-skills:docx: Word .docx / .dotx files: create, read or edit.')
    expect(text).toContain('goes to Claude Docs instead.')
    expect(text).not.toContain('whenever the user wants')
  })

  test('test_skill_listing_other_lines_unchanged', async ($, on) => {
    passAttachments(on)
    const { text } = await $.prompt.attachment(attachment('skill_listing', LISTING))
    for (const line of LISTING.split('\n').filter(l => !/pptx|docx/.test(l))) expect(text).toContain(line)
    expect(text!.split('\n').length).toBe(LISTING.split('\n').length)
  })

  test('test_skill_listing_prototype_name_unchanged', async ($, on) => {
    passAttachments(on)
    const { text } = await $.prompt.attachment(attachment('skill_listing', LISTING))
    expect(text).toContain('- constructor: A user skill whose name is also an Object.prototype key.')
  })

  test('test_skill_listing_same_input_twice_same_output', async ($, on) => {
    passAttachments(on)
    const a = await $.prompt.attachment(attachment('skill_listing', LISTING))
    const b = await $.prompt.attachment(attachment('skill_listing', LISTING))
    expect(a.text).toBe(b.text)
  })

  test('test_skill_listing_already_shortened_stays_same', async ($, on) => {
    passAttachments(on)
    const once = await $.prompt.attachment(attachment('skill_listing', LISTING))
    const twice = await $.prompt.attachment(attachment('skill_listing', once.text!))
    expect(twice.text).toBe(once.text)
  })

  test('test_skill_listing_null_text_passes_through', async ($, on) => {
    on('prompt.attachment', () => ({ text: null }))
    expect((await $.prompt.attachment(attachment('skill_listing', ''))).text).toBe(null)
  })
})

const budget = (left: number) => `<total_tokens>${left} tokens left</total_tokens>`
const reminder = ($: any, text: string) => $.prompt.attachment(attachment('total_tokens_reminder', text))

describe('total_tokens_reminder', () => {
  test('test_budget_reminder_plenty_left_left_out', async ($, on) => {
    passAttachments(on)
    expect((await reminder($, budget(15000000))).text).toBe(null)
    expect((await reminder($, budget(14000000))).text).toBe(null)
  })

  test('test_budget_reminder_concurrent_requests_all_answered', async ($, on) => {
    passAttachments(on)
    const lefts = Array.from({ length: 20 }, (_, i) => 15000000 - i * 1000)
    const rs = await Promise.all(lefts.map(left => reminder($, budget(left))))
    for (const r of rs) expect(r.text).toBe(null)
  })

  test('test_budget_reminder_below_share_shown', async ($, on) => {
    passAttachments(on)
    await reminder($, budget(15000000))
    expect((await reminder($, budget(2999999))).text).toBe(budget(2999999))
  })

  test('test_budget_reminder_at_share_left_out', async ($, on) => {
    passAttachments(on)
    await reminder($, budget(15000000))
    expect((await reminder($, budget(3000000))).text).toBe(null)
  })

  test('test_budget_reminder_zero_left_shown', async ($, on) => {
    passAttachments(on)
    expect((await reminder($, budget(0))).text).toBe(budget(0))
  })

  test('test_budget_reminder_unparseable_unchanged', async ($, on) => {
    passAttachments(on)
    expect((await reminder($, 'budget unknown')).text).toBe('budget unknown')
  })

  test('test_budget_reminder_null_passes_through', async ($, on) => {
    on('prompt.attachment', () => ({ text: null }))
    expect((await reminder($, budget(10))).text).toBe(null)
  })
})

describe('output_style reminder', () => {
  const STYLE = 'colleague-zh output style is active. Remember to follow the specific guidelines for this style.'

  test('test_style_reminder_left_out', async ($, on) => {
    passAttachments(on)
    expect((await $.prompt.attachment(attachment('output_style', STYLE))).text).toBe(null)
  })

  test('test_style_instructions_section_unchanged', async ($, on) => {
    passAttachments(on)
    const text = '# Output Style: colleague-zh\nThis style governs user-facing prose only.'
    expect((await $.prompt.attachment(attachment('output_style_instructions', text))).text).toBe(text)
  })
})

describe('language drift', () => {
  const STYLE = 'colleague-zh output style is active. Remember to follow the specific guidelines for this style.'
  const EN = 'Now the footer navigation. I am handing it to the deck agent, then I check the rendered page.'
  const ZH = '頁尾導覽已經交給 deck agent，接著檢查渲染後的頁面。'

  // Appends one model response row; the kit has nothing beneath session.append, so its rejection is expected.
  const respond = ($: any, content: unknown[], agentId?: string, door = 'response') =>
    $.session
      .append({
        door,
        origin: door === 'response' ? { kind: 'model' } : { kind: 'tool', tool: 'Bash' },
        uuid: 'r1',
        message: { type: 'assistant', role: 'assistant', content },
        ...(agentId ? { agentId } : {}),
      })
      .catch((err: Error) => {
        if (!/no implementation for session.append/.test(err.message)) throw err
      })
  const text = (t: string) => ({ type: 'text', text: t })
  const styleReminder = async ($: any) => (await $.prompt.attachment(attachment('output_style', STYLE))).text

  test('test_drift_english_response_adds_language_note', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)])
    const r = await styleReminder($)
    expect(r).toContain(STYLE)
    expect(r).toContain('# Language')
  })

  test('test_drift_chinese_response_clears_note', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)])
    await respond($, [text(ZH)])
    expect(await styleReminder($)).toBe(null)
  })

  test('test_drift_note_repeats_until_chinese', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)])
    expect(await styleReminder($)).toContain('# Language')
    await respond($, [{ type: 'tool_use', id: 't9', name: 'Bash', input: {} }])
    expect(await styleReminder($)).toContain('# Language')
  })

  test('test_drift_english_quoting_chinese_terms_adds_note', async ($, on) => {
    passAttachments(on)
    await respond($, [text('The glossary tooltip only marks the first occurrence and skips buttons, so pointing the term at 「實驗對照組」 is safe.')])
    expect(await styleReminder($)).toContain('# Language')
  })

  test('test_drift_short_english_ignored', async ($, on) => {
    passAttachments(on)
    await respond($, [text('Done.')])
    expect(await styleReminder($)).toBe(null)
  })

  test('test_drift_code_only_block_ignored', async ($, on) => {
    passAttachments(on)
    await respond($, [text('```ts\nconst answer = await fetchTheValueFromTheServer(requestOptions, retries)\n```')])
    expect(await styleReminder($)).toBe(null)
  })

  test('test_drift_subagent_english_ignored', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)], 'agent-1')
    expect(await styleReminder($)).toBe(null)
  })

  test('test_drift_tool_result_english_ignored', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)], undefined, 'tool-result')
    expect(await styleReminder($)).toBe(null)
  })

  test('test_drift_no_style_text_stays_null', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)])
    expect((await $.prompt.attachment(attachment('output_style', ''))).text).toBe(null)
  })

  test('test_drift_same_state_twice_same_note', async ($, on) => {
    passAttachments(on)
    await respond($, [text(EN)])
    expect(await styleReminder($)).toBe(await styleReminder($))
  })
})

describe('mcp_instructions_delta', () => {
  test('test_mcp_docs_only_section_left_out', async ($, on) => {
    passAttachments(on)
    expect((await delta($, HEAD + DOCS)).text).toBe(null)
  })

  test('test_mcp_docs_only_with_ambient_line_left_out', async ($, on) => {
    passAttachments(on)
    expect((await delta($, HEAD + DOCS + '\n\n' + AMBIENT)).text).toBe(null)
  })

  test('test_mcp_other_server_kept_with_header', async ($, on) => {
    passAttachments(on)
    const { text } = await delta($, HEAD + DOCS + '\n\n' + OTHER)
    expect(text).toBe(HEAD + OTHER)
  })

  test('test_mcp_disconnect_notice_after_docs_kept', async ($, on) => {
    passAttachments(on)
    const { text } = await delta($, HEAD + DOCS + '\n\n' + GONE + '\n\n' + AMBIENT)
    expect(text).toBe(HEAD + GONE + '\n\n' + AMBIENT)
  })

  test('test_mcp_without_docs_unchanged', async ($, on) => {
    passAttachments(on)
    expect((await delta($, HEAD + OTHER)).text).toBe(HEAD + OTHER)
  })
})

describe('claude docs first call', () => {
  test('test_docs_first_call_refused_with_instructions', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    await delta($, HEAD + DOCS)
    const r: any = await docsCall($)
    expect(wasRefused(r)).toBe(true)
    expect(r.deny ?? r.text).toContain('Claude Docs: living docs you create and edit here.')
  })

  test('test_docs_second_call_runs', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    await delta($, HEAD + DOCS)
    await docsCall($)
    expect(wasRefused(await docsCall($))).toBe(false)
  })

  test('test_docs_call_without_stored_instructions_runs', async ($, on) => {
    answerDocs(on)
    expect(wasRefused(await docsCall($))).toBe(false)
  })

  test('test_docs_subagent_refused_after_main_read', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    await delta($, HEAD + DOCS)
    await docsCall($)
    expect(wasRefused(await docsCall($, 'sub1'))).toBe(true)
    expect(wasRefused(await docsCall($))).toBe(false)
  })

  test('test_docs_refused_again_after_compaction', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    on('session.compact', () => ({ messages: [SUMMARY] }))
    await delta($, HEAD + DOCS)
    await docsCall($)
    await $.session.compact({ trigger: 'manual', messages: [SUMMARY] })
    expect(wasRefused(await docsCall($))).toBe(true)
  })

  test('test_docs_subagent_compaction_leaves_main_read', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    on('session.compact', () => ({ messages: [SUMMARY] }))
    await delta($, HEAD + DOCS)
    await docsCall($)
    await $.session.compact({ trigger: 'auto', messages: [SUMMARY], agentId: 'sub1' })
    expect(wasRefused(await docsCall($))).toBe(false)
  })

  test('test_docs_skipped_compaction_keeps_read', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    on('session.compact', () => ({ skip: 'off' }))
    await delta($, HEAD + DOCS)
    await docsCall($)
    await $.session.compact({ trigger: 'manual', messages: [SUMMARY] })
    expect(wasRefused(await docsCall($))).toBe(false)
  })

  test('test_docs_refused_again_after_reconnect_delta', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    await delta($, HEAD + DOCS)
    await docsCall($)
    await delta($, HEAD + DOCS)
    expect(wasRefused(await docsCall($))).toBe(true)
  })

  test('test_docs_refused_again_after_session_end', async ($, on) => {
    passAttachments(on)
    answerDocs(on)
    on('session.end', (_$, e) => ({ sessionId: e.sessionId }))
    await delta($, HEAD + DOCS)
    await docsCall($)
    await $.session.end({ reason: 'clear', sessionId: 's1', resume: undefined as any })
    expect(wasRefused(await docsCall($))).toBe(true)
  })
})

describe('session.append tool results', () => {
  const P = '/home/user/a b/notes.md'
  const STATE = ' (file state is current in your context — no need to Read it back)'
  const STOP = JSON.stringify({ message: 'Successfully stopped task: b1 (sleep 5; echo "(done)")', task_id: 'b1', task_type: 'local_bash', command: 'sleep 5; echo "(done)"' })
  const SEND = JSON.stringify({ success: true, message: 'Message queued for delivery to a1 at its next tool round.', pin: { id: 'a1', name: 'a1', ref: 'c4' } })

  test('test_write_created_path_shortened_suffix_kept', async ($, on) => {
    expect(await fileResult($, on, 'Write', P, `File created successfully at: ${P}${STATE}`)).toBe(`File created successfully at: …/notes.md${STATE}`)
  })

  test('test_write_user_modified_note_with_slash_kept', async ($, on) => {
    const note = ' The user modified your proposed content before accepting it. See docs/a/b.'
    expect(await fileResult($, on, 'Write', P, `File created successfully at: ${P}${note}`)).toBe(`File created successfully at: …/notes.md${note}`)
  })

  test('test_edit_replace_all_variant_shortened', async ($, on) => {
    const text = `The file ${P} has been updated. All occurrences were successfully replaced.`
    expect(await fileResult($, on, 'Edit', P, text)).toBe('The file …/notes.md has been updated. All occurrences were successfully replaced.')
  })

  test('test_edit_disk_change_note_kept', async ($, on) => {
    const text = `The file ${P} has been updated successfully. (note: the file had been modified on disk since you last read it)`
    expect(await fileResult($, on, 'Edit', P, text)).toBe('The file …/notes.md has been updated successfully. (note: the file had been modified on disk since you last read it)')
  })

  test('test_write_expanded_path_unchanged', async ($, on) => {
    const text = `File created successfully at: /home/user/notes.md${STATE}`
    expect(await fileResult($, on, 'Write', '~/notes.md', text)).toBe(text)
  })

  test('test_write_without_recorded_call_unchanged', async ($, on) => {
    const text = `File created successfully at: ${P}${STATE}`
    expect(await keeper(on)($, toolResult('Write', text))).toBe(text)
  })

  test('test_write_error_result_unchanged', async ($, on) => {
    const text = `File created successfully at: ${P}${STATE}`
    expect(await fileResult($, on, 'Write', P, text, true)).toBe(text)
  })

  test('test_write_rewrite_twice_stays_same', async ($, on) => {
    const run = files(on)
    const once = await run($, 'Write', P, `File created successfully at: ${P}${STATE}`)
    expect(await run($, 'Write', P, once)).toBe(once)
  })

  test('test_taskstop_command_kept_once', async ($, on) => {
    const out = JSON.parse(await keeper(on)($, toolResult('TaskStop', STOP)))
    expect(out).toEqual({ message: 'Successfully stopped task: b1', task_id: 'b1', task_type: 'local_bash', command: 'sleep 5; echo "(done)"' })
  })

  test('test_taskstop_other_message_unchanged', async ($, on) => {
    const other = JSON.stringify({ message: 'No task found with ID: b9', task_id: 'b9', command: 'x' })
    expect(await keeper(on)($, toolResult('TaskStop', other))).toBe(other)
  })

  test('test_taskstop_invalid_json_unchanged', async ($, on) => {
    expect(await keeper(on)($, toolResult('TaskStop', 'Successfully stopped task: b1 (x'))).toBe('Successfully stopped task: b1 (x')
  })

  test('test_sendmessage_duplicate_pin_name_dropped', async ($, on) => {
    const out = JSON.parse(await keeper(on)($, toolResult('SendMessage', SEND)))
    expect(out.pin).toEqual({ id: 'a1', ref: 'c4' })
    expect(out.message).toBe('Message queued for delivery to a1 at its next tool round.')
  })

  test('test_sendmessage_distinct_pin_name_kept', async ($, on) => {
    const named = JSON.stringify({ success: true, message: 'm', pin: { id: 'a1', name: 'reviewer', ref: 'c4' } })
    expect(await keeper(on)($, toolResult('SendMessage', named))).toBe(named)
  })

  test('test_text_block_array_rewritten', async ($, on) => {
    on('tool.call', { tool: ['Write', 'Edit'] }, () => ({ result: {} }))
    const store = keeper(on)
    await $.tool.call({ tool: 'Write', tool_use_id: 't1', file_path: P, content: 'x' })
    const out = await store($, toolResult('Write', [{ type: 'text', text: `File created successfully at: ${P}` }]))
    expect(out[0].text).toBe('File created successfully at: …/notes.md')
  })

  test('test_whitespace_only_result_unchanged', async ($, on) => {
    expect(await fileResult($, on, 'Write', P, '   ')).toBe('   ')
  })

  test('test_other_tool_same_text_unchanged', async ($, on) => {
    const text = `File created successfully at: ${P}`
    expect(await keeper(on)($, toolResult('Bash', text))).toBe(text)
  })
})
