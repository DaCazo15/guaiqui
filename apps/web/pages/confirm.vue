<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

onMounted(async () => {
  await authStore.fetchProfile()

  if (authStore.isAuthenticated) {
    if (!authStore.isEmailVerified) {
      navigateTo('/verificar-correo')
    } else if (authStore.needsConsent) {
      navigateTo('/aceptar-terminos')
    } else {
      navigateTo('/app')
    }
  } else {
    navigateTo('/login')
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-guaiqui-surface text-guaiqui-text">
    <div class="text-center space-y-4">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary text-3xl shadow-guaiqui-sm">
        <i class="bi bi-arrow-repeat animate-spin"></i>
      </div>
      <p class="text-guaiqui-text-muted text-sm font-medium">Verificando sesión...</p>
    </div>
  </div>
</template>
