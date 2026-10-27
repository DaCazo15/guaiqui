import { describe, it, expect } from 'vitest'
import { assertNoPrivateSecretsInPublic, validatePublicEnv } from '../envValidation'

describe('envValidation', () => {
  describe('assertNoPrivateSecretsInPublic', () => {
    it('does not throw when public object has no private secrets', () => {
      const safeConfig = {
        SUPABASE_URL: 'https://test.supabase.co',
        SUPABASE_ANON_KEY: 'safe-anon-key-12345678901234567890',
        APP_NAME: 'Guaiqueríes',
      }
      expect(() => assertNoPrivateSecretsInPublic(safeConfig)).not.toThrow()
    })

    it('handles null or empty objects safely', () => {
      expect(() => assertNoPrivateSecretsInPublic(null as unknown as Record<string, unknown>)).not.toThrow()
      expect(() => assertNoPrivateSecretsInPublic({})).not.toThrow()
    })

    it('throws error when service_role is detected', () => {
      const leakedConfig = {
        role: 'service_role',
      }
      expect(() => assertNoPrivateSecretsInPublic(leakedConfig)).toThrow(
        /Supabase Service Role JWT/
      )
    })

    it('throws error when RESEND_API_KEY is detected in payload', () => {
      const leakedConfig = {
        config: 'RESEND_API_KEY=re_123456',
      }
      expect(() => assertNoPrivateSecretsInPublic(leakedConfig)).toThrow(
        /Resend Secret Key Variable/
      )
    })

    it('throws error when TURNSTILE_SECRET_KEY is detected', () => {
      const leakedConfig = {
        secret: 'TURNSTILE_SECRET_KEY=0x4AAAAAA',
      }
      expect(() => assertNoPrivateSecretsInPublic(leakedConfig)).toThrow(
        /Turnstile Secret Key Variable/
      )
    })

    it('throws error when VAPID_PRIVATE_KEY is detected', () => {
      const leakedConfig = {
        push: 'VAPID_PRIVATE_KEY=secret_vapid',
      }
      expect(() => assertNoPrivateSecretsInPublic(leakedConfig)).toThrow(
        /VAPID Private Key Variable/
      )
    })
  })

  describe('validatePublicEnv', () => {
    it('passes for valid SUPABASE_URL and SUPABASE_ANON_KEY', () => {
      const validEnv = {
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_ANON_KEY: 'valid-long-anon-key-exceeding-twenty-characters',
      }
      expect(validatePublicEnv(validEnv)).toBe(true)
    })

    it('throws when SUPABASE_URL is missing or invalid', () => {
      expect(() => validatePublicEnv({ SUPABASE_ANON_KEY: 'long-enough-key-here-123456' })).toThrow(
        /SUPABASE_URL debe ser una URL válida/
      )
      expect(() =>
        validatePublicEnv({ SUPABASE_URL: 'ftp://not-http', SUPABASE_ANON_KEY: 'long-enough-key-here-123456' })
      ).toThrow(/SUPABASE_URL debe ser una URL válida/)
    })

    it('throws when SUPABASE_ANON_KEY is missing or too short', () => {
      expect(() =>
        validatePublicEnv({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'short' })
      ).toThrow(/SUPABASE_ANON_KEY debe estar configurada/)
      expect(() =>
        validatePublicEnv({ SUPABASE_URL: 'https://example.supabase.co' })
      ).toThrow(/SUPABASE_ANON_KEY debe estar configurada/)
    })
  })
})
