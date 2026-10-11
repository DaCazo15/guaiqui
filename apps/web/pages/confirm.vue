<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, navigateTo } from '#imports'
import { useSupabaseClient } from '#imports'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const supabase = useSupabaseClient()
const authStore = useAuthStore()

const status = ref<'verifying' | 'error' | 'success'>('verifying')
const errorMessage = ref('')
const emailForResend = ref('')
const isResending = ref(false)
const resendSuccess = ref(false)
const resendError = ref('')

onMounted(async () => {
  // 1. Verificar si la URL trae parámetros de error en query o hash fragment
  let errorParam = (route.query.error || route.query.error_description) as string | undefined
  let errorCode = (route.query.error_code) as string | undefined

  if (!errorParam && typeof window !== 'undefined' && window.location.hash) {
    const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''))
    errorParam = hashParams.get('error_description') || hashParams.get('error') || undefined
    errorCode = hashParams.get('error_code') || undefined
  }

  if (errorParam || errorCode) {
    status.value = 'error'
    if (errorCode === 'otp_expired' || errorParam?.toLowerCase().includes('expired')) {
      errorMessage.value = 'El enlace de confirmación ha expirado o ya fue utilizado.'
    } else {
      errorMessage.value = errorParam || 'El enlace de verificación no es válido.'
    }
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
    return
  }

  // 2. Si regresamos con código PKCE (?code=...), intercambiar por sesión
  const code = route.query.code
  if (code && typeof code === 'string') {
    try {
      const { error } = await supabase.auth.exchangeCodeForSession(code)
      if (error) {
        status.value = 'error'
        errorMessage.value = error.message?.toLowerCase().includes('expired')
          ? 'El enlace de confirmación ha expirado o ya fue utilizado.'
          : 'No se pudo validar el enlace de confirmación. Por favor, solicita uno nuevo.'
        await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
        return
      }
    } catch {
      status.value = 'error'
      errorMessage.value = 'El enlace de confirmación ha expirado o ya fue utilizado.'
      await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
      return
    }
  }

  // 3. Obtener usuario de la sesión activa
  const { data: userData } = await supabase.auth.getUser()
  const activeUser = userData?.user

  if (activeUser) {
    await authStore.fetchProfile(activeUser)

    if (authStore.isAuthenticated) {
      status.value = 'success'
      if (!authStore.isEmailVerified) {
        navigateTo('/verificar-correo')
      } else if (authStore.needsConsent) {
        navigateTo('/aceptar-terminos')
      } else {
        navigateTo('/app')
      }
      return
    }
  }

  // 4. Si no hay usuario y no vino código, redirigir al login
  if (!code) {
    navigateTo('/login')
  } else {
    status.value = 'error'
    errorMessage.value = 'No se encontró una sesión activa para este enlace. Por favor, solicita uno nuevo.'
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
  }
})

async function handleGoToLogin() {
  try {
    await authStore.logout()
  } catch {
    await supabase.auth.signOut({ scope: 'local' }).catch(() => {})
    if (typeof window !== 'undefined') {
      window.location.href = '/login'
    } else {
      await navigateTo('/login')
    }
  }
}

async function handleResendEmail() {
  if (!emailForResend.value || !emailForResend.value.includes('@')) {
    resendError.value = 'Por favor ingresa un correo electrónico válido.'
    return
  }

  isResending.value = true
  resendError.value = ''
  resendSuccess.value = false

  try {
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: emailForResend.value.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/confirm`,
      },
    })

    if (error) throw error
    resendSuccess.value = true
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Error al reenviar el correo.'
    resendError.value = msg
  } finally {
    isResending.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-guaiqui-surface text-guaiqui-text px-4 py-12">
    <!-- Estado: Verificando -->
    <div v-if="status === 'verifying'" class="text-center space-y-4 max-w-sm">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary text-3xl shadow-guaiqui-sm">
        <i class="bi bi-arrow-repeat animate-spin"></i>
      </div>
      <h2 class="text-xl font-display font-bold uppercase tracking-wider text-guaiqui-text">Verificando enlace</h2>
      <p class="text-guaiqui-text-muted text-sm font-medium">Validando tu acceso con la plataforma...</p>
    </div>

    <!-- Estado: Error / Enlace expirado o usado -->
    <div v-else-if="status === 'error'" class="w-full max-w-md bg-white border border-guaiqui-border rounded-2xl p-6 sm:p-8 shadow-guaiqui-md space-y-6 text-center">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-50 text-red-600 text-3xl mx-auto">
        <i class="bi bi-exclamation-triangle-fill"></i>
      </div>

      <div class="space-y-2">
        <h2 class="text-2xl font-display font-bold uppercase tracking-wider text-guaiqui-text">Enlace no válido</h2>
        <p class="text-guaiqui-text-muted text-sm leading-relaxed">
          {{ errorMessage }}
        </p>
      </div>

      <!-- Formulario para reenviar enlace -->
      <div class="border-t border-guaiqui-border pt-6 space-y-4 text-left">
        <label for="resend-email" class="block text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted">
          Reenviar enlace de confirmación
        </label>
        <div class="space-y-2">
          <input
            id="resend-email"
            v-model="emailForResend"
            type="email"
            placeholder="tu-correo@ejemplo.com"
            class="w-full px-4 py-2.5 rounded-lg border border-guaiqui-border bg-guaiqui-surface text-guaiqui-text text-sm focus:outline-none focus:ring-2 focus:ring-guaiqui-primary"
            :disabled="isResending"
          />
          <button
            type="button"
            class="w-full py-2.5 px-4 rounded-lg bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-sm tracking-wide transition-colors flex items-center justify-center gap-2"
            :disabled="isResending"
            @click="handleResendEmail"
          >
            <i v-if="isResending" class="bi bi-arrow-repeat animate-spin"></i>
            <i v-else class="bi bi-envelope-fill"></i>
            <span>{{ isResending ? 'Enviando...' : 'Reenviar enlace' }}</span>
          </button>
        </div>

        <div v-if="resendSuccess" class="p-3 bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs rounded-lg flex items-start gap-2">
          <i class="bi bi-check-circle-fill text-sm shrink-0 mt-0.5"></i>
          <span>Enlace enviado. Revisa tu bandeja de entrada o carpeta de spam.</span>
        </div>

        <div v-if="resendError" class="p-3 bg-red-50 border border-red-200 text-red-600 text-xs rounded-lg flex items-start gap-2">
          <i class="bi bi-x-circle-fill text-sm shrink-0 mt-0.5"></i>
          <span>{{ resendError }}</span>
        </div>
      </div>

      <!-- Botón para ir al login -->
      <div class="pt-2">
        <button
          type="button"
          class="w-full py-2.5 px-4 rounded-lg border border-guaiqui-border hover:bg-guaiqui-surface text-guaiqui-text font-bold text-sm tracking-wide transition-colors flex items-center justify-center gap-2 cursor-pointer"
          @click="handleGoToLogin"
        >
          <i class="bi bi-box-arrow-in-right"></i>
          <span>Ir a Iniciar Sesión</span>
        </button>
      </div>
    </div>
  </div>
</template>
