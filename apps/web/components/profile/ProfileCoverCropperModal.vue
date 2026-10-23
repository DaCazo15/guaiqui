<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue'
import { cropAndCompressCover } from '@guaiqui/shared'

const props = defineProps<{
  isOpen: boolean
  file: File | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm', croppedFile: File): void
}>()

const imageUrl = ref<string | null>(null)
const imageWidth = ref(0)
const imageHeight = ref(0)
const isTall = ref(false)
const isWide = ref(false)
const positionPercent = ref(50) // 0 a 100
const isProcessing = ref(false)
const errorMessage = ref<string | null>(null)

watch(
  () => props.file,
  (newFile) => {
    if (imageUrl.value) {
      URL.revokeObjectURL(imageUrl.value)
      imageUrl.value = null
    }
    positionPercent.value = 50
    errorMessage.value = null

    if (!newFile) return

    const url = URL.createObjectURL(newFile)
    imageUrl.value = url

    const img = new Image()
    img.onload = () => {
      imageWidth.value = img.naturalWidth || img.width
      imageHeight.value = img.naturalHeight || img.height

      const targetRatio = 8 / 3 // 2.666
      const currentRatio = imageWidth.value / (imageHeight.value || 1)

      if (currentRatio < targetRatio) {
        // La foto es más alta / vertical: requiere ajuste vertical
        isTall.value = true
        isWide.value = false
      } else {
        // La foto es más ancha: requiere ajuste horizontal
        isTall.value = false
        isWide.value = true
      }
    }
    img.src = url
  },
  { immediate: true }
)

onUnmounted(() => {
  if (imageUrl.value) {
    URL.revokeObjectURL(imageUrl.value)
  }
})

// Estilo de previsualización dinámico para encuadrar en tiempo real según el deslizador
const previewObjectPosition = computed(() => {
  if (isTall.value) {
    return `center ${positionPercent.value}%`
  }
  if (isWide.value) {
    return `${positionPercent.value}% center`
  }
  return 'center center'
})

async function handleConfirmCrop() {
  if (!props.file) return
  isProcessing.value = true
  errorMessage.value = null

  try {
    const fraction = positionPercent.value / 100
    const cropArea = isTall.value
      ? { yPercent: fraction, xPercent: 0.5 }
      : { xPercent: fraction, yPercent: 0.5 }

    // Recorte irreversible en cliente y compresión estricta a WebP entre 5 KB y 10 KB
    const croppedFile = await cropAndCompressCover(props.file, cropArea, {
      targetWidth: 600,
      targetHeight: 225,
      minTargetBytes: 5 * 1024,
      targetBytes: 8 * 1024,
      maxBytes: 10 * 1024,
    })

    emit('confirm', croppedFile)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al procesar el recorte de la imagen.'
  } finally {
    isProcessing.value = false
  }
}

function handleClose() {
  if (isProcessing.value) return
  emit('close')
}
</script>

<template>
  <div
    v-if="isOpen && file"
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-xs animate-in fade-in duration-200"
    role="dialog"
    aria-modal="true"
    aria-labelledby="cropper-title"
  >
    <div class="bg-white rounded-guaiqui-2xl max-w-xl w-full p-5 sm:p-6 shadow-2xl border border-guaiqui-border space-y-4">
      <!-- Encabezado del modal -->
      <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
        <div class="flex items-center gap-2 text-guaiqui-text">
          <i class="bi bi-crop text-guaiqui-primary text-xl"></i>
          <h3 id="cropper-title" class="font-display font-extrabold text-lg uppercase tracking-wide">
            Encuadrar Foto de Portada
          </h3>
        </div>
        <button
          type="button"
          @click="handleClose"
          :disabled="isProcessing"
          class="text-gray-400 hover:text-gray-700 p-1 rounded-lg transition-colors"
          title="Cerrar"
        >
          <i class="bi bi-x-lg text-lg"></i>
        </button>
      </div>

      <!-- Visor de recorte interactivo (8:3) -->
      <div class="relative w-full aspect-[8/3] rounded-guaiqui-xl overflow-hidden bg-slate-900 border-2 border-dashed border-guaiqui-primary shadow-inner">
        <img
          v-if="imageUrl"
          :src="imageUrl"
          alt="Previsualización de recorte"
          class="w-full h-full object-cover transition-all duration-75 select-none pointer-events-none"
          :style="{ objectPosition: previewObjectPosition }"
        />

        <!-- Guía de encuadre translúcida -->
        <div class="absolute inset-0 pointer-events-none border border-white/40 flex items-center justify-center">
          <div class="text-[11px] text-white/80 font-bold bg-black/40 px-2 py-0.5 rounded-full backdrop-blur-xs flex items-center gap-1">
            <i class="bi bi-aspect-ratio"></i>
            <span>Vista final de portada</span>
          </div>
        </div>
      </div>

      <!-- Control deslizante de encuadre -->
      <div class="space-y-1.5 pt-1">
        <div class="flex items-center justify-between text-xs font-medium text-guaiqui-text">
          <span class="flex items-center gap-1.5">
            <i :class="isTall ? 'bi-arrows-vertical' : 'bi-arrows'"></i>
            <span>{{ isTall ? 'Posición vertical de la foto' : 'Posición horizontal' }}</span>
          </span>
        </div>

        <input
          type="range"
          min="0"
          max="100"
          v-model.number="positionPercent"
          :disabled="isProcessing"
          class="w-full h-2 bg-gray-200 rounded-lg mb-2 appearance-none cursor-pointer accent-guaiqui-primary"
        />

      </div>

      <!-- Alerta de Error -->
      <p v-if="errorMessage" class="text-xs text-rose-600 flex items-center gap-1.5 p-2 bg-rose-50 rounded-lg">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <span>{{ errorMessage }}</span>
      </p>

      <!-- Botones de Acción -->
      <div class="flex items-center justify-end gap-2.5 pt-2 border-t border-guaiqui-border">
        <button
          type="button"
          @click="handleClose"
          :disabled="isProcessing"
          class="px-4 py-2 rounded-guaiqui-md border border-guaiqui-border text-xs font-bold text-guaiqui-text uppercase tracking-wider hover:bg-gray-100 transition-colors disabled:opacity-50"
        >
          Cancelar
        </button>

        <button
          type="button"
          @click="handleConfirmCrop"
          :disabled="isProcessing"
          class="px-5 py-2 rounded-guaiqui-md bg-guaiqui-primary text-white text-xs font-bold uppercase tracking-wider hover:bg-guaiqui-primary-dark transition-all shadow-md active:scale-95 disabled:opacity-50 flex items-center gap-2"
        >
          <i v-if="isProcessing" class="bi bi-arrow-repeat animate-spin text-sm"></i>
          <i v-else class="bi bi-check2-circle text-sm"></i>
          <span>{{ isProcessing ? 'Recortando y guardando...' : 'Recortar y Guardar' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
