import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Database } from '@guaiqui/shared'
import { CURRENT_LEGAL_VERSIONS } from '@guaiqui/shared'

export type ProfileRow = Database['public']['Tables']['profiles']['Row']
export type WalletRow = Database['public']['Tables']['wallets']['Row']

export const useAuthStore = defineStore('auth', () => {
  const supabase = useSupabaseClient<Database>()
  const supabaseUser = useSupabaseUser()
  const sessionUser = ref<any>(null)
  const explicitLoggedOut = ref(false)

  const profile = ref<ProfileRow | null>(null)
  const wallet = ref<WalletRow | null>(null)
  const isLoading = ref(false)
  const errorMessage = ref<string | null>(null)

  const user = computed(() => explicitLoggedOut.value ? null : (sessionUser.value || supabaseUser.value))
  const isAuthenticated = computed(() => !!user.value)
  const isEmailVerified = computed(() => !!user.value?.email_confirmed_at || !!user.value?.confirmed_at || (isAuthenticated.value && !!profile.value) || isAuthenticated.value)
  
  const activeLegalVersions = ref<Record<string, string>>({
    terminos: 'v1.0',
    privacidad: 'v1.0',
    perlitas: 'v1.0',
    canjes: 'v1.0',
  })

  async function fetchActiveLegalVersions() {
    try {
      const { data } = await supabase.rpc('get_active_legal_versions')
      if (data && typeof data === 'object') {
        activeLegalVersions.value = data as Record<string, string>
      }
    } catch (_err) {
      // Fallback to default v1.0
    }
  }

  const needsConsent = computed(() => {
    if (!isAuthenticated.value || !isEmailVerified.value || !profile.value) return false
    const activeT = activeLegalVersions.value.terminos || 'v1.0'
    const activeP = activeLegalVersions.value.privacidad || 'v1.0'
    const activeR = activeLegalVersions.value.perlitas || 'v1.0'

    const userT = profile.value.terms_version || 'v1.0'
    const userP = profile.value.privacy_version || 'v1.0'
    const userR = profile.value.pearls_rules_version || 'v1.0'

    return (
      !profile.value.terms_accepted_at ||
      userT !== activeT ||
      !profile.value.privacy_accepted_at ||
      userP !== activeP ||
      !profile.value.pearls_rules_accepted_at ||
      userR !== activeR
    )
  })

  const isActive = computed(() => profile.value?.status === 'active')

  async function fetchProfile(overrideUser?: any) {
    const targetUser = overrideUser || user.value
    if (!targetUser || !targetUser.id) {
      profile.value = null
      wallet.value = null
      return
    }

    try {
      isLoading.value = true
      errorMessage.value = null

      let { data: prof, error: profErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', targetUser.id)
        .maybeSingle()

      if (profErr) throw profErr

      if (!prof) {
        // Fallback: trigger might have failed or been bypassed, ensure profile exists
        await supabase.rpc('ensure_profile')
        const { data: fallbackProf } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', targetUser.id)
          .maybeSingle()
        prof = fallbackProf
      }

      profile.value = prof

      const { data: wal, error: walErr } = await supabase
        .from('wallets')
        .select('*')
        .eq('fan_id', targetUser.id)
        .maybeSingle()

      if (walErr) throw walErr
      wallet.value = wal
    } catch (err: any) {
      console.error('Error al cargar perfil:', err)
      errorMessage.value = err.message || 'Error al cargar perfil'
    } finally {
      isLoading.value = false
    }
  }

  async function loginWithEmail(email: string, pass: string) {
    explicitLoggedOut.value = false
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password: pass,
      })
      if (error) throw error
      if (data.user) {
        sessionUser.value = data.user
      }
      await fetchProfile(data.user)
      return data
    } catch (err: any) {
      errorMessage.value = translateAuthError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function signUpWithEmail(
    email: string,
    pass: string,
    consent: {
      terms: boolean
      privacy: boolean
      pearlsRules: boolean
    }
  ) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password: pass,
        options: {
          emailRedirectTo: `${window.location.origin}/confirm`,
        },
      })
      if (error) throw error

      if (data.user) {
        // Save initial consent in profile
        const now = new Date().toISOString()
        await supabase
          .from('profiles')
          .update({
            terms_accepted_at: consent.terms ? now : null,
            terms_version: CURRENT_LEGAL_VERSIONS.terms,
            privacy_accepted_at: consent.privacy ? now : null,
            privacy_version: CURRENT_LEGAL_VERSIONS.privacy,
            pearls_rules_accepted_at: consent.pearlsRules ? now : null,
            pearls_rules_version: CURRENT_LEGAL_VERSIONS.pearls_rules,
          })
          .eq('id', data.user.id)
      }

      await fetchProfile()
      return data
    } catch (err: any) {
      errorMessage.value = translateAuthError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function loginWithGoogle() {
    errorMessage.value = null
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/confirm`,
      },
    })
    if (error) {
      errorMessage.value = translateAuthError(error.message)
      throw error
    }
  }

  async function acceptConsent() {
    if (!user.value) return
    isLoading.value = true
    errorMessage.value = null
    try {
      await fetchActiveLegalVersions()
      const now = new Date().toISOString()
      const { error } = await supabase
        .from('profiles')
        .update({
          terms_accepted_at: now,
          terms_version: activeLegalVersions.value.terminos || 'v1.0',
          privacy_accepted_at: now,
          privacy_version: activeLegalVersions.value.privacidad || 'v1.0',
          pearls_rules_accepted_at: now,
          pearls_rules_version: activeLegalVersions.value.perlitas || 'v1.0',
        })
        .eq('id', user.value.id)

      if (error) throw error
      await fetchProfile()
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function updateProfile(updates: Partial<ProfileRow>) {
    if (!user.value) return
    isLoading.value = true
    errorMessage.value = null
    try {
      const { error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', user.value.id)

      if (error) throw error
      await fetchProfile()
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function uploadAvatar(file: File) {
    if (!user.value) throw new Error('Usuario no autenticado')

    // Client-side validations
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp']
    if (!allowedTypes.includes(file.type)) {
      throw new Error('Formato no permitido. Usa JPG, PNG o WebP.')
    }

    const maxSize = 2 * 1024 * 1024 // 2MB
    if (file.size > maxSize) {
      throw new Error('El archivo excede el tamaño máximo permitido de 2 MB.')
    }

    isLoading.value = true
    errorMessage.value = null

    try {
      const ext = file.name.split('.').pop()
      const path = `${user.value.id}/${crypto.randomUUID()}.${ext}`

      const { error: uploadErr } = await supabase.storage
        .from('avatars')
        .upload(path, file, { upsert: true })

      if (uploadErr) throw uploadErr

      const { data: publicUrlData } = supabase.storage
        .from('avatars')
        .getPublicUrl(path)

      const avatarUrl = publicUrlData.publicUrl
      await updateProfile({ avatar_url: avatarUrl })
      return avatarUrl
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al subir la imagen'
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function requestPasswordReset(email: string) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/restablecer-contrasena`,
      })
      if (error) throw error
    } catch (err: any) {
      errorMessage.value = translateAuthError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function updatePassword(newPass: string) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { error } = await supabase.auth.updateUser({ password: newPass })
      if (error) throw error
    } catch (err: any) {
      errorMessage.value = translateAuthError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function resendVerificationEmail(email: string) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { error } = await supabase.auth.resend({
        type: 'signup',
        email,
        options: {
          emailRedirectTo: `${window.location.origin}/confirm`,
        },
      })
      if (error) throw error
    } catch (err: any) {
      errorMessage.value = translateAuthError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function deleteAccount() {
    isLoading.value = true
    errorMessage.value = null
    try {
      // Call Edge Function or RPC fallback
      const { data, error } = await supabase.functions.invoke('delete-account')

      if (error) {
        throw new Error(error.message || 'Error al eliminar la cuenta')
      }

      if (data?.error) {
        throw new Error(data.error)
      }

      await logout()
      return data
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function logout() {
    explicitLoggedOut.value = true
    isLoading.value = true
    try {
      profile.value = null
      wallet.value = null
      sessionUser.value = null

      if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
        try {
          const registration = await navigator.serviceWorker.ready
          const subscription = await registration.pushManager.getSubscription()
          if (subscription) {
            await supabase.rpc('unregister_push_subscription', { p_endpoint: subscription.endpoint })
            await subscription.unsubscribe()
          }
        } catch (_swErr) {
          // Ignore SW cleanup errors during logout
        }
      }

      await supabase.auth.signOut().catch((err) => console.warn('SignOut warning:', err))

      if (typeof window !== 'undefined') {
        localStorage.clear()
        sessionStorage.clear()

        // Clear all authentication cookies
        document.cookie.split(';').forEach((c) => {
          const eqPos = c.indexOf('=')
          const name = eqPos > -1 ? c.substring(0, eqPos).trim() : c.trim()
          if (name.startsWith('sb-') || name.includes('supabase') || name.includes('token') || name.includes('auth')) {
            document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`
            document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${window.location.hostname};`
          }
        })

        window.location.href = '/login'
      } else {
        await navigateTo('/login')
      }
    } catch (err: any) {
      console.warn('Logout catch error:', err)
      if (typeof window !== 'undefined') {
        window.location.href = '/login'
      }
    } finally {
      isLoading.value = false
    }
  }

  function translateAuthError(msg: string): string {
    if (!msg) return 'Ocurrió un error inesperado.'
    if (msg.includes('Invalid login credentials')) return 'Correo o contraseña incorrectos.'
    if (msg.includes('User already registered')) return 'Ya existe una cuenta registrada con este correo.'
    if (msg.includes('Password should be at least')) return 'La contraseña debe tener al menos 8 caracteres.'
    if (msg.includes('Email rate limit exceeded')) return 'Límite de envíos excedido. Espera unos minutos e intentalo de nuevo.'
    return msg
  }

  return {
    user,
    profile,
    wallet,
    isLoading,
    errorMessage,
    isAuthenticated,
    isEmailVerified,
    needsConsent,
    isActive,
    fetchProfile,
    fetchActiveLegalVersions,
    loginWithEmail,
    signUpWithEmail,
    loginWithGoogle,
    acceptConsent,
    updateProfile,
    uploadAvatar,
    requestPasswordReset,
    updatePassword,
    resendVerificationEmail,
    deleteAccount,
    logout,
  }
})
