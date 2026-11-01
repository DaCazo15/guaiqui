/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { Capacitor } from '@capacitor/core'
import { Preferences } from '@capacitor/preferences'
import { capacitorStorage } from '../utils/capacitorStorage'
import { parseDeepLinkUrl } from '../utils/deepLinks'

vi.mock('@capacitor/core', () => ({
  Capacitor: {
    isNativePlatform: vi.fn(),
    getPlatform: vi.fn()
  }
}))

vi.mock('@capacitor/preferences', () => ({
  Preferences: {
    get: vi.fn(),
    set: vi.fn(),
    remove: vi.fn()
  }
}))

describe('Capacitor Mobile Integration & Adaptations', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorage.clear()
  })

  describe('capacitorStorage (Session persistence)', () => {
    describe('Native Mobile Platform (Android/iOS)', () => {
      beforeEach(() => {
        vi.mocked(Capacitor.isNativePlatform).mockReturnValue(true)
      })

      it('reads session token from Preferences.get when native', async () => {
        vi.mocked(Preferences.get).mockResolvedValueOnce({ value: 'sb-native-token-abc' })

        const token = await capacitorStorage.getItem('sb-access-token')

        expect(Capacitor.isNativePlatform).toHaveBeenCalled()
        expect(Preferences.get).toHaveBeenCalledWith({ key: 'sb-access-token' })
        expect(token).toBe('sb-native-token-abc')
      })

      it('stores session token using Preferences.set when native', async () => {
        await capacitorStorage.setItem('sb-access-token', 'sb-native-token-xyz')

        expect(Preferences.set).toHaveBeenCalledWith({
          key: 'sb-access-token',
          value: 'sb-native-token-xyz'
        })
      })

      it('removes session token using Preferences.remove when native', async () => {
        await capacitorStorage.removeItem('sb-access-token')

        expect(Preferences.remove).toHaveBeenCalledWith({ key: 'sb-access-token' })
      })
    })

    describe('Web Browser Platform', () => {
      beforeEach(() => {
        vi.mocked(Capacitor.isNativePlatform).mockReturnValue(false)
      })

      it('falls back to window.localStorage.getItem when on web', async () => {
        localStorage.setItem('sb-access-token', 'web-token-123')

        const token = await capacitorStorage.getItem('sb-access-token')

        expect(Preferences.get).not.toHaveBeenCalled()
        expect(token).toBe('web-token-123')
      })

      it('falls back to window.localStorage.setItem when on web', async () => {
        await capacitorStorage.setItem('sb-access-token', 'web-token-456')

        expect(Preferences.set).not.toHaveBeenCalled()
        expect(localStorage.getItem('sb-access-token')).toBe('web-token-456')
      })

      it('falls back to window.localStorage.removeItem when on web', async () => {
        localStorage.setItem('sb-access-token', 'web-token-789')
        await capacitorStorage.removeItem('sb-access-token')

        expect(Preferences.remove).not.toHaveBeenCalled()
        expect(localStorage.getItem('sb-access-token')).toBeNull()
      })
    })
  })

  describe('parseDeepLinkUrl (Deep Links & OAuth Callbacks)', () => {
    it('parses OAuth hash callback (access_token & refresh_token)', () => {
      const url = 'guaiqui://auth-callback#access_token=token-abc&refresh_token=refresh-xyz&expires_in=3600'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(true)
      expect(parsed.accessToken).toBe('token-abc')
      expect(parsed.refreshToken).toBe('refresh-xyz')
      expect(parsed.path).toBe('/app')
    })

    it('parses OAuth query code callback', () => {
      const url = 'guaiqui://auth-callback?code=oauth-auth-code-123'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(true)
      expect(parsed.authCode).toBe('oauth-auth-code-123')
      expect(parsed.path).toBe('/app')
    })

    it('parses team deep link (/e/[slug])', () => {
      const url = 'guaiqui://e/guaiqueries'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(false)
      expect(parsed.path).toBe('/e/guaiqueries')
    })

    it('parses profile deep link (/u/[id])', () => {
      const url = 'guaiqui://u/fan-uuid-555'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(false)
      expect(parsed.path).toBe('/u/fan-uuid-555')
    })

    it('parses referral signup deep link (/registro?ref=CODE)', () => {
      const url = 'guaiqui://registro?ref=GUAIQUI_FAN'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(false)
      expect(parsed.path).toBe('/registro?ref=GUAIQUI_FAN')
    })

    it('parses universal https links (https://guaiqueries.com/e/marinos)', () => {
      const url = 'https://guaiqueries.com/e/marinos?tab=trivias'
      const parsed = parseDeepLinkUrl(url)

      expect(parsed.isAuthCallback).toBe(false)
      expect(parsed.path).toBe('/e/marinos?tab=trivias')
    })

    it('returns root path fallback for empty or invalid input', () => {
      expect(parseDeepLinkUrl('')).toEqual({ isAuthCallback: false, path: '/' })
    })
  })
})
