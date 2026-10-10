import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

export interface StaffProfile {
  user_id: string
  role: 'staff' | 'admin'
  active: boolean
  display_name?: string
  avatar_url?: string
}

const IDLE_TIMEOUT_MS = 30 * 60 * 1000 // 30 minutos

export const useAuthStore = defineStore('auth', () => {
  const user = ref<any>(null)
  const staffMember = ref<StaffProfile | null>(null)
  const isLoading = ref(true)
  const isInitialized = ref(false)
  const authError = ref<string | null>(null)
  
  const lastActivityTime = ref<number>(Date.now())
  let idleTimer: number | null = null

  const isAuthenticated = computed(() => !!user.value && !!staffMember.value && staffMember.value.active)
  const isAdmin = computed(() => isAuthenticated.value && staffMember.value?.role === 'admin')

  const resetIdleTimer = () => {
    lastActivityTime.value = Date.now()
  }

  const startIdleMonitoring = () => {
    stopIdleMonitoring()
    lastActivityTime.value = Date.now()

    if (typeof window !== 'undefined') {
      const events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart']
      events.forEach(evt => window.addEventListener(evt, resetIdleTimer, { passive: true }))

      idleTimer = window.setInterval(async () => {
        if (user.value && Date.now() - lastActivityTime.value >= IDLE_TIMEOUT_MS) {
          console.warn('Sesión de staff cerrada por inactividad de 30 minutos.')
          await signOut('Sesión cerrada automáticamente por 30 minutos de inactividad.')
          if (window.location.pathname !== '/login') {
            window.location.href = '/login'
          }
        }
      }, 15000)
    }
  }

  const stopIdleMonitoring = () => {
    if (idleTimer) {
      clearInterval(idleTimer)
      idleTimer = null
    }
    if (typeof window !== 'undefined') {
      const events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart']
      events.forEach(evt => window.removeEventListener(evt, resetIdleTimer))
    }
  }

  const fetchStaffData = async (uid: string): Promise<boolean> => {
    try {
      const { data: staff, error: staffErr } = await supabase
        .from('staff_members')
        .select('user_id, role, active')
        .eq('user_id', uid)
        .single()

      if (staffErr || !staff || !staff.active) {
        staffMember.value = null
        authError.value = 'Acceso no autorizado: Esta cuenta no posee permisos de personal de taquilla o administración activos.'
        return false
      }

      // Profile metadata if available
      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name, avatar_url')
        .eq('id', uid)
        .maybeSingle()

      staffMember.value = {
        ...staff,
        display_name: profile?.display_name || 'Personal de Taquilla',
        avatar_url: profile?.avatar_url || undefined
      }

      authError.value = null
      return true
    } catch (err: any) {
      console.error('Error fetching staff member profile:', err)
      staffMember.value = null
      authError.value = 'Error al verificar permisos de personal.'
      return false
    }
  }

  const checkAuth = async (force = false): Promise<boolean> => {
    if (isInitialized.value && !force) {
      return isAuthenticated.value
    }

    isLoading.value = true
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session || !session.user) {
        user.value = null
        staffMember.value = null
        stopIdleMonitoring()
        return false
      }

      user.value = session.user
      const isStaffValid = await fetchStaffData(session.user.id)
      if (isStaffValid) {
        startIdleMonitoring()
        return true
      } else {
        stopIdleMonitoring()
        return false
      }
    } catch (err: any) {
      console.error('Error durante checkAuth:', err)
      user.value = null
      staffMember.value = null
      stopIdleMonitoring()
      return false
    } finally {
      isInitialized.value = true
      isLoading.value = false
    }
  }

  const signIn = async (email: string, password: string): Promise<{ success: boolean; message?: string }> => {
    isLoading.value = true
    authError.value = null
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) {
        authError.value = 'Credenciales inválidas. Por favor verifique su correo y contraseña.'
        return { success: false, message: authError.value }
      }

      if (!data.user) {
        authError.value = 'Error de autenticación.'
        return { success: false, message: authError.value }
      }

      user.value = data.user
      const isStaffValid = await fetchStaffData(data.user.id)

      if (!isStaffValid) {
        await supabase.auth.signOut()
        user.value = null
        return { success: false, message: authError.value || 'Acceso no autorizado.' }
      }

      startIdleMonitoring()
      return { success: true }
    } catch (err: any) {
      authError.value = err.message || 'Error al iniciar sesión.'
      return { success: false, message: authError.value || undefined }
    } finally {
      isLoading.value = false
    }
  }

  const signOut = async (reason?: string) => {
    stopIdleMonitoring()
    try {
      await supabase.auth.signOut({ scope: 'local' })
    } catch (err) {
      console.warn('Error al cerrar sesión en Supabase:', err)
    } finally {
      user.value = null
      staffMember.value = null
      authError.value = reason || null
    }
  }

  return {
    user,
    staffMember,
    isLoading,
    isInitialized,
    authError,
    isAuthenticated,
    isAdmin,
    checkAuth,
    signIn,
    signOut,
    stopIdleMonitoring
  }
})
