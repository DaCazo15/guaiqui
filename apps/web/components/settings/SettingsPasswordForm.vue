<script setup lang="ts">
import { ref } from 'vue'
import { BaseInput, BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

const newPassword = ref('')
const confirmPassword = ref('')
const successMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)

async function handlePasswordChange() {
  successMessage.value = null
  errorMessage.value = null

  if (!newPassword.value || newPassword.value.length < 8) {
    errorMessage.value = 'La contraseña debe tener al menos 8 caracteres.'
    return
  }

  if (newPassword.value !== confirmPassword.value) {
    errorMessage.value = 'Las contraseñas no coinciden.'
    return
  }

  try {
    await authStore.updatePassword(newPassword.value)
    successMessage.value = 'Contraseña actualizada correctamente.'
    newPassword.value = ''
    confirmPassword.value = ''
  } catch (err: any) {
    errorMessage.value = err.message
  }
}
</script>

<template>
  <form @submit.prevent="handlePasswordChange" class="space-y-4">
    <h3 class="text-base font-semibold text-guaiqui-text">Cambiar Contraseña</h3>

    <div v-if="successMessage" class="p-3 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-md text-guaiqui-status-success text-sm flex items-center gap-2">
      <i class="bi bi-check-circle-fill shrink-0"></i>
      <span>{{ successMessage }}</span>
    </div>

    <div v-if="errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ errorMessage }}</span>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
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
        placeholder="Repite la contraseña"
        required
      />
    </div>

    <BaseButton type="submit" variant="outline" size="sm" :loading="authStore.isLoading">
      <i class="bi bi-key-fill mr-1.5"></i>
      Actualizar Contraseña
    </BaseButton>
  </form>
</template>
