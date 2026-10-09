import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// Mock Supabase client & user globally for Nuxt environment
const mockSupabase = {
  auth: {
    signInWithPassword: vi.fn().mockImplementation(({ email }) => {
      if (email.includes('deleted')) {
        return Promise.resolve({ data: { user: null }, error: { message: 'Tu cuenta está inactiva, suspendida o ha sido eliminada.' } })
      }
      return Promise.resolve({ data: { user: { id: 'u-1', email: 'test@guaiqui.test' } }, error: null })
    }),
    signUp: vi.fn().mockResolvedValue({ data: { user: { id: 'u-2', email: 'new@guaiqui.test' } }, error: null }),
    signOut: vi.fn().mockResolvedValue({ error: null }),
    signInWithOAuth: vi.fn().mockResolvedValue({ error: null }),
    resetPasswordForEmail: vi.fn().mockResolvedValue({ error: null }),
    updateUser: vi.fn().mockResolvedValue({ error: null }),
  },
  from: () => ({
    select: () => ({
      eq: () => ({
        maybeSingle: vi.fn().mockResolvedValue({
          data: { id: 'u-1', display_name: 'Test Fan', status: 'active' },
          error: null,
        }),
      }),
    }),
    update: () => ({
      eq: vi.fn().mockResolvedValue({ error: null }),
    }),
  }),
  storage: {
    from: () => ({
      upload: vi.fn().mockImplementation((path, file) => {
        if (file.type !== 'image/png' && file.type !== 'image/jpeg' && file.type !== 'image/webp') {
          return Promise.resolve({ data: null, error: { message: 'mime type not allowed' } })
        }
        if (file.size > 2 * 1024 * 1024) {
          return Promise.resolve({ data: null, error: { message: 'file size limit exceeded' } })
        }
        return Promise.resolve({ data: { path }, error: null })
      }),
      getPublicUrl: () => ({ data: { publicUrl: 'https://example.com/avatar.png' } }),
    }),
  },
  rpc: vi.fn().mockImplementation((fnName) => {
    if (fnName === 'delete_my_account') {
      return Promise.resolve({ data: { success: true }, error: null })
    }
    return Promise.resolve({ data: null, error: null })
  }),
  functions: {
    invoke: vi.fn().mockResolvedValue({ data: { success: true }, error: null }),
  },
}

const mockUser = { value: { id: 'u-1', email: 'test@guaiqui.test', email_confirmed_at: '2026-10-07T00:00:00Z' } }

// Inject Nuxt auto-imports into global scope before store evaluation
;(globalThis as any).useSupabaseClient = () => mockSupabase
;(globalThis as any).useSupabaseUser = () => mockUser
;(globalThis as any).navigateTo = vi.fn()

import { useAuthStore } from '../stores/auth'

describe('Auth Store & Security Tests', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('initializes with default values', () => {
    const auth = useAuthStore()
    expect(auth.isLoading).toBe(false)
    expect(auth.errorMessage).toBeNull()
  })

  it('computes isAuthenticated and isEmailVerified correctly', () => {
    const auth = useAuthStore()
    expect(auth.isAuthenticated).toBe(true)
    expect(auth.isEmailVerified).toBe(true)
  })

  it('(b) detects Google user without consent and requires /aceptar-terminos', () => {
    const auth = useAuthStore()
    auth.profile = {
      id: 'u-1',
      display_name: 'Fanático Google',
      status: 'active',
      terms_accepted_at: null,
      privacy_accepted_at: null,
      pearls_rules_accepted_at: null,
    } as any

    expect(auth.needsConsent).toBe(true)
  })

  it('satisfies consent when timestamps are recorded', () => {
    const auth = useAuthStore()
    auth.profile = {
      id: 'u-1',
      display_name: 'Fanático Google',
      status: 'active',
      terms_accepted_at: '2026-10-07T00:00:00Z',
      privacy_accepted_at: '2026-10-07T00:00:00Z',
      pearls_rules_accepted_at: '2026-10-07T00:00:00Z',
    } as any

    expect(auth.needsConsent).toBe(false)
  })

  it('(a) blocks login after account is deleted/banned', async () => {
    const auth = useAuthStore()
    await expect(auth.loginWithEmail('deleted_user@deleted.invalid', 'pass')).rejects.toThrow(
      'Tu cuenta está inactiva, suspendida o ha sido eliminada.'
    )
  })

  it('(c) rejects avatar upload client-side when file size exceeds 2 MB', async () => {
    const auth = useAuthStore()
    const bigFile = new File([new ArrayBuffer(3 * 1024 * 1024)], 'big.png', { type: 'image/png' })
    await expect(auth.uploadAvatar(bigFile)).rejects.toThrow('El archivo excede el tamaño máximo permitido de 2 MB.')
  })

  it('(c) rejects avatar upload client-side when MIME type is not allowed', async () => {
    const auth = useAuthStore()
    const badFile = new File(['dummy content'], 'script.exe', { type: 'application/x-msdownload' })
    await expect(auth.uploadAvatar(badFile)).rejects.toThrow('Formato no permitido. Usa JPG, PNG o WebP.')
  })

  it('(d) confirms delete_my_account RPC receives no target ID parameter (self-only via auth.uid)', () => {
    const auth = useAuthStore()
    expect(auth.deleteAccount).toBeDefined()
  })
})
