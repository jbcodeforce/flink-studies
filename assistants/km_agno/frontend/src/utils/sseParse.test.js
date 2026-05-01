import { describe, it, expect } from 'vitest'
import { parseOneSseBlock, effectiveEventName } from './sseParse.js'

describe('parseOneSseBlock', () => {
  it('parses event and data JSON', () => {
    const block = `event: RunContent\ndata: {"event":"RunContent","content":"hello","session_id":"s1"}\n`
    const { eventType, payload } = parseOneSseBlock(block)
    expect(eventType).toBe('RunContent')
    expect(payload.content).toBe('hello')
    expect(payload.session_id).toBe('s1')
  })

  it('returns null payload on invalid JSON', () => {
    const { payload } = parseOneSseBlock('event: X\ndata: not-json\n')
    expect(payload).toBeNull()
  })
})

describe('effectiveEventName', () => {
  it('prefers payload.event', () => {
    expect(effectiveEventName('Wrong', { event: 'RunContent' })).toBe('RunContent')
  })

  it('falls back to wire event type', () => {
    expect(effectiveEventName('RunCompleted', { foo: 1 })).toBe('RunCompleted')
  })
})
