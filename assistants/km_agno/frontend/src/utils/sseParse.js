/**
 * Parse one SSE block (lines between blank lines) into event name and JSON payload.
 * @param {string} block
 * @returns {{ eventType: string | null, payload: object | null }}
 */
export function parseOneSseBlock(block) {
  let eventType = null
  const dataLines = []
  for (const line of block.split('\n')) {
    if (line.startsWith('event:')) {
      eventType = line.slice(6).trim()
    } else if (line.startsWith('data:')) {
      dataLines.push(line.slice(5).trimStart())
    }
  }
  if (dataLines.length === 0) {
    return { eventType, payload: null }
  }
  const raw = dataLines.join('\n')
  try {
    const payload = JSON.parse(raw)
    return { eventType, payload }
  } catch {
    return { eventType, payload: null }
  }
}

/**
 * Effective event name: SSE wire event line wins when payload.event is missing.
 * @param {string | null} eventType
 * @param {object | null} payload
 */
export function effectiveEventName(eventType, payload) {
  if (payload && typeof payload.event === 'string' && payload.event) {
    return payload.event
  }
  return eventType || null
}
