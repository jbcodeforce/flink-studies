import { parseOneSseBlock, effectiveEventName } from '@/utils/sseParse.js'

const PREFIX = '/agent-os'

function url(path) {
  const p = path.startsWith('/') ? path : `/${path}`
  return `${PREFIX}${p}`
}

async function jsonFetch(path, options = {}) {
  const res = await fetch(url(path), {
    headers: { Accept: 'application/json', ...options.headers },
    ...options
  })
  const text = await res.text()
  if (!res.ok) {
    let detail = res.statusText
    try {
      const j = JSON.parse(text)
      if (j.detail != null) detail = typeof j.detail === 'string' ? j.detail : JSON.stringify(j.detail)
    } catch {
      if (text) detail = text.slice(0, 500)
    }
    throw new Error(detail)
  }
  return text ? JSON.parse(text) : null
}

export async function listAgents() {
  return jsonFetch('/agents')
}

/**
 * @param {{ userId?: string, agentId: string, page?: number, limit?: number }} params
 */
export async function listSessions({ userId, agentId, page = 1, limit = 20 }) {
  const q = new URLSearchParams({
    type: 'agent',
    component_id: agentId,
    page: String(page),
    limit: String(limit)
  })
  if (userId) q.set('user_id', userId)
  return jsonFetch(`/sessions?${q.toString()}`)
}

/**
 * @param {string} sessionId
 * @param {{ userId?: string }} [opts]
 */
export async function getSession(sessionId, opts = {}) {
  const q = new URLSearchParams()
  if (opts.userId) q.set('user_id', opts.userId)
  const qs = q.toString()
  return jsonFetch(`/sessions/${encodeURIComponent(sessionId)}${qs ? `?${qs}` : ''}`)
}

/**
 * Map AgentOS chat_history entries to UI messages (skip system).
 * @param {Array<{ role?: string, content?: unknown }>} chatHistory
 */
export function chatHistoryToMessages(chatHistory) {
  if (!Array.isArray(chatHistory)) return []
  const out = []
  for (const m of chatHistory) {
    const role = m.role
    if (role === 'system') continue
    if (role !== 'user' && role !== 'assistant') continue
    const content =
      typeof m.content === 'string' ? m.content : m.content != null ? String(m.content) : ''
    out.push({ role, content })
  }
  return out
}

/**
 * Process AgentOS agent run SSE stream.
 * @param {ReadableStream<Uint8Array>} body
 * @param {{
 *   onTextChunk?: (s: string) => void,
 *   onSessionId?: (id: string) => void,
 *   onRunMeta?: (meta: object) => void,
 *   onError?: (err: Error) => void,
 *   onDone?: () => void
 * }} handlers
 */
export async function consumeAgentRunSse(body, handlers) {
  const reader = body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  let completed = false

  const finish = () => {
    if (!completed) {
      completed = true
      handlers.onDone?.()
    }
  }

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })
      const parts = buffer.split('\n\n')
      buffer = parts.pop() ?? ''
      for (const block of parts) {
        const trimmed = block.trim()
        if (!trimmed) continue
        const { eventType, payload } = parseOneSseBlock(trimmed)
        if (!payload) continue
        const ev = effectiveEventName(eventType, payload)

        if (ev === 'RunStarted') {
          if (payload.session_id) handlers.onSessionId?.(String(payload.session_id))
          handlers.onRunMeta?.(payload)
        }
        if (ev === 'RunContent' || ev === 'RunIntermediateContent') {
          const c = payload.content
          if (c != null && c !== '') {
            handlers.onTextChunk?.(typeof c === 'string' ? c : String(c))
          }
        }
        if (ev === 'RunError') {
          handlers.onError?.(new Error(String(payload.content ?? 'RunError')))
          finish()
          return
        }
        if (ev === 'RunCompleted') {
          finish()
          return
        }
      }
    }
    if (buffer.trim()) {
      const { eventType, payload } = parseOneSseBlock(buffer.trim())
      if (payload) {
        const ev = effectiveEventName(eventType, payload)
        if (ev === 'RunError') {
          handlers.onError?.(new Error(String(payload.content ?? 'RunError')))
        }
        if (ev === 'RunCompleted') {
          finish()
          return
        }
      }
    }
  } finally {
    finish()
  }
}

/**
 * @param {string} agentId
 * @param {{ message: string, sessionId?: string | null, userId?: string | null }} input
 * @param {{
 *   onTextChunk?: (s: string) => void,
 *   onSessionId?: (id: string) => void,
 *   onRunMeta?: (meta: object) => void,
 *   onError?: (err: Error) => void,
 *   onDone?: () => void
 * }} handlers
 */
export async function createAgentRunStream(agentId, input, handlers) {
  const form = new FormData()
  form.set('message', input.message)
  form.set('stream', 'true')
  if (input.sessionId) form.set('session_id', input.sessionId)
  if (input.userId) form.set('user_id', input.userId)

  const res = await fetch(url(`/agents/${encodeURIComponent(agentId)}/runs`), {
    method: 'POST',
    body: form
  })

  if (!res.ok) {
    const text = await res.text()
    let detail = res.statusText
    try {
      const j = JSON.parse(text)
      if (j.detail != null) detail = typeof j.detail === 'string' ? j.detail : JSON.stringify(j.detail)
    } catch {
      if (text) detail = text.slice(0, 500)
    }
    handlers.onError?.(new Error(detail))
    handlers.onDone?.()
    return
  }

  if (!res.body) {
    handlers.onError?.(new Error('Empty response body'))
    handlers.onDone?.()
    return
  }

  await consumeAgentRunSse(res.body, handlers)
}

export function pickAgentId(agentsResponse, fallback = 'expert-agent') {
  if (!agentsResponse) return fallback
  const list = Array.isArray(agentsResponse) ? agentsResponse : agentsResponse.agents
  if (!Array.isArray(list) || list.length === 0) return fallback
  const byId = list.find((a) => a.id === fallback || a.agent_id === fallback)
  if (byId) return byId.id ?? byId.agent_id ?? fallback
  const first = list[0]
  return first.id ?? first.agent_id ?? fallback
}
