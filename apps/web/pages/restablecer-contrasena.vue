<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton, BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

const newPassword = ref('')
const confirmPassword = ref('')
const successMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)

async function handleUpdatePassword() {
  errorMessage.value = null
  successMessage.value = null

  if (!newPassword.value || newPassword.value.length < 8) {
    errorMessage.value = 'La nueva contraseña debe tener al menos 8 caracteres.'
    return
  }

  if (newPassword.value !== confirmPassword.value) {
    errorMessage.value = 'Las contraseñas no coinciden.'
    return
  }

  try {
    await authStore.updatePassword(newPassword.value)
    successMessage.value = 'Tu contraseña ha sido actualizada correctamente.'
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
          <i class="bi bi-shield-lock-fill"></i>
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Nueva <span class="text-guaiqui-primary">Contraseña</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Ingresa tu nueva contraseña para acceder a tu cuenta.
        </p>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl space-y-4">
        <div v-if="successMessage" class="p-4 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-md text-guaiqui-status-success text-sm space-y-2">
          <p class="flex items-center gap-2">
            <i class="bi bi-check-circle-fill shrink-0"></i>
            <span>{{ successMessage }}</span>
          </p>
          <NuxtLink to="/app" class="inline-flex items-center gap-1.5 text-guaiqui-primary underline font-medium hover:text-guaiqui-primary-dark">
            <span>Ir a la App Fan Zone</span>
            <i class="bi bi-arrow-right"></i>
          </NuxtLink>
        </div>

        <form v-else @submit.prevent="handleUpdatePassword" class="space-y-4">
          <div v-if="errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
            <i class="bi bi-exclamation-circle-fill shrink-0"></i>
            <span>{{ errorMessage }}</span>
          </div>

          <BaseInput
            v-model="newPassword"
            label="Nueva contraseña"
            type="password"
            placeholder="Mínimo 8 caracteres"
            required
          />

          <BaseInput
            v-model="confirmPassword"
            label="Confirmar nueva contraseña"
            type="password"
            placeholder="Repite la nueva contraseña"
            required
          />

          <BaseButton type="submit" variant="primary" block :loading="authStore.isLoading">
            <i class="bi bi-check-circle mr-1.5"></i>
            Actualizar Contraseña
          </BaseButton>
        </form>
      </BaseCard>
    </div>
  </div>
</template>
