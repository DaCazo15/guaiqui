import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User } from '@supabase/supabase-js'
import type { Profile, Wallet } from '@guaiqui/shared'
import { CURRENT_LEGAL_VERSIONS } from '@guaiqui/shared'
import { translateAuthError } from '../utils/authErrors'
import { clearClientAuthSession } from '../utils/sessionCleanup'
import { uploadAvatarToStorage, uploadCoverToStorage } from '../utils/profileStorage'

export type ProfileRow = Profile
export type WalletRow = Wallet

export const useAuthStore = defineStore('auth', () => {
  const supabase = useSupabaseClient()
  const supabaseUser = useSupabaseUser()
  const sessionUser = ref<User | null>(null)
  const explicitLoggedOut = ref(false)

  const profile = ref<ProfileRow | null>(null)
  const wallet = ref<WalletRow | null>(null)
  const isLoading = ref(false)
  const errorMessage = ref<string | null>(null)

  const user = computed<User | null>(() => {
    if (explicitLoggedOut.value) return null
    const current = sessionUser.value || (supabaseUser.value as unknown as User | null)
    if (!current) return null
    const currentObj = current as { id?: string; sub?: string }
    const id = current.id || currentObj.sub
    if (!current.id && id) {
      return { ...current, id }
    }
    return current
  })
  const isAuthenticated = computed(() => !!user.value)
  const isEmailVerified = computed(() => {
    if (!user.value) return false
    const isOAuth =
      user.value.app_metadata?.provider === 'google' ||
      (Array.isArray(user.value.app_metadata?.providers) &&
        user.value.app_metadata.providers.includes('google'))
    return (
      !!user.value.email_confirmed_at ||
      !!user.value.confirmed_at ||
      isOAuth ||
      (isAuthenticated.value && !!profile.value)
    )
  })
  
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
    } catch {
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

  const isProfileIncomplete = computed(() => {
    if (!profile.value) return false
    return (
      !profile.value.birth_date ||
      !profile.value.municipality ||
      !profile.value.favorite_player_id ||
      !profile.value.shirt_size ||
      Boolean(profile.value.display_name?.startsWith('Fanático #'))
    )
  })

  async function fetchProfile(overrideUser?: User | null) {
    if (overrideUser) {
      sessionUser.value = overrideUser
    } else if (!sessionUser.value && typeof supabase.auth?.getUser === 'function') {
      try {
        const { data: userData } = await supabase.auth.getUser()
        if (userData?.user) {
          sessionUser.value = userData.user
        }
      } catch {
        // Fallback to supabaseUser state if network or offline
      }
    }

    const targetUser = overrideUser || user.value
    const targetUserObj = targetUser as { id?: string; sub?: string } | null | undefined
    const targetId = targetUser?.id || targetUserObj?.sub
    if (!targetId || typeof targetId !== 'string' || targetId === 'undefined') {
      profile.value = null
      wallet.value = null
      return
    }

    try {
      isLoading.value = true
      errorMessage.value = null

      const { data: initialProf, error: profErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', targetId)
        .maybeSingle()

      if (profErr) throw profErr
      let prof = initialProf

      if (!prof) {
        // Fallback: trigger might have failed or been bypassed, ensure profile exists
        try {
          await supabase.rpc('ensure_profile')
          const { data: fallbackProf } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', targetId)
            .maybeSingle()
          prof = fallbackProf
        } catch {
          // ensure_profile RPC could be missing or failed gracefully
        }
      }

      // Auto-populate Google OAuth profile photo if not yet set or if updated on Google
      if (prof) {
        const meta = targetUser?.user_metadata
        let googlePhoto =
          meta?.avatar_url ||
          meta?.picture ||
          (targetUser as any)?.identities?.find((i: any) => i?.provider === 'google')?.identity_data?.avatar_url ||
          (targetUser as any)?.identities?.find((i: any) => i?.provider === 'google')?.identity_data?.picture

        const currentAvatar = prof.avatar_url ? prof.avatar_url.trim() : ''
        if (googlePhoto && typeof googlePhoto === 'string') {
          const isGoogleAvatar = currentAvatar.includes('googleusercontent.com')
          if (!currentAvatar || (isGoogleAvatar && currentAvatar !== googlePhoto)) {
            prof.avatar_url = googlePhoto
            supabase
              .from('profiles')
              .update({ avatar_url: googlePhoto, updated_at: new Date().toISOString() })
              .eq('id', targetId)
              .then(
                () => {},
                (err: any) => console.warn('Could not auto-sync Google avatar:', err)
              )
          }
        }
      }

      profile.value = prof

      const { data: wal, error: walErr } = await supabase
        .from('wallets')
        .select('*')
        .eq('fan_id', targetId)
        .maybeSingle()

      if (walErr) throw walErr
      wallet.value = wal
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Error al cargar perfil'
      console.error('Error al cargar perfil:', err)
      errorMessage.value = msg
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

  async function checkEmailExists(email: string): Promise<boolean> {
    const cleanEmail = email?.trim().toLowerCase()
    if (!cleanEmail) return false
    try {
      const { data, error } = await supabase.functions.invoke('check-email', {
        body: { email: cleanEmail },
      })
      if (error) {
        console.warn('Error checking email exists via Edge Function:', error)
        return false
      }
      return Boolean(data?.exists)
    } catch (err) {
      console.warn('Error invoking check-email function:', err)
      return false
    }
  }

  async function signUpWithEmail(
    email: string,
    pass: string,
    consent: {
      terms: boolean
      privacy: boolean
      pearlsRules: boolean
    },
    profileData?: {
      displayName?: string
      municipality?: string
      birthDate?: string | null
      gender?: string | null
      favoritePlayerId?: string | null
      shirtSize?: string | null
      referralSource?: string | null
    }
  ) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const cleanEmail = email.trim().toLowerCase()

      // Double-check email availability before proceeding
      const exists = await checkEmailExists(cleanEmail)
      if (exists) {
        throw new Error('Ya existe una cuenta registrada con este correo. Por favor inicia sesión o utiliza otro correo.')
      }

      const now = new Date().toISOString()
      const metadata = {
        display_name: profileData?.displayName || undefined,
        municipality: profileData?.municipality || undefined,
        birth_date: profileData?.birthDate || undefined,
        gender: profileData?.gender || undefined,
        favorite_player_id: profileData?.favoritePlayerId || undefined,
        shirt_size: profileData?.shirtSize || undefined,
        referral_source: profileData?.referralSource || undefined,
        terms_accepted_at: consent.terms ? now : null,
        terms_version: CURRENT_LEGAL_VERSIONS.terms,
        privacy_accepted_at: consent.privacy ? now : null,
        privacy_version: CURRENT_LEGAL_VERSIONS.privacy,
        pearls_rules_accepted_at: consent.pearlsRules ? now : null,
        pearls_rules_version: CURRENT_LEGAL_VERSIONS.pearls_rules,
      }

      const { data, error } = await supabase.auth.signUp({
        email: cleanEmail,
        password: pass,
        options: {
          emailRedirectTo: `${window.location.origin}/confirm`,
          data: metadata,
        },
      })
      if (error) throw error

      // If Supabase email enumeration protection returns empty identities, user already exists
      if (data?.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) {
        throw new Error('Ya existe una cuenta registrada con este correo. Por favor inicia sesión o utiliza otro correo.')
      }

      if (data?.user?.id) {
        sessionUser.value = data.user
        await fetchProfile(data.user)
      }

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
    if (!user.value?.id) return
    isLoading.value = true
    errorMessage.value = null
    try {
      await fetchActiveLegalVersions()
      const { error } = await supabase.rpc('accept_terms')
      if (error) throw error
      await fetchProfile()
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function setBirthDate(birthDate: string) {
    if (!user.value?.id) return
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.rpc('set_birth_date', {
        p_birth_date: birthDate,
      })
      if (error) throw error
      await fetchProfile()
      return data
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function updateProfile(updates: Partial<ProfileRow>) {
    if (!user.value?.id) return
    isLoading.value = true
    errorMessage.value = null
    try {
      // 1. If birth_date is provided and user has no birth_date yet, register via set_birth_date RPC
      if (updates.birth_date && !profile.value?.birth_date) {
        const { error: birthErr } = await supabase.rpc('set_birth_date', {
          p_birth_date: updates.birth_date,
        })
        if (birthErr) throw birthErr
      }

      // 2. Filter payload strictly to allowed updatable columns with GRANT UPDATE
      const allowedKeys = [
        'display_name',
        'avatar_url',
        'municipality',
        'gender',
        'favorite_player_id',
        'shirt_size',
        'referral_source',
        'notification_prefs',
        'cover_url',
      ] as const

      const safeUpdates: Record<string, any> = {}
      for (const key of allowedKeys) {
        if (key in updates && (updates as any)[key] !== undefined) {
          safeUpdates[key] = (updates as any)[key]
        }
      }

      if (Object.keys(safeUpdates).length > 0) {
        const { error } = await supabase
          .from('profiles')
          .update(safeUpdates)
          .eq('id', user.value.id)

        if (error) throw error

        if (profile.value) {
          Object.assign(profile.value, safeUpdates)
        }
      }

      await fetchProfile()
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function uploadAvatar(file: File): Promise<string> {
    if (!user.value) throw new Error('Usuario no autenticado')

    isLoading.value = true
    errorMessage.value = null

    try {
      const avatarUrl = await uploadAvatarToStorage(supabase, user.value.id, file)
      await updateProfile({ avatar_url: avatarUrl })
      if (profile.value) {
        profile.value.avatar_url = avatarUrl
      }
      return avatarUrl
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al subir la imagen'
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function uploadCover(file: File): Promise<string> {
    if (!user.value) throw new Error('Usuario no autenticado')

    isLoading.value = true
    errorMessage.value = null

    try {
      const coverUrl = await uploadCoverToStorage(supabase, user.value.id, file)
      await updateProfile({ cover_url: coverUrl })
      if (profile.value) {
        profile.value.cover_url = coverUrl
      }
      return coverUrl
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al subir la foto de portada'
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
      if (error) {
        console.warn('Opaque password reset response (suppressed error):', error.message)
      }
    } catch (err: any) {
      console.warn('Opaque password reset response (suppressed exception):', err)
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
      await clearClientAuthSession(supabase)
    } finally {
      profile.value = null
      wallet.value = null
      sessionUser.value = null
      isLoading.value = false

      if (typeof window !== 'undefined') {
        window.location.href = '/login'
      } else {
        await navigateTo('/login')
      }
    }
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
    isProfileIncomplete,
    fetchProfile,
    fetchActiveLegalVersions,
    checkEmailExists,
    loginWithEmail,
    signUpWithEmail,
    loginWithGoogle,
    acceptConsent,
    setBirthDate,
    updateProfile,
    uploadAvatar,
    uploadCover,
    requestPasswordReset,
    updatePassword,
    resendVerificationEmail,
    deleteAccount,
    logout,
  }
})
