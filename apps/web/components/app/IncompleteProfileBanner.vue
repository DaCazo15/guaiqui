<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const authStore = useAuthStore()

const isDismissed = ref(false)

onMounted(() => {
  if (typeof window !== 'undefined') {
    isDismissed.value = sessionStorage.getItem('dismiss_incomplete_profile') === 'true'
  }
})

function dismiss() {
  isDismissed.value = true
  if (typeof window !== 'undefined') {
    sessionStorage.setItem('dismiss_incomplete_profile', 'true')
  }
}
</script>

<template>
  <div
    v-if="authStore.isProfileIncomplete && !isDismissed && route.path !== '/app/perfil'"
    class="mb-6 p-4 sm:p-2.5 bg-white border border-guaiqui-primary/30 rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition-all duration-300"
    role="region"
    aria-label="Aviso de perfil incompleto"
  >
    <div class="flex items-start sm:items-center gap-3.5">
      <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center shrink-0 font-bold text-lg border border-guaiqui-primary/20">
        <i class="bi bi-person-fill-exclamation"></i>
      </div>
      <div class="space-y-0.5">
        <h2 class="text-sm sm:text-base font-bold text-guaiqui-text flex items-center gap-2">
          <span>¡Completa tu perfil de Fanático!</span>
          <span class="text-[10px] font-semibold uppercase tracking-wider bg-amber-100 text-amber-800 px-2 py-0.5 rounded-full border border-amber-200">
            Pendiente
          </span>
        </h2>
        <p class="text-xs text-guaiqui-text-muted leading-relaxed max-w-xl">
          Aún te faltan datos en tu perfil (fecha de cumpleaños, talla, municipio o jugador favorito). Complétalos para recibir saludos especiales y premios a tu medida.
        </p>
      </div>
    </div>

    <div class="flex items-center gap-2.5 self-end sm:self-center shrink-0">
      <NuxtLink to="/app/perfil">
        <BaseButton variant="primary" size="sm" class="flex items-center gap-1.5 whitespace-nowrap shadow-guaiqui-sm">
          <span>Configurar Perfil</span>
          <i class="bi bi-arrow-right"></i>
        </BaseButton>
      </NuxtLink>

      <button
        type="button"
        @click="dismiss"
        class="text-slate-400 hover:text-slate-600 p-2 rounded-lg hover:bg-slate-100 transition-colors"
        title="Recordar más tarde"
        aria-label="Cerrar aviso de perfil incompleto"
      >
        <i class="bi bi-x-lg text-sm"></i>
      </button>
    </div>
  </div>
</template>
