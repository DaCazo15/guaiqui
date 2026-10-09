import { describe, it, expect, beforeEach } from 'vitest'
import { useAnalytics } from '../composables/useAnalytics'

describe('Fase 8C — Analytics & Privacy Unit Tests', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('by default discards events when consent is denied or pending', () => {
    const analytics = useAnalytics()
    analytics.initConsent()

    const result = analytics.trackEvent('cta_click', { section: 'hero', target: '/registro' })
    expect(result).toBeNull()
  })

  it('tracks sanitized events when consent is explicitly granted', () => {
    const analytics = useAnalytics()
    analytics.setConsent(true)

    const result = analytics.trackEvent('cta_click', { section: 'hero', target: '/registro' })
    expect(result).not.toBeNull()
    expect(result?.eventName).toBe('cta_click')
    expect(result?.properties).toEqual({ section: 'hero', target: '/registro' })
  })

  it('strictly filters out PII keys from event properties', () => {
    const analytics = useAnalytics()

    const dirtyProps = {
      section: 'checkout',
      email: 'fan@guaiqui.test',
      name: 'Juan Perez',
      display_name: 'JuanPerez123',
      balance: 5000,
      balance_cache: 5000,
      pearls: 5000,
      product_id: 'prod-uuid-123',
      cost_pearls: 100,
    }

    const cleanProps = analytics.sanitizeProperties(dirtyProps)

    expect(cleanProps).toEqual({
      section: 'checkout',
      product_id: 'prod-uuid-123',
      cost_pearls: 100,
    })

    expect(cleanProps).not.toHaveProperty('email')
    expect(cleanProps).not.toHaveProperty('name')
    expect(cleanProps).not.toHaveProperty('display_name')
    expect(cleanProps).not.toHaveProperty('balance')
    expect(cleanProps).not.toHaveProperty('balance_cache')
    expect(cleanProps).not.toHaveProperty('pearls')
  })

  it('discards events immediately if user revokes analytics consent', () => {
    const analytics = useAnalytics()
    analytics.setConsent(true)

    expect(analytics.hasAnalyticsConsent.value).toBe(true)

    // User revokes consent in settings or banner
    analytics.setConsent(false)

    expect(analytics.hasAnalyticsConsent.value).toBe(false)
    const result = analytics.trackEvent('trivia_started', { trivia_id: 't-1' })
    expect(result).toBeNull()
  })
})
