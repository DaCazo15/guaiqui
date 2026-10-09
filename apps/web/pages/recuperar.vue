<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton, BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

definePageMeta({
  middleware: ['guest'],
})

const authStore = useAuthStore()
const email = ref('')
const successMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)

async function handleResetRequest() {
  errorMessage.value = null
  successMessage.value = null

  if (!email.value || !email.value.includes('@')) {
    errorMessage.value = 'Ingresa un correo electrónico válido.'
    return
  }

  try {
    await authStore.requestPasswordReset(email.value)
    successMessage.value = 'Hemos enviado las instrucciones para restablecer tu contraseña a tu correo.'
  } catch (err: any) {
    errorMessage.value = err.message
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-guaiqui-surface text-guaiqui-text">
    <div class="w-full max-w-md space-y-6">
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center w-14 h-14 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary text-2xl shadow-guaiqui-sm">
          <i class="bi bi-key-fill"></i>
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Recuperar <span class="text-guaiqui-primary">Contraseña</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Ingresa tu correo registrado y te enviaremos un enlace de recuperación.
        </p>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl space-y-4">
        <div v-if="successMessage" class="p-4 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-md text-guaiqui-status-success text-sm space-y-2">
          <p class="flex items-center gap-2">
            <i class="bi bi-check-circle-fill shrink-0"></i>
            <span>{{ successMessage }}</span>
          </p>
          <NuxtLink to="/login" class="inline-flex items-center gap-1.5 text-guaiqui-primary underline font-medium hover:text-guaiqui-primary-dark">
            <span>Volver a Iniciar Sesión</span>
            <i class="bi bi-arrow-right"></i>
          </NuxtLink>
        </div>

        <form v-else @submit.prevent="handleResetRequest" class="space-y-4">
          <div v-if="errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
            <i class="bi bi-exclamation-circle-fill shrink-0"></i>
            <span>{{ errorMessage }}</span>
          </div>

          <BaseInput
            v-model="email"
            label="Correo electrónico"
            type="email"
            placeholder="tu@email.com"
            required
          />

          <BaseButton type="submit" variant="primary" block :loading="authStore.isLoading">
            <i class="bi bi-send-fill mr-1.5"></i>
            Enviar Instrucciones
          </BaseButton>
        </form>
      </BaseCard>

      <div class="text-center text-sm text-guaiqui-text-muted">
        <NuxtLink to="/login" class="text-guaiqui-primary font-semibold hover:text-guaiqui-primary-dark underline inline-flex items-center gap-1">
          <i class="bi bi-arrow-left"></i>
          Volver a Iniciar Sesión
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
