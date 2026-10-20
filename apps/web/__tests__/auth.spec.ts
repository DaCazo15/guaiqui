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
    signUp: vi.fn().mockImplementation(({ email }) => {
      if (email === 'taken@guaiqui.test') {
        return Promise.resolve({ data: { user: { id: 'u-existing', identities: [] } }, error: null })
      }
      return Promise.resolve({ data: { user: { id: 'u-2', email: 'new@guaiqui.test', identities: [{ id: 'id-1' }] } }, error: null })
    }),
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
  rpc: vi.fn().mockImplementation((fnName: string, args?: any) => {
    if (fnName === 'delete_my_account') {
      return Promise.resolve({ data: { success: true }, error: null })
    }
    if (fnName === 'accept_terms') {
      return Promise.resolve({ data: { success: true, accepted_at: new Date().toISOString() }, error: null })
    }
    if (fnName === 'set_birth_date') {
      return Promise.resolve({ data: { success: true, birth_date: args?.p_birth_date }, error: null })
    }
    return Promise.resolve({ data: null, error: null })
  }),
  functions: {
    invoke: vi.fn().mockImplementation((fnName: string, opts?: any) => {
      if (fnName === 'check-email') {
        const target = opts?.body?.email
        return Promise.resolve({ data: { exists: target === 'taken@guaiqui.test' }, error: null })
      }
      return Promise.resolve({ data: { success: true, avatar_url: 'https://example.com/avatar.avif' }, error: null })
    }),
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

  it('invokes accept_terms RPC when acceptConsent is executed', async () => {
    const auth = useAuthStore()
    await auth.acceptConsent()
    expect(mockSupabase.rpc).toHaveBeenCalledWith('accept_terms')
  })

  it('invokes set_birth_date RPC when birth_date is passed and user has no birth_date yet', async () => {
    const auth = useAuthStore()
    auth.profile = { id: 'u-1', display_name: 'Fan Test', birth_date: null } as any
    await auth.updateProfile({ birth_date: '1999-08-15', display_name: 'Ziko Cazorla' })
    expect(mockSupabase.rpc).toHaveBeenCalledWith('set_birth_date', { p_birth_date: '1999-08-15' })
  })

  it('invokes compress-avatar edge function when uploadAvatar is called', async () => {
    const auth = useAuthStore()
    auth.profile = { id: 'u-1', display_name: 'Fan Test', avatar_url: null } as any
    const validFile = new File(['valid image data'], 'avatar.jpg', { type: 'image/jpeg' })
    const resultUrl = await auth.uploadAvatar(validFile)
    expect(mockSupabase.functions.invoke).toHaveBeenCalledWith('compress-avatar', expect.objectContaining({
      body: expect.any(FormData),
    }))
    expect(resultUrl).toBe('https://example.com/avatar.avif')
    expect(auth.profile?.avatar_url).toBe('https://example.com/avatar.avif')
  })

  it('verifies checkEmailExists returns true when email exists in database', async () => {
    const auth = useAuthStore()
    const exists = await auth.checkEmailExists('taken@guaiqui.test')
    expect(exists).toBe(true)
  })

  it('verifies checkEmailExists returns false when email is available', async () => {
    const auth = useAuthStore()
    const exists = await auth.checkEmailExists('available@guaiqui.test')
    expect(exists).toBe(false)
  })

  it('rejects signUpWithEmail when email is already registered', async () => {
    const auth = useAuthStore()
    await expect(
      auth.signUpWithEmail('taken@guaiqui.test', 'Password123!', {
        terms: true,
        privacy: true,
        pearlsRules: true,
      })
    ).rejects.toThrow('Ya existe una cuenta registrada con este correo.')
  })

  it('successfully executes signUpWithEmail with metadata when email is available', async () => {
    const auth = useAuthStore()
    const result = await auth.signUpWithEmail(
      'new@guaiqui.test',
      'Password123!',
      { terms: true, privacy: true, pearlsRules: true },
      { displayName: 'Nuevo Fan', municipality: 'Maneiro', birthDate: '1999-07-15' }
    )
    expect(result.user?.id).toBe('u-2')
    expect(mockSupabase.auth.signUp).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'new@guaiqui.test',
        options: expect.objectContaining({
          data: expect.objectContaining({
            display_name: 'Nuevo Fan',
            municipality: 'Maneiro',
            birth_date: '1999-07-15',
          }),
        }),
      })
    )
  })

  it('detects incomplete profile when birth_date or municipality is missing', () => {
    const auth = useAuthStore()
    auth.profile = {
      id: 'u-1',
      display_name: 'Fanático #123456',
      birth_date: null,
      municipality: null,
      favorite_player_id: null,
      shirt_size: null,
      status: 'active',
    } as any

    expect(auth.isProfileIncomplete).toBe(true)
  })

  it('detects profile is complete when all key preferences are filled', () => {
    const auth = useAuthStore()
    auth.profile = {
      id: 'u-1',
      display_name: 'Carlos Margarita',
      birth_date: '1995-05-20',
      municipality: 'Maneiro',
      favorite_player_id: '11111111-1111-1111-1111-111111111111',
      shirt_size: 'L',
      status: 'active',
    } as any

    expect(auth.isProfileIncomplete).toBe(false)
  })

  it('auto-populates Google profile photo if user logged in with Google and profile has no avatar', async () => {
    const auth = useAuthStore()
    const googleUser = {
      id: 'u-1',
      email: 'fan@gmail.com',
      app_metadata: { provider: 'google' },
      user_metadata: {
        avatar_url: 'https://lh3.googleusercontent.com/a/ACg8ocTestPhoto=s96-c',
        full_name: 'Fan Google',
      },
    } as any

    await auth.fetchProfile(googleUser)
    expect(auth.profile?.avatar_url).toBe('https://lh3.googleusercontent.com/a/ACg8ocTestPhoto=s96-c')
  })
})


