<script setup lang="ts">
import { ref } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { useSupabaseClient } from '#imports'

const supabase = useSupabaseClient()

const isLoading = ref(false)
const message = ref('')

const handleGlobalSignOut = async () => {
  if (!confirm('¿Deseas cerrar sesión en todos tus navegadores y dispositivos activos?')) return

  isLoading.value = true
  message.value = ''

  try {
    const { error } = await supabase.auth.signOut({ scope: 'global' })
    if (error) throw error

    message.value = 'Sesión cerrada en todos los dispositivos.'
    setTimeout(() => {
      window.location.href = '/login'
    }, 1000)
  } catch (err: any) {
    message.value = err.message || 'Error al cerrar sesión globalmente.'
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="space-y-2">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-base font-semibold text-guaiqui-text">Sesiones Activas</h3>
        <p class="text-xs text-guaiqui-text-muted">
          Cierra inmediatamente el acceso en todos los navegadores y dispositivos móviles donde hayas iniciado sesión.
        </p>
      </div>

      <BaseButton variant="outline" size="sm" :disabled="isLoading" @click="handleGlobalSignOut">
        <i v-if="isLoading" class="bi bi-arrow-repeat animate-spin mr-1.5"></i>
        <i v-else class="bi bi-box-arrow-left mr-1.5"></i>
        Cerrar sesión en todos los dispositivos
      </BaseButton>
    </div>

    <p v-if="message" class="text-xs font-medium text-guaiqui-primary mt-1">{{ message }}</p>
  </div>
</template>
