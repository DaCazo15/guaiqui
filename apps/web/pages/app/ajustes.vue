<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import SettingsPreferencesForm from '~/components/settings/SettingsPreferencesForm.vue'
import SettingsPasswordForm from '~/components/settings/SettingsPasswordForm.vue'
import SettingsDeleteModal from '~/components/settings/SettingsDeleteModal.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const authStore = useAuthStore()

const isDeleteModalOpen = ref(false)
const deleteError = ref<string | null>(null)

async function handleDeleteAccount() {
  deleteError.value = null
  try {
    await authStore.deleteAccount()
  } catch (err: any) {
    deleteError.value = err.message || 'Error al eliminar la cuenta.'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Ajustes y <span class="text-guaiqui-primary">Configuración</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Gestiona las preferencias de tu cuenta, seguridad y privacidad.
      </p>
    </div>

    <!-- Main Card -->
    <BaseCard class="bg-white border-guaiqui-border p-6 rounded-guaiqui-xl space-y-8 shadow-guaiqui-sm">
      <!-- Section 1: Preferences -->
      <SettingsPreferencesForm />

      <div class="border-t border-guaiqui-border pt-6">
        <!-- Section 2: Change Password -->
        <SettingsPasswordForm />
      </div>

      <div class="border-t border-guaiqui-border pt-6 space-y-4">
        <!-- Section 3: Policies Links -->
        <h3 class="text-base font-semibold text-guaiqui-text">Políticas y Privacidad</h3>
        <div class="flex flex-wrap gap-4 text-xs">
          <NuxtLink to="/politicas/terminos" target="_blank" class="text-guaiqui-primary hover:text-guaiqui-primary-dark underline font-medium">
            Términos y Condiciones
          </NuxtLink>
          <NuxtLink to="/politicas/privacidad" target="_blank" class="text-guaiqui-primary hover:text-guaiqui-primary-dark underline font-medium">
            Políticas de Privacidad
          </NuxtLink>
          <NuxtLink to="/politicas/perlitas" target="_blank" class="text-guaiqui-primary hover:text-guaiqui-primary-dark underline font-medium">
            Reglas del Programa de Perlitas
          </NuxtLink>
        </div>
      </div>

      <div class="border-t border-guaiqui-border pt-6 space-y-4">
        <!-- Section 4: Account Actions -->
        <h3 class="text-base font-semibold text-guaiqui-status-danger">Zona de Riesgo</h3>

        <div class="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between p-4 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/20 rounded-guaiqui-lg">
          <div>
            <p class="text-sm font-semibold text-guaiqui-text">Eliminar Cuenta</p>
            <p class="text-xs text-guaiqui-text-muted">
              Anonimiza tus datos personales y deshabilita tu acceso a la plataforma.
            </p>
          </div>

          <BaseButton variant="danger" size="sm" @click="isDeleteModalOpen = true">
            <i class="bi bi-trash3-fill mr-1.5"></i>
            Eliminar Cuenta
          </BaseButton>
        </div>
      </div>
    </BaseCard>

    <!-- Delete Confirmation Modal -->
    <SettingsDeleteModal
      :open="isDeleteModalOpen"
      :loading="authStore.isLoading"
      :error="deleteError"
      @close="isDeleteModalOpen = false"
      @confirm="handleDeleteAccount"
    />
  </div>
</template>
