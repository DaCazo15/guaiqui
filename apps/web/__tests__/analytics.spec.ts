import { describe, it, expect, beforeEach } from 'vitest'
import { useAnalytics, normalizePath } from '../composables/useAnalytics'

describe('Fase 17 — GA4 & Analytics Layer Unit Tests', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('by default discards events when consent is denied or pending', () => {
    const analytics = useAnalytics()
    analytics.initConsent()

    const result = analytics.trackEvent('cta_click', { section: 'hero', destination: '/registro' })
    expect(result).toBeNull()
  })

  it('tracks sanitized events when consent is explicitly granted', () => {
    const analytics = useAnalytics()
    analytics.setConsent(true)

    const result = analytics.trackEvent('cta_click', { section: 'hero', destination: '/registro' })
    expect(result).not.toBeNull()
    expect(result?.eventName).toBe('cta_click')
    expect(result?.properties).toEqual({ section: 'hero', destination: '/registro' })
  })

  it('strictly filters out PII keys from event properties', () => {
    const analytics = useAnalytics()

    const dirtyProps = {
      section: 'checkout',
      email: 'fan@guaiqui.test',
      name: 'Juan Perez',
      display_name: 'JuanPerez123',
      birth_date: '1995-05-20',
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
    expect(cleanProps).not.toHaveProperty('birth_date')
    expect(cleanProps).not.toHaveProperty('balance')
  })

  it('normalizes SPA route paths replacing UUIDs and numeric IDs with :id', () => {
    expect(normalizePath('/app/canjes/123e4567-e89b-12d3-a456-426614174000')).toBe('/app/canjes/:id')
    expect(normalizePath('/app/trivias/98765')).toBe('/app/trivias/:id')
    expect(normalizePath('/app/billetera?token=secret123')).toBe('/app/billetera')
    expect(normalizePath('/app/perfil')).toBe('/app/perfil')
  })

  it('discards events immediately if user revokes analytics consent', () => {
    const analytics = useAnalytics()
    analytics.setConsent(true)

    expect(analytics.hasAnalyticsConsent.value).toBe(true)

    analytics.setConsent(false)

    expect(analytics.hasAnalyticsConsent.value).toBe(false)
    const result = analytics.trackEvent('trivia_started', { trivia_id: 't-1' })
    expect(result).toBeNull()
  })

  it('supports non-reserved rewarded_ad_* event names for Phase 18', () => {
    const analytics = useAnalytics()
    analytics.setConsent(true)

    const result = analytics.trackEvent('rewarded_ad_granted', { ad_id: 'ad-123', reward_pearls: 50 })
    expect(result).not.toBeNull()
    expect(result?.eventName).toBe('rewarded_ad_granted')
    expect(result?.properties).toEqual({ ad_id: 'ad-123', reward_pearls: 50 })
  })
})
