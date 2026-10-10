<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton, BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

definePageMeta({
  middleware: ['guest'],
})

const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const localError = ref<string | null>(null)

async function handleLogin() {
  localError.value = null
  if (!email.value || !password.value) {
    localError.value = 'Por favor ingresa tu correo y contraseña.'
    return
  }

  try {
    await authStore.loginWithEmail(email.value, password.value)
    if (!authStore.isEmailVerified) {
      navigateTo('/verificar-correo')
    } else if (authStore.needsConsent) {
      navigateTo('/aceptar-terminos')
    } else {
      navigateTo('/app')
    }
  } catch (err: any) {
    localError.value = err.message
  }
}

async function handleGoogleLogin() {
  try {
    await authStore.loginWithGoogle()
  } catch (err: any) {
    localError.value = err.message
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-guaiqui-surface text-guaiqui-text">
    <div class="w-full max-w-md space-y-6">
      <!-- Header / Logo -->
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary text-3xl shadow-guaiqui-sm">
          <i class="bi bi-dribbble"></i>
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Guaiqueríes <span class="text-guaiqui-primary">Fan Zone</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Inicia sesión para jugar trivias, acumular perlitas y ganar premios.
        </p>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl space-y-6">
        <form class="space-y-4" @submit.prevent="handleLogin">
          <div v-if="localError || authStore.errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
            <i class="bi bi-exclamation-circle-fill shrink-0"></i>
            <span>{{ localError || authStore.errorMessage }}</span>
          </div>

          <BaseInput
            v-model="email"
            label="Correo electrónico"
            type="email"
            placeholder="tu@email.com"
            required
          />

          <BaseInput
            v-model="password"
            label="Contraseña"
            type="password"
            placeholder="••••••••"
            required
          />

          <div class="flex justify-end">
            <NuxtLink to="/recuperar" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-medium underline">
              ¿Olvidaste tu contraseña?
            </NuxtLink>
          </div>

          <AuthTurnstileWrapper />

          <BaseButton type="submit" variant="primary" block :loading="authStore.isLoading">
            <i class="bi bi-box-arrow-in-right mr-1.5"></i>
            Iniciar Sesión
          </BaseButton>
        </form>

        <div class="relative my-4">
          <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-guaiqui-border"></div></div>
          <div class="relative flex justify-center text-xs uppercase"><span class="bg-white px-2 text-guaiqui-text-subtle font-medium">o continúa con</span></div>
        </div>

        <BaseButton type="button" variant="outline" block @click="handleGoogleLogin">
          <span class="flex items-center justify-center gap-2">
            <svg class="w-4 h-4" viewBox="0 0 24 24"><path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/><path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/><path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/></svg>
            Iniciar sesión con Google
          </span>
        </BaseButton>
      </BaseCard>

      <div class="text-center text-sm text-guaiqui-text-muted">
        ¿Aún no tienes cuenta?
        <NuxtLink to="/registro" class="text-guaiqui-primary font-semibold hover:text-guaiqui-primary-dark underline ml-1">
          Regístrate gratis
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
