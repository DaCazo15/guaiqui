/**
 * Utility for Environment Variable Validation & Leak Detection
 */

export function assertNoPrivateSecretsInPublic(publicObj: Record<string, unknown>): void {
  if (!publicObj) return
  const serialized = JSON.stringify(publicObj)

  const forbiddenPatterns = [
    { pattern: 'role":"service_role"', name: 'Supabase Service Role JWT' },
    { pattern: 'RESEND_API_KEY', name: 'Resend Secret Key Variable' },
    { pattern: 'TURNSTILE_SECRET_KEY', name: 'Turnstile Secret Key Variable' },
    { pattern: 'VAPID_PRIVATE_KEY', name: 'VAPID Private Key Variable' },
  ]

  for (const { pattern, name } of forbiddenPatterns) {
    if (serialized.includes(pattern)) {
      throw new Error(`[SEGURIDAD DE ENTORNOS] ¡ALERTA DE FUGA! Se detectó el secreto privado (${name}) dentro de las variables públicas del cliente.`)
    }
  }
}

export function validatePublicEnv(env: { SUPABASE_URL?: string; SUPABASE_ANON_KEY?: string }): boolean {
  if (!env.SUPABASE_URL || !env.SUPABASE_URL.startsWith('http')) {
    throw new Error('SUPABASE_URL debe ser una URL válida.')
  }
  if (!env.SUPABASE_ANON_KEY || env.SUPABASE_ANON_KEY.length < 20) {
    throw new Error('SUPABASE_ANON_KEY debe estar configurada.')
  }
  return true
}
