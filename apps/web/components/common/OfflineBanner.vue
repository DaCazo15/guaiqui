<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

const isOffline = ref(false)
const retrying = ref(false)

const checkConnection = () => {
  if (typeof navigator !== 'undefined') {
    isOffline.value = !navigator.onLine
  }
}

const retry = async () => {
  retrying.value = true
  try {
    // Intentar una petición ligera para verificar conectividad real
    await fetch('/manifest.json', { method: 'HEAD', cache: 'no-store' })
    isOffline.value = false
  } catch {
    isOffline.value = true
  } finally {
    retrying.value = false
  }
}

onMounted(() => {
  checkConnection()
  window.addEventListener('online', checkConnection)
  window.addEventListener('offline', checkConnection)
})

onUnmounted(() => {
  window.removeEventListener('online', checkConnection)
  window.removeEventListener('offline', checkConnection)
})
</script>

<template>
  <Transition
    enter-active-class="transition duration-300 ease-out"
    enter-from-class="transform -translate-y-full opacity-0"
    enter-to-class="transform translate-y-0 opacity-100"
    leave-active-class="transition duration-200 ease-in"
    leave-from-class="transform translate-y-0 opacity-100"
    leave-to-class="transform -translate-y-full opacity-0"
  >
    <div
      v-if="isOffline"
      class="fixed top-0 left-0 right-0 z-50 bg-amber-600 text-white px-4 py-2.5 shadow-lg flex items-center justify-between gap-3 text-xs sm:text-sm font-medium safe-top"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-wifi-off text-base"></i>
        <span>Sin conexión a internet. Algunas funciones pueden estar limitadas.</span>
      </div>

      <button
        type="button"
        :disabled="retrying"
        class="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-amber-800 hover:bg-amber-900 text-white font-bold text-xs transition-colors shrink-0 disabled:opacity-60 cursor-pointer"
        @click="retry"
      >
        <i :class="['bi', retrying ? 'bi-arrow-repeat animate-spin' : 'bi-arrow-clockwise']"></i>
        <span>{{ retrying ? 'Reconectando...' : 'Reintentar' }}</span>
      </button>
    </div>
  </Transition>
</template>
