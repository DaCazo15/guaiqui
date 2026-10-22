<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const code = ref('')
const recoveryCode = ref('')
const useRecovery = ref(false)
const errorMsg = ref('')
const isSubmitting = ref(false)

const handleVerify = async () => {
  if (useRecovery.value) {
    if (!recoveryCode.value || recoveryCode.value.trim().length < 8) {
      errorMsg.value = 'Ingresa un código de recuperación válido.'
      return
    }

    isSubmitting.value = true
    errorMsg.value = ''

    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) throw new Error('Sesión no encontrada. Inicia sesión nuevamente.')

      const { data, error } = await supabase.functions.invoke('use-recovery-code', {
        body: { code: recoveryCode.value.trim() }
      })

      if (error || data?.error) throw new Error(data?.error || error?.message || 'Código inválido.')

      // Refresh session auth state
      await authStore.checkAuth(true)
      router.replace({ name: 'enroll-2fa' })
    } catch (err: any) {
      errorMsg.value = err.message || 'Código de recuperación no válido.'
    } finally {
      isSubmitting.value = false
    }
    return
  }

  if (!code.value || code.value.length !== 6) {
    errorMsg.value = 'Ingresa un código de 6 dígitos.'
    return
  }

  isSubmitting.value = true
  errorMsg.value = ''

  try {
    const { data: factorData, error: factorErr } = await supabase.auth.mfa.listFactors()
    if (factorErr) throw factorErr

    const totpFactor = factorData.totp.find(f => f.status === 'verified')
    if (!totpFactor) {
      router.replace({ name: 'enroll-2fa' })
      return
    }

    const challenge = await supabase.auth.mfa.challenge({ factorId: totpFactor.id })
    if (challenge.error) throw challenge.error

    const verifyResp = await supabase.auth.mfa.verify({
      factorId: totpFactor.id,
      challengeId: challenge.data.id,
      code: code.value
    })

    if (verifyResp.error) throw verifyResp.error

    await authStore.checkAuth(true)

    if (authStore.isAdmin) {
      router.replace({ name: 'admin-dashboard' })
    } else {
      router.replace({ name: 'staff-queue' })
    }
  } catch (err: any) {
    errorMsg.value = err.message || 'Código 2FA incorrecto. Intenta de nuevo.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-slate-950 flex flex-col justify-center items-center px-4 py-12 font-body">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl space-y-6">
      <div class="text-center space-y-2">
        <div class="w-14 h-14 bg-emerald-950/80 border border-emerald-700/60 text-emerald-400 rounded-2xl flex items-center justify-center mx-auto shadow-inner">
          <i class="bi bi-shield-check text-2xl"></i>
        </div>
        <h1 class="text-2xl font-bold text-white tracking-wide font-title">Verificación en Dos Pasos (2FA)</h1>
        <p class="text-sm text-slate-400">
          {{ useRecovery ? 'Ingresa uno de tus códigos de recuperación de un solo uso.' : 'Ingresa el código de 6 dígitos de tu aplicación de autenticación.' }}
        </p>
      </div>

      <div v-if="errorMsg" class="p-4 bg-red-950/50 border border-red-800/80 rounded-xl text-red-200 text-sm flex items-start gap-3">
        <i class="bi bi-exclamation-octagon-fill text-red-400 text-lg flex-shrink-0 mt-0.5"></i>
        <div>
          <span class="font-semibold block">Error de autenticación</span>
          <span class="text-red-300 text-xs">{{ errorMsg }}</span>
        </div>
      </div>

      <form @submit.prevent="handleVerify" class="space-y-5">
        <div v-if="!useRecovery">
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2 text-center">
            Código de 6 dígitos
          </label>
          <input
            v-model="code"
            type="text"
            maxlength="6"
            placeholder="123456"
            class="w-full py-3.5 px-4 bg-slate-950 border border-slate-800 rounded-xl text-center text-3xl tracking-[0.3em] font-mono text-emerald-400 placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all shadow-inner"
            required
            autofocus
          />
        </div>

        <div v-else>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2 text-center">
            Código de recuperación
          </label>
          <input
            v-model="recoveryCode"
            type="text"
            placeholder="XXXX-XXXX"
            class="w-full py-3 px-4 bg-slate-950 border border-slate-800 rounded-xl text-center font-mono uppercase text-lg text-emerald-400 placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all shadow-inner"
            required
            autofocus
          />
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full py-3.5 px-4 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white font-semibold rounded-xl transition-all duration-150 flex items-center justify-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50 disabled:cursor-not-allowed text-sm mt-2"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin text-lg"></i>
          <i v-else class="bi bi-shield-lock text-lg"></i>
          <span>{{ isSubmitting ? 'Verificando...' : 'Verificar e Ingresar' }}</span>
        </button>
      </form>

      <div class="pt-2 border-t border-slate-800/80 text-center">
        <button
          type="button"
          @click="useRecovery = !useRecovery; errorMsg = ''"
          class="text-xs text-emerald-400 hover:text-emerald-300 hover:underline font-medium transition-colors"
        >
          {{ useRecovery ? '← Volver a código de autenticador (TOTP)' : '¿Perdiste tu dispositivo? Usar código de recuperación' }}
        </button>
      </div>
    </div>
  </div>
</template>
