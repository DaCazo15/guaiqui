<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useNotificationsStore } from '~/stores/notifications'

const notifStore = useNotificationsStore()
const isIos = ref(false)
const isStandalone = ref(false)
const isSubmitting = ref(false)
const feedbackMessage = ref<string | null>(null)

onMounted(() => {
  notifStore.checkPermissionState()

  if (typeof window !== 'undefined') {
    const ua = window.navigator.userAgent.toLowerCase()
    isIos.value = /iphone|ipad|ipod/.test(ua)
    isStandalone.value =
      window.matchMedia('(display-mode: standalone)').matches || (window.navigator as any).standalone === true
  }
})

const needsIosPwaNotice = computed(() => {
  return isIos.value && !isStandalone.value
})

const handleEnablePush = async () => {
  isSubmitting.value = true
  feedbackMessage.value = null
  try {
    const success = await notifStore.requestPushPermission()
    if (success) {
      feedbackMessage.value = 'Notificaciones push activadas correctamente.'
    } else if (notifStore.pushPermission === 'denied') {
      feedbackMessage.value = 'Permiso denegado en el navegador.'
    }
  } catch (err: any) {
    feedbackMessage.value = err.message || 'No se pudieron activar las notificaciones.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="bg-white border border-guaiqui-border rounded-guaiqui-lg p-5 shadow-guaiqui-sm">
    <div class="flex items-start gap-3">
      <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center shrink-0 text-xl">
        <i class="bi bi-bell-fill"></i>
      </div>
      <div class="flex-1 min-w-0">
        <h3 class="font-display text-base font-bold text-guaiqui-text uppercase tracking-wide">
          Notificaciones Push PWA
        </h3>
        <p class="text-xs text-guaiqui-text-muted mt-1 leading-relaxed">
          Recibe alertas instantáneas sobre la aprobación de tus canjes, trivias del día y noticias de Guaiqueríes.
        </p>

        <!-- Estado 1: iOS sin PWA instalada -->
        <div v-if="needsIosPwaNotice" class="mt-3 p-3 bg-amber-50 border border-amber-200 rounded-guaiqui-md text-xs text-amber-800 flex items-start gap-2">
          <i class="bi bi-apple text-base shrink-0"></i>
          <div>
            <p class="font-semibold">Para activar notificaciones en iPhone:</p>

            <ol class="list-decimal list-inside mt-1 space-y-0.5 text-[11px]">
              <li>Toca el botón <strong>Compartir</strong> <i class="bi bi-share"></i> en Safari.</li>
              <li>Selecciona <strong>"Añadir a pantalla de inicio"</strong>.</li>
              <li>Abre la aplicación desde tu pantalla de inicio para habilitar notificaciones.</li>
            </ol>
          </div>
        </div>

        <!-- Estado 2: Permiso Denegado -->
        <div v-else-if="notifStore.pushPermission === 'denied'" class="mt-3 p-3 bg-red-50 border border-red-200 rounded-guaiqui-md text-xs text-red-800">
          <div class="flex items-center gap-2 font-semibold">
            <i class="bi bi-exclamation-triangle-fill text-red-600"></i>
            <span>Permiso de notificaciones bloquado</span>
          </div>
          <p class="text-[11px] mt-1 text-red-700">
            Has bloqueado las notificaciones para este sitio. Para reactivarlas, haz clic en el icono de candado o configuración junto a la barra de direcciones de tu navegador y permite las Notificaciones.
          </p>
        </div>

        <!-- Estado 3: Permiso Concedido -->
        <div v-else-if="notifStore.pushPermission === 'granted'" class="mt-3 flex items-center justify-between">
          <div class="flex items-center gap-2 text-xs font-semibold text-guaiqui-primary bg-guaiqui-primary-soft px-3 py-1.5 rounded-full border border-guaiqui-primary/20">
            <i class="bi bi-check-circle-fill"></i>
            <span>Notificaciones activas en este dispositivo</span>
          </div>
          <button
            class="text-xs text-guaiqui-text-muted hover:text-red-600 underline font-medium"
            @click="notifStore.unregisterPush"
          >
            Desactivar
          </button>
        </div>

        <!-- Estado 4: Permiso Pendiente (Default) -->
        <div v-else class="mt-4">
          <button
            class="px-4 py-2 bg-guaiqui-primary hover:bg-guaiqui-primary-hover text-white text-xs font-bold rounded-guaiqui-md transition-colors shadow-guaiqui-sm flex items-center gap-2 disabled:opacity-50"
            :disabled="isSubmitting"
            @click="handleEnablePush"
          >
            <i class="bi bi-bell-plus-fill"></i>
            <span>Activar notificaciones</span>
          </button>
        </div>

        <p v-if="feedbackMessage" class="text-xs font-medium mt-2 text-guaiqui-primary">
          {{ feedbackMessage }}
        </p>
      </div>
    </div>
  </div>
</template>
