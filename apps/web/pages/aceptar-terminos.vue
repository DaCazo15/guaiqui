<script setup lang="ts">
import { ref } from 'vue'
import { BaseCheckbox, BaseButton, BaseCard } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

const terms = ref(false)
const privacy = ref(false)
const pearlsRules = ref(false)

const localError = ref<string | null>(null)

async function handleAccept() {
  localError.value = null

  if (!terms.value || !privacy.value || !pearlsRules.value) {
    localError.value = 'Debes aceptar los Términos, Políticas de Privacidad y Reglas de Puntos para continuar.'
    return
  }

  try {
    await authStore.acceptConsent()
    navigateTo('/app')
  } catch (err: any) {
    localError.value = err.message || 'Error al guardar el consentimiento.'
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-guaiqui-surface text-guaiqui-text">
    <div class="w-full max-w-md space-y-6">
      <div class="text-center space-y-2">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-guaiqui-primary text-3xl mb-2 shadow-guaiqui-sm">
          <i class="bi bi-file-earmark-check-fill"></i>
        </div>
        <h1 class="font-display text-3xl font-bold uppercase tracking-wider text-guaiqui-text">
          Consentimiento de <span class="text-guaiqui-primary">Términos</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Para acceder a la plataforma Guaiqueríes Fan Zone, debes aceptar nuestras políticas.
        </p>
      </div>

      <BaseCard class="bg-white border-guaiqui-border shadow-guaiqui-md p-6 rounded-guaiqui-xl space-y-4">
        <div v-if="localError" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-sm flex items-center gap-2">
          <i class="bi bi-exclamation-circle-fill shrink-0"></i>
          <span>{{ localError }}</span>
        </div>

        <div class="space-y-4 text-sm text-guaiqui-text-muted">
          <BaseCheckbox v-model="terms">
            Acepto los
            <NuxtLink to="/politicas/terminos" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
              Términos y Condiciones
            </NuxtLink>
            *
          </BaseCheckbox>

          <BaseCheckbox v-model="privacy">
            Acepto las
            <NuxtLink to="/politicas/privacidad" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
              Políticas de Privacidad
            </NuxtLink>
            *
          </BaseCheckbox>

          <BaseCheckbox v-model="pearlsRules">
            Acepto las
            <NuxtLink to="/politicas/perlitas" target="_blank" class="text-guaiqui-primary underline hover:text-guaiqui-primary-dark font-medium">
              Reglas del Programa de Puntos
            </NuxtLink>
            *
          </BaseCheckbox>
        </div>

        <BaseButton variant="primary" block :loading="authStore.isLoading" @click="handleAccept">
          <span>Aceptar y Entrar a la App</span>
          <i class="bi bi-arrow-right ml-1.5"></i>
        </BaseButton>
      </BaseCard>

      <div class="text-center text-sm text-guaiqui-text-muted">
        <button @click="authStore.logout()" class="text-guaiqui-text-muted hover:text-guaiqui-text underline text-xs">
          Cerrar sesión
        </button>
      </div>
    </div>
  </div>
</template>
