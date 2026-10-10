import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { supabase } from '../src/lib/supabase'
import { useAuthStore } from '../src/stores/auth'

describe('Admin Auth Store - signOut resilience', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.restoreAllMocks()
  })

  it('clears user and staffMember in finally block even if supabase.auth.signOut rejects with a network error', async () => {
    const authStore = useAuthStore()

    // Mock initial logged-in state
    authStore.user = { id: 'user-admin-1', email: 'admin@guaiqueries.com' }
    authStore.staffMember = {
      user_id: 'user-admin-1',
      role: 'admin',
      active: true,
      display_name: 'Admin User'
    }

    expect(authStore.isAuthenticated).toBe(true)

    // Mock supabase.auth.signOut to reject with a network error
    vi.spyOn(supabase.auth, 'signOut').mockRejectedValueOnce(new Error('Network disconnected'))

    // Call signOut with reason
    await authStore.signOut('Error de conexión al salir')

    // Verify state was wiped regardless of network failure
    expect(authStore.user).toBeNull()
    expect(authStore.staffMember).toBeNull()
    expect(authStore.authError).toBe('Error de conexión al salir')
    expect(authStore.isAuthenticated).toBe(false)
  })

  it('clears user and staffMember on normal signOut', async () => {
    const authStore = useAuthStore()

    authStore.user = { id: 'user-staff-1', email: 'staff@guaiqueries.com' }
    authStore.staffMember = {
      user_id: 'user-staff-1',
      role: 'staff',
      active: true,
      display_name: 'Staff User'
    }

    vi.spyOn(supabase.auth, 'signOut').mockResolvedValueOnce({ error: null })

    await authStore.signOut('Sesión cerrada correctamente.')

    expect(authStore.user).toBeNull()
    expect(authStore.staffMember).toBeNull()
    expect(authStore.authError).toBe('Sesión cerrada correctamente.')
    expect(authStore.isAuthenticated).toBe(false)
  })
})
