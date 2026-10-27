import { describe, it, expect } from 'vitest'

/**
 * Unit tests replicating the exact verification rules implemented in
 * supabase/functions/verify-captcha/index.ts
 */

function resolveClientIp(headers: Record<string, string | null | undefined>): string {
  const cfConnecting = headers['cf-connecting-ip']
  const xRealIp = headers['x-real-ip']
  if (cfConnecting) return cfConnecting.trim()
  if (xRealIp) return xRealIp.trim()

  const xff = headers['x-forwarded-for']
  if (xff) {
    const hops = xff.split(',').map((ip) => ip.trim()).filter(Boolean)
    return hops[hops.length - 1] || '127.0.0.1'
  }
  return '127.0.0.1'
}

interface VerifyParams {
  token?: string | null
  environment: string
  turnstileSecretKey?: string | null
  ipSalt?: string | null
}

interface VerifyResult {
  status: number
  body: { success?: boolean; error?: string }
}

function evaluateCaptchaPrerequisites(params: VerifyParams): VerifyResult | null {
  const isLocal = params.environment === 'local' || params.environment === 'test'

  // Fail closed if required secrets are absent in staging/production
  if (!isLocal && (!params.turnstileSecretKey || !params.ipSalt)) {
    return {
      status: 500,
      body: { error: 'Error de configuración del servidor' }
    }
  }

  // Mandatory token check
  if (!params.token || typeof params.token !== 'string' || params.token.trim() === '') {
    return {
      status: 400,
      body: { error: 'Token de captcha obligatorio' }
    }
  }

  // Mock token check
  if (params.token === 'test-valid-pass') {
    if (!isLocal) {
      return {
        status: 400,
        body: { error: 'Token de captcha inválido' }
      }
    }
    return {
      status: 200,
      body: { success: true }
    }
  }

  return null // Proceed to external Turnstile API call
}

describe('verify-captcha Security and IP Resolution Rules', () => {
  describe('Environment-based mock token enforcement', () => {
    it('rejects "test-valid-pass" with 400 when ENVIRONMENT=production', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'test-valid-pass',
        environment: 'production',
        turnstileSecretKey: '0x4AAAAAA_REAL_SECRET',
        ipSalt: 'super_secure_salt'
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(400)
      expect(res?.body.error).toBe('Token de captcha inválido')
    })

    it('rejects "test-valid-pass" with 400 when ENVIRONMENT=staging', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'test-valid-pass',
        environment: 'staging',
        turnstileSecretKey: '0x4AAAAAA_REAL_SECRET',
        ipSalt: 'super_secure_salt'
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(400)
      expect(res?.body.error).toBe('Token de captcha inválido')
    })

    it('accepts "test-valid-pass" when ENVIRONMENT=local', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'test-valid-pass',
        environment: 'local',
        turnstileSecretKey: null,
        ipSalt: null
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(200)
      expect(res?.body.success).toBe(true)
    })

    it('accepts "test-valid-pass" when ENVIRONMENT=test', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'test-valid-pass',
        environment: 'test',
        turnstileSecretKey: null,
        ipSalt: null
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(200)
      expect(res?.body.success).toBe(true)
    })
  })

  describe('Missing configuration fail-closed behavior', () => {
    it('fails closed with 500 in production when TURNSTILE_SECRET_KEY is missing', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'valid_cf_token_from_widget',
        environment: 'production',
        turnstileSecretKey: null,
        ipSalt: 'some_salt'
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(500)
      expect(res?.body.error).toBe('Error de configuración del servidor')
    })

    it('fails closed with 500 in production when IP_SALT is missing', () => {
      const res = evaluateCaptchaPrerequisites({
        token: 'valid_cf_token_from_widget',
        environment: 'production',
        turnstileSecretKey: '0x4AAAAAA_REAL_SECRET',
        ipSalt: null
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(500)
      expect(res?.body.error).toBe('Error de configuración del servidor')
    })

    it('rejects empty or whitespace-only token with 400', () => {
      const res = evaluateCaptchaPrerequisites({
        token: '   ',
        environment: 'production',
        turnstileSecretKey: '0x4AAAAAA_REAL_SECRET',
        ipSalt: 'some_salt'
      })
      expect(res).not.toBeNull()
      expect(res?.status).toBe(400)
      expect(res?.body.error).toBe('Token de captcha obligatorio')
    })
  })

  describe('Client IP extraction and proxy spoofing prevention', () => {
    it('prioritizes cf-connecting-ip over x-forwarded-for', () => {
      const ip = resolveClientIp({
        'cf-connecting-ip': '190.200.10.5',
        'x-forwarded-for': '127.0.0.1, 10.0.0.1'
      })
      expect(ip).toBe('190.200.10.5')
    })

    it('prioritizes x-real-ip when cf-connecting-ip is missing', () => {
      const ip = resolveClientIp({
        'x-real-ip': '190.200.10.6',
        'x-forwarded-for': '127.0.0.1, 10.0.0.1'
      })
      expect(ip).toBe('190.200.10.6')
    })

    it('takes the last trusted hop from x-forwarded-for to prevent client spoofing', () => {
      // Attacker sends: X-Forwarded-For: 8.8.8.8 (spoofed)
      // Edge proxy appends: 200.10.20.30
      // Full header: "8.8.8.8, 200.10.20.30"
      const ip = resolveClientIp({
        'x-forwarded-for': '8.8.8.8, 200.10.20.30'
      })
      expect(ip).toBe('200.10.20.30')
    })

    it('falls back to 127.0.0.1 when no IP headers are present', () => {
      const ip = resolveClientIp({})
      expect(ip).toBe('127.0.0.1')
    })
  })
})
