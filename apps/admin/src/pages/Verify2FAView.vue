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
  <div class="min-h-screen flex items-center justify-center bg-gray-100 p-4">
    <div class="max-w-md w-full bg-white rounded-xl shadow-lg p-6 space-y-6">
      <div class="text-center space-y-2">
        <div class="w-12 h-12 bg-green-100 text-green-700 rounded-full flex items-center justify-center mx-auto">
          <i class="bi bi-shield-check text-2xl"></i>
        </div>
        <h1 class="text-xl font-bold text-gray-900">Verificación en Dos Pasos (2FA)</h1>
        <p class="text-sm text-gray-600">
          {{ useRecovery ? 'Ingresa uno de tus códigos de recuperación de un solo uso.' : 'Ingresa el código de 6 dígitos de tu aplicación de autenticación.' }}
        </p>
      </div>

      <div v-if="errorMsg" class="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <span>{{ errorMsg }}</span>
      </div>

      <form @submit.prevent="handleVerify" class="space-y-4">
        <div v-if="!useRecovery">
          <label class="block text-sm font-medium text-gray-700 mb-1">Código de 6 dígitos</label>
          <input
            v-model="code"
            type="text"
            maxlength="6"
            placeholder="123456"
            class="w-full px-4 py-2 border rounded-lg text-center text-2xl tracking-widest font-mono focus:ring-2 focus:ring-green-500 focus:outline-none"
            required
          />
        </div>

        <div v-else>
          <label class="block text-sm font-medium text-gray-700 mb-1">Código de recuperación</label>
          <input
            v-model="recoveryCode"
            type="text"
            placeholder="XXXX-XXXX"
            class="w-full px-4 py-2 border rounded-lg text-center font-mono uppercase focus:ring-2 focus:ring-green-500 focus:outline-none"
            required
          />
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg transition disabled:opacity-50 flex items-center justify-center gap-2"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin"></i>
          <span>{{ isSubmitting ? 'Verificando...' : 'Verificar e Ingresar' }}</span>
        </button>
      </form>

      <div class="text-center">
        <button
          type="button"
          @click="useRecovery = !useRecovery; errorMsg = ''"
          class="text-xs text-green-700 hover:underline font-medium"
        >
          {{ useRecovery ? '← Volver a código de autenticador (TOTP)' : '¿Perdiste tu dispositivo? Usar código de recuperación' }}
        </button>
      </div>
    </div>
  </div>
</template>
