export const meta = {
  name: 'retro-read',
  description: 'Read every chunk of each session, group its moments by cause, and have a fresh reviewer judge each cause against the harness then and now',
  phases: [
    { title: 'Read', detail: 'one retro-reader per chunk, its unread tail read again' },
    { title: 'Group', detail: 'moments grouped by cause within one session' },
    { title: 'Review', detail: 'one fresh reviewer per cause' },
  ],
}

const LABELS = ['correction', 'rejection', 'failure report', 'interruption']
const BEHAVIORS = ['wrong approach', 'misread request', 'overstep', 'overstated claim', 'buggy code', 'env']
const VERDICTS = ['fixed since', 'ignored', 'missing', 'one-off']
const ACTIONS = ['New', 'Update', 'Supersede', 'Split', 'Delete', 'Noop']
const READS_PER_CHUNK = 3

const MOMENTS = {
  type: 'object',
  properties: {
    read_through: { type: 'integer' },
    moments: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          line: { type: 'integer' },
          ts: { type: 'string' },
          label: { enum: LABELS },
          behavior: { enum: BEHAVIORS },
          his_words: { type: 'string' },
          what_went_wrong: { type: 'string' },
        },
        required: ['line', 'ts', 'label', 'behavior', 'his_words', 'what_went_wrong'],
      },
    },
  },
  required: ['read_through', 'moments'],
}

const GROUPS = {
  type: 'object',
  properties: {
    groups: {
      type: 'array',
      items: {
        type: 'object',
        properties: { cause: { type: 'string' }, moment_ids: { type: 'array', items: { type: 'integer' } } },
        required: ['cause', 'moment_ids'],
      },
    },
  },
  required: ['groups'],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    rule_then: { type: 'string' },
    rule_now: { type: 'string' },
    change: {
      type: 'object',
      properties: { target: { type: 'string' }, text: { type: 'string' }, action: { enum: ACTIONS } },
      required: ['target', 'text', 'action'],
    },
    would_change: { type: 'string' },
    contradicts: { type: 'string' },
  },
  required: ['verdict', 'rule_then', 'rule_now', 'would_change', 'contradicts'],
}

const short = (session) => session.id.slice(0, 8)

async function readChunk(session, chunk) {
  const moments = []
  const outOfRange = []
  let from = chunk.first
  for (let read = 0; read < READS_PER_CHUNK && from <= chunk.last; read++) {
    const result = await agent(
      `Chunk file: ${chunk.path}\nYour range: i ${from} to ${chunk.last}.` +
        (from > chunk.first ? ` Lines before i ${from} were read already; start at i ${from}.` : '') +
        `\nPointers (his memory index): ${session.memory_index}`,
      { agentType: 'retro-reader', schema: MOMENTS, phase: 'Read', label: `read ${short(session)} ${chunk.path.split('/').pop()} from ${from}` },
    )
    if (!result) break
    for (const moment of result.moments) {
      if (moment.line >= from && moment.line <= chunk.last) moments.push(moment)
      else outOfRange.push(moment)
    }
    from = Math.max(from, result.read_through + 1)
  }
  return { moments, outOfRange, unread: from <= chunk.last ? { path: chunk.path, from, to: chunk.last } : null }
}

async function readSession(session) {
  const reads = (await parallel(session.chunks.map((chunk) => () => readChunk(session, chunk)))).filter(Boolean)
  const moments = reads.flatMap((r) => r.moments).sort((a, b) => a.line - b.line).map((m, id) => ({ id, ...m }))
  const outOfRange = reads.flatMap((r) => r.outOfRange)
  const unread = reads.map((r) => r.unread).filter(Boolean)
  const unreadChunks = session.chunks.length - reads.length
  if (outOfRange.length) log(`${short(session)}: ${outOfRange.length} moments cited an i outside their chunk and were dropped`)
  if (unread.length || unreadChunks) log(`${short(session)}: ${unread.length} chunk tails and ${unreadChunks} whole chunks not read`)
  return { session, moments, outOfRange, unread, unreadChunks }
}

async function groupSession(read) {
  if (!read.moments.length) return { ...read, groups: [] }
  const listing = read.moments
    .map((m) => `${m.id} | i ${m.line} | ${m.behavior} | "${m.his_words}" | ${m.what_went_wrong}`)
    .join('\n')
  const ask = (extra) =>
    agent(
      `Group these moments from one Claude Code session by root cause: what in Claude's behaviour or the harness let each happen. ` +
        `Name each cause in a short phrase. Every id goes in exactly one group.${extra}\n\nid | line | behavior | his words | what went wrong\n${listing}`,
      { schema: GROUPS, phase: 'Group', label: `group ${short(read.session)}` },
    )
  const check = (result) => {
    const seen = result ? result.groups.flatMap((g) => g.moment_ids) : []
    const missing = read.moments.map((m) => m.id).filter((id) => !seen.includes(id))
    return { missing, duplicated: seen.length !== new Set(seen).size }
  }
  let result = await ask('')
  let problems = check(result)
  if (problems.missing.length || problems.duplicated) {
    result = await ask(`\nA first attempt left out ids ${problems.missing.join(', ') || 'none'} or put an id in two groups; fix both.`)
    problems = check(result)
  }
  const groups = result ? result.groups : []
  if (problems.missing.length) groups.push({ cause: 'ungrouped', moment_ids: problems.missing })
  return { ...read, groups }
}

async function reviewSession(grouped) {
  const { session } = grouped
  const verdicts = await parallel(
    grouped.groups.map((group) => () => {
      const moments = group.moment_ids.map((id) => grouped.moments[id]).filter(Boolean)
      return agent(
        `Judge one cause of corrections in a Claude Code session against Anand's harness.\n\n` +
          `Cause: ${group.cause}\nMoments (line = i in ${session.pairs}, which you may read for context):\n${JSON.stringify(moments, null, 1)}\n\n` +
          `Harness when the session started: ${session.then} (empty means no history exists for that date; then "ignored" cannot be shown).\n` +
          `Harness now: ${session.now}. Which file owns each rule: ${session.resolver}.\n\n` +
          `Verdict:\n- fixed since: a rule added after the session covers it. No change.\n` +
          `- ignored: a rule covered it then. Change: make it clearer, or a hook when it must never be broken.\n` +
          `- missing: nothing covered it. Draft the change (target file, exact text, action), and in would_change say whether that text would have changed what Claude did at the cited lines; if it would not, give no change.\n` +
          `- one-off: an accident, not a gap. No change.\n` +
          `Prefer a hook over a rule update, and an update or delete over a new line, unless a new line is clearly the best fit. ` +
          `rule_then and rule_now quote the covering rule with file:line, or say none. contradicts names any existing rule the change would contradict, or is empty.`,
        { agentType: 'reviewer', schema: VERDICT, phase: 'Review', label: `review ${short(session)} ${group.cause.slice(0, 40)}` },
      ).then((verdict) => ({ ...group, verdict }))
    }),
  )
  return {
    id: session.id,
    moments: grouped.moments,
    out_of_range: grouped.outOfRange,
    unread: grouped.unread,
    unread_chunks: grouped.unreadChunks,
    groups: verdicts.filter(Boolean),
  }
}

return await pipeline(args.sessions, readSession, groupSession, reviewSession)
