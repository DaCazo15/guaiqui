<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  selectedFile: File | null
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'file-selected', file: File): void
  (e: 'file-cleared'): void
}>()

const isDragging = ref(false)
const fileInputRef = ref<HTMLInputElement | null>(null)

const onDragOver = (e: DragEvent) => {
  e.preventDefault()
  isDragging.value = true
}

const onDragLeave = () => {
  isDragging.value = false
}

const onDrop = (e: DragEvent) => {
  e.preventDefault()
  isDragging.value = false
  if (props.loading) return

  const files = e.dataTransfer?.files
  if (files && files.length > 0) {
    handleFile(files[0])
  }
}

const onInputChange = (e: Event) => {
  const target = e.target as HTMLInputElement
  if (target.files && target.files.length > 0) {
    handleFile(target.files[0])
  }
}

const handleFile = (file: File) => {
  const ext = file.name.split('.').pop()?.toLowerCase()
  if (!['xlsx', 'xls', 'csv'].includes(ext || '')) {
    alert('Por favor selecciona un archivo de hoja de cálculo válido (.xlsx, .xls o .csv).')
    return
  }
  emit('file-selected', file)
}

const triggerFileInput = () => {
  fileInputRef.value?.click()
}

const clearFile = () => {
  if (fileInputRef.value) fileInputRef.value.value = ''
  emit('file-cleared')
}

const formatSize = (bytes: number) => {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}
</script>

<template>
  <div class="space-y-2">
    <div class="flex items-center justify-between">
      <h4 class="text-sm font-semibold text-white flex items-center gap-2">
        <i class="bi bi-cloud-arrow-up text-emerald-400 text-base"></i>
        Paso 2: Subir Archivo Relleno (.xlsx o .csv)
      </h4>
      <span v-if="props.selectedFile" class="text-xs text-slate-400">
        {{ formatSize(props.selectedFile.size) }}
      </span>
    </div>

    <!-- Hidden native input -->
    <input
      ref="fileInputRef"
      type="file"
      accept=".xlsx, .xls, .csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel, text/csv"
      class="hidden"
      @change="onInputChange"
    />

    <!-- When file is already selected -->
    <div
      v-if="props.selectedFile"
      class="flex items-center justify-between p-3.5 rounded-xl border border-emerald-500/40 bg-emerald-950/20 text-emerald-100"
    >
      <div class="flex items-center gap-3 min-w-0">
        <div class="w-10 h-10 rounded-lg bg-emerald-500/20 flex items-center justify-center shrink-0">
          <i class="bi bi-file-earmark-check text-emerald-400 text-xl"></i>
        </div>
        <div class="min-w-0">
          <p class="text-sm font-semibold text-white truncate">{{ props.selectedFile.name }}</p>
          <p class="text-xs text-emerald-300/80">Archivo listo para previsualizar y validar</p>
        </div>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <button
          type="button"
          class="px-2.5 py-1 text-xs font-medium text-slate-300 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-lg transition-colors"
          :disabled="props.loading"
          @click="triggerFileInput"
        >
          <i class="bi bi-arrow-repeat mr-1"></i> Cambiar
        </button>
        <button
          type="button"
          class="p-1.5 text-slate-400 hover:text-red-400 transition-colors rounded-lg"
          :disabled="props.loading"
          title="Quitar archivo"
          @click="clearFile"
        >
          <i class="bi bi-trash3 text-sm"></i>
        </button>
      </div>
    </div>

    <!-- Drag & Drop Zone -->
    <div
      v-else
      class="border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-200"
      :class="[
        isDragging
          ? 'border-emerald-400 bg-emerald-950/30 ring-2 ring-emerald-500/20'
          : 'border-slate-700 hover:border-emerald-500/60 bg-slate-800/20 hover:bg-slate-800/50'
      ]"
      @dragover="onDragOver"
      @dragleave="onDragLeave"
      @drop="onDrop"
      @click="triggerFileInput"
    >
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-800 flex items-center justify-center text-emerald-400 mb-2">
        <i class="bi bi-cloud-arrow-up-fill text-2xl"></i>
      </div>
      <p class="text-sm font-medium text-white">
        Arrastra tu archivo aquí o <span class="text-emerald-400 underline decoration-dotted">explora tus archivos</span>
      </p>
      <p class="text-xs text-slate-400 mt-1">
        Formatos compatibles: Microsoft Excel (.xlsx, .xls) y CSV (.csv)
      </p>
    </div>
  </div>
</template>
