<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import AuthBasketballHorizon from '~/components/auth/AuthBasketballHorizon.vue'
import AuthMobileSheet from '~/components/auth/AuthMobileSheet.vue'

definePageMeta({
  middleware: ['guest'],
})

const route = useRoute()
const authStore = useAuthStore()

const initialMode = computed<'login' | 'register'>(() => {
  return route.query.tab === 'register' ? 'register' : 'login'
})

const localError = ref<string | null>(null)

async function handleLogin(payload: { email: string; pass: string }) {
  localError.value = null
  try {
    await authStore.loginWithEmail(payload.email, payload.pass)
    if (!authStore.isEmailVerified) {
      navigateTo('/verificar-correo')
    } else if (authStore.needsConsent) {
      navigateTo('/aceptar-terminos')
    } else {
      navigateTo('/app')
    }
  } catch (err: any) {
    localError.value = err.message || 'Error al iniciar sesión'
  }
}

async function handleRegister(payload: { email: string; pass: string }) {
  localError.value = null
  try {
    await authStore.signUpWithEmail(
      payload.email,
      payload.pass,
      { terms: true, privacy: true, pearlsRules: true },
      { displayName: payload.email.split('@')[0] }
    )
    navigateTo('/verificar-correo')
  } catch (err: any) {
    localError.value = err.message || 'Error al registrar la cuenta'
  }
}

async function handleGoogleAuth() {
  localError.value = null
  try {
    await authStore.loginWithGoogle()
  } catch (err: any) {
    localError.value = err.message || 'Error al conectar con Google'
  }
}
</script>

<template>
  <div class="min-h-screen w-full bg-[#01140c] text-white flex items-center justify-center sm:p-6 md:p-8 overflow-x-hidden">
    <!-- Responsive Container: Full screen on mobile, device card on desktop & tablet -->
    <div class="relative w-full min-h-screen sm:min-h-[760px] md:min-h-[780px] sm:my-auto max-w-md sm:max-w-[480px] md:max-w-[520px] lg:max-w-[540px] bg-gradient-to-b from-[#01170f] via-[#022c1e] to-[#043e1e] sm:rounded-[44px] sm:border sm:border-emerald-500/30 sm:shadow-[0_25px_60px_rgba(0,0,0,0.8)] flex flex-col justify-between overflow-hidden">
      <!-- Turnstile Captcha Hidden / Extension Slot -->
      <AuthTurnstileWrapper />

      <!-- Top Section: Team Brand, Fan Activo Title & Spinning Half-Submerged Basketball -->
      <div class="relative flex-1 flex flex-col justify-start">
        <AuthBasketballHorizon />
      </div>

      <!-- Bottom Section: Curved Green Sheet with Iniciar Sesión / Registrarte & Google Button -->
      <AuthMobileSheet
        :loading="authStore.isLoading"
        :error-message="localError || authStore.errorMessage"
        :initial-mode="initialMode"
        @login="handleLogin"
        @register="handleRegister"
        @google-auth="handleGoogleAuth"
      />
    </div>
  </div>
</template>
