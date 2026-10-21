<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { BaseButton, BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

const cooldownSeconds = ref(0)
let timer: ReturnType<typeof setInterval> | null = null

const feedbackMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)

const supabase = useSupabaseClient()

onMounted(async () => {
  startCooldown(60)
  // Comprobar automáticamente si el usuario ya fue verificado para no retenerlo
  try {
    const { data: refreshData } = await supabase.auth.refreshSession()
    const updatedUser = refreshData?.user || (await supabase.auth.getUser()).data?.user
    if (updatedUser) {
      await authStore.fetchProfile(updatedUser)
      if (authStore.isEmailVerified) {
        if (authStore.needsConsent) {
          navigateTo('/aceptar-terminos')
        } else {
          navigateTo('/app')
        }
      }
    }
  } catch {
    // Mantenerse en la vista si aún no está verificado
  }
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})

function startCooldown(seconds: number) {
  cooldownSeconds.value = seconds
  if (timer) clearInterval(timer)
  timer = setInterval(() => {
    if (cooldownSeconds.value > 0) {
      cooldownSeconds.value--
    } else {
      if (timer) clearInterval(timer)
    }
  }, 1000)
}

async function handleResend() {
  if (cooldownSeconds.value > 0) return
  feedbackMessage.value = null
  errorMessage.value = null

  const targetEmail = authStore.user?.email
  if (!targetEmail) {
    errorMessage.value = 'No se encontró el correo del usuario.'
    return
  }

  try {
    await authStore.resendVerificationEmail(targetEmail)
    feedbackMessage.value = '¡Enlace de verificación reenviado! Revisa tu bandeja de entrada.'
    startCooldown(60)
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : 'Error al reenviar correo.'
  }
}

async function checkVerification() {
  try {
    feedbackMessage.value = null
    errorMessage.value = null

    // 1. Refrescar la sesión con Supabase Auth para renovar el JWT con el nuevo email_confirmed_at
    const { data: refreshData } = await supabase.auth.refreshSession()
    const updatedUser = refreshData?.user || (await supabase.auth.getUser()).data?.user

    // 2. Sincronizar el usuario refrescado en el store
    await authStore.fetchProfile(updatedUser)

    // 3. Comprobar si ya está verificado y redirigir
    if (authStore.isEmailVerified) {
      if (authStore.needsConsent) {
        navigateTo('/aceptar-terminos')
      } else {
        navigateTo('/app')
      }
      return
    }
  } catch (err) {
    console.warn('Error al verificar sesión:', err)
  }

  feedbackMessage.value = 'El correo aún no ha sido verificado. Por favor revisa tu bandeja de entrada o spam.'
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-guaiqui-surface text-guaiqui-text">
    <div class="w-full max-w-md space-y-6">
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary text-3xl mb-2 shadow-guaiqui-sm">
          <i class="bi bi-envelope-check-fill"></i>
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Verifica tu <span class="text-guaiqui-primary">Correo</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Enviamos un correo de verificación a:
          <strong class="text-guaiqui-text font-mono block mt-1">{{ authStore.user?.email || 'tu correo' }}</strong>
        </p>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl space-y-4">
        <div v-if="feedbackMessage" class="p-3 bg-guaiqui-primary-soft border border-guaiqui-primary/30 rounded-guaiqui-md text-guaiqui-primary text-sm flex items-center gap-2">
          <i class="bi bi-info-circle-fill shrink-0"></i>
          <span>{{ feedbackMessage }}</span>
        </div>

        <div v-if="errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
          <i class="bi bi-exclamation-circle-fill shrink-0"></i>
          <span>{{ errorMessage }}</span>
        </div>

        <p class="text-xs text-guaiqui-text-muted leading-relaxed">
          Debes hacer clic en el enlace del correo para activar tu cuenta y comenzar a ganar y canjear puntos.
        </p>

        <div class="space-y-3 pt-2">
          <BaseButton variant="primary" block @click="checkVerification">
            <span>Ya lo verifiqué, Continuar</span>
            <i class="bi bi-arrow-right ml-1.5"></i>
          </BaseButton>

          <BaseButton
            variant="outline"
            block
            :disabled="cooldownSeconds > 0 || authStore.isLoading"
            @click="handleResend"
          >
            <span v-if="cooldownSeconds > 0">Reenviar correo en {{ cooldownSeconds }}s</span>
            <span v-else class="flex items-center justify-center gap-1.5">
              <i class="bi bi-arrow-clockwise"></i>
              <span>Reenviar correo de verificación</span>
            </span>
          </BaseButton>
        </div>
      </BaseCard>

      <div class="text-center text-sm text-guaiqui-text-muted">
        <button class="text-guaiqui-text-muted hover:text-guaiqui-text underline text-xs" @click="authStore.logout()">
          Cerrar sesión / Usar otra cuenta
        </button>
      </div>
    </div>
  </div>
</template>
