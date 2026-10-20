<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  avatarUrl?: string | null
  displayName?: string | null
  uploading?: boolean
}>()

const emit = defineEmits<{
  (e: 'upload', file: File): void
}>()

const fileInputRef = ref<HTMLInputElement | null>(null)
const localError = ref<string | null>(null)
const imageLoadFailed = ref(false)

function triggerFileInput() {
  fileInputRef.value?.click()
}

function handleFileChange(event: Event) {
  localError.value = null
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  // Validate type
  const allowed = ['image/jpeg', 'image/png', 'image/webp']
  if (!allowed.includes(file.type)) {
    localError.value = 'Formato no permitido. Por favor usa JPG, PNG o WebP.'
    return
  }

  // Validate size (max 2MB)
  if (file.size > 2 * 1024 * 1024) {
    localError.value = 'El archivo supera el límite de 2 MB.'
    return
  }

  emit('upload', file)
}
</script>

<template>
  <div class="flex flex-col items-center gap-3">
    <div class="relative group">
      <!-- Avatar Preview Container -->
      <div class="w-24 h-24 md:w-28 md:h-28 rounded-full bg-guaiqui-surface border-2 border-guaiqui-primary/30 overflow-hidden flex items-center justify-center text-3xl font-bold text-guaiqui-primary shadow-guaiqui-sm relative">
        <img
          v-if="avatarUrl && !imageLoadFailed"
          :src="avatarUrl"
          :alt="displayName || 'Avatar'"
          class="w-full h-full object-cover"
          referrerpolicy="no-referrer"
          @error="imageLoadFailed = true"
        />
        <span v-else>
          {{ displayName?.charAt(0).toUpperCase() || 'F' }}
        </span>

        <!-- Loading Overlay -->
        <div v-if="uploading" class="absolute inset-0 bg-white/80 flex items-center justify-center">
          <i class="bi bi-arrow-repeat animate-spin text-2xl text-guaiqui-primary"></i>
        </div>
      </div>

      <!-- Change Avatar Floating Action Button -->
      <button
        type="button"
        @click="triggerFileInput"
        :disabled="uploading"
        class="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-guaiqui-primary text-white flex items-center justify-center shadow-md hover:bg-guaiqui-primary-dark transition-all active:scale-95 disabled:opacity-50"
        title="Cambiar foto de perfil"
      >
        <i class="bi bi-camera-fill text-sm"></i>
      </button>

      <input
        ref="fileInputRef"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        class="hidden"
        @change="handleFileChange"
      />
    </div>

    <p v-if="localError" class="text-xs text-guaiqui-status-danger text-center flex items-center gap-1">
      <i class="bi bi-exclamation-circle-fill"></i>
      <span>{{ localError }}</span>
    </p>
    <p class="text-[11px] text-guaiqui-text-muted">
      Formatos aceptados: JPG, PNG, WebP (máx. 2 MB)
    </p>
  </div>
</template>
