/**
 * Shared Logger Utility for Supabase Edge Functions
 * Redacts sensitive fields, auth tokens, passwords, and secret keys before printing to log streams.
 */

export function sanitizeData(data: any): any {
  if (!data) return data

  if (typeof data === 'string') {
    // Redact JWT tokens
    if (data.startsWith('Bearer ') || data.startsWith('eyJ')) {
      return '[REDACTED_JWT_TOKEN]'
    }
    // Redact Resend keys
    if (data.includes('re_')) {
      return data.replace(/re_[A-Za-z0-9_-]{20,}/g, '[REDACTED_RESEND_KEY]')
    }
    return data
  }

  if (typeof data === 'object') {
    const copy: Record<string, any> = Array.isArray(data) ? [] : {}
    const sensitiveKeys = ['password', 'token', 'secret', 'authorization', 'apikey', 'code', 'recovery_code', 'jwt']

    for (const [key, val] of Object.entries(data)) {
      const lowerKey = key.toLowerCase()
      if (sensitiveKeys.some((s) => lowerKey.includes(s))) {
        copy[key] = '[REDACTED]'
      } else if (typeof val === 'object' && val !== null) {
        copy[key] = sanitizeData(val)
      } else {
        copy[key] = val
      }
    }
    return copy
  }

  return data
}

export const logger = {
  info: (msg: string, meta?: any) => {
    console.log(`[INFO] ${msg}`, meta ? sanitizeData(meta) : '')
  },
  warn: (msg: string, meta?: any) => {
    console.warn(`[WARN] ${msg}`, meta ? sanitizeData(meta) : '')
  },
  error: (msg: string, meta?: any) => {
    console.error(`[ERROR] ${msg}`, meta ? sanitizeData(meta) : '')
  },
}
