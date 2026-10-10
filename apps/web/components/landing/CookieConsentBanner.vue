<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAnalytics } from '~/composables/useAnalytics'

const analytics = useAnalytics()
const isOpen = ref(false)
const showDetails = ref(false)
const analyticsAllowed = ref(false)
const advertisingAllowed = ref(false)

onMounted(() => {
  analytics.initConsent()
  if (analytics.isConsentPending.value) {
    isOpen.value = true
  }
})

const handleAcceptAll = () => {
  analytics.setConsent(true, true)
  isOpen.value = false
}

const handleRejectAll = () => {
  analytics.setConsent(false, false)
  isOpen.value = false
}

const handleSavePreferences = () => {
  analytics.setConsent(analyticsAllowed.value, advertisingAllowed.value)
  isOpen.value = false
}

const openBannerModal = () => {
  analyticsAllowed.value = analytics.hasAnalyticsConsent.value
  advertisingAllowed.value = analytics.hasAdvertisingConsent.value
  isOpen.value = true
}

defineExpose({
  openBannerModal,
})
</script>

<template>
  <div
    v-if="isOpen"
    class="fixed bottom-4 left-4 right-4 sm:left-auto sm:right-6 sm:max-w-md z-50 bg-white border border-guaiqui-border rounded-guaiqui-xl p-5 shadow-2xl space-y-4"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-base">
          <i class="bi bi-shield-lock-fill"></i>
        </div>
        <h4 class="font-display font-bold text-sm text-guaiqui-text uppercase">
          Privacidad y Cookies
        </h4>
      </div>

      <button
        class="text-guaiqui-text-muted hover:text-guaiqui-text text-sm"
        title="Cerrar"
        @click="isOpen = false"
      >
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <p class="text-xs text-guaiqui-text-muted leading-relaxed">
      Utilizamos cookies necesarias para el funcionamiento del sitio y, si lo autorizas, cookies de analítica y publicidad para anuncios recompensados sin rastrear tu identidad personal.
    </p>

    <!-- Detailed category selection toggle -->
    <div v-if="showDetails" class="space-y-3 pt-2 border-t border-guaiqui-border text-xs">
      <div class="flex items-center justify-between opacity-80">
        <div>
          <span class="font-semibold text-guaiqui-text">Cookies Necesarias</span>
          <span class="block text-[10px] text-guaiqui-text-muted">Requeridas para autenticación y billetera.</span>
        </div>
        <input type="checkbox" checked disabled class="accent-guaiqui-primary" />
      </div>

      <div class="flex items-center justify-between pt-1">
        <div>
          <span class="font-semibold text-guaiqui-text">Analítica de Uso</span>
          <span class="block text-[10px] text-guaiqui-text-muted">Métricas anónimas sin grabación de sesión.</span>
        </div>
        <input
          v-model="analyticsAllowed"
          type="checkbox"
          class="w-4 h-4 accent-guaiqui-primary rounded"
        />
      </div>

      <div class="flex items-center justify-between pt-1">
        <div>
          <span class="font-semibold text-guaiqui-text">Publicidad de Terceros</span>
          <span class="block text-[10px] text-guaiqui-text-muted">Requerido para anuncios recompensados (GPT).</span>
        </div>
        <input
          v-model="advertisingAllowed"
          type="checkbox"
          class="w-4 h-4 accent-guaiqui-primary rounded"
        />
      </div>
    </div>

    <div class="flex flex-wrap items-center justify-end gap-2 pt-2 border-t border-guaiqui-border">
      <button
        v-if="!showDetails"
        class="text-xs text-guaiqui-text-muted hover:text-guaiqui-text underline mr-auto font-medium"
        @click="showDetails = true"
      >
        Personalizar
      </button>

      <button
        v-if="showDetails"
        class="px-3 py-1.5 text-xs font-semibold text-guaiqui-text bg-guaiqui-surface hover:bg-guaiqui-border rounded-guaiqui-md border border-guaiqui-border transition-colors"
        @click="handleSavePreferences"
      >
        Guardar
      </button>

      <button
        class="px-3 py-1.5 text-xs font-semibold text-guaiqui-text bg-guaiqui-surface hover:bg-guaiqui-border rounded-guaiqui-md border border-guaiqui-border transition-colors"
        @click="handleRejectAll"
      >
        Solo Necesarias
      </button>

      <button
        class="px-3.5 py-1.5 text-xs font-bold text-white bg-guaiqui-primary hover:bg-guaiqui-primary-hover rounded-guaiqui-md shadow-guaiqui-sm transition-colors"
        @click="handleAcceptAll"
      >
        Aceptar Todas
      </button>
    </div>
  </div>
</template>
