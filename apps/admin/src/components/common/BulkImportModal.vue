<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { BaseModal, BaseButton } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import {
  BULK_CONFIGS,
  parseSpreadsheetFile,
  type BulkImportType
} from '../../lib/bulkImportConfig'
import BulkImportTemplateDownload from './bulk-import/BulkImportTemplateDownload.vue'
import BulkImportFileDrop from './bulk-import/BulkImportFileDrop.vue'
import BulkImportPreviewTable from './bulk-import/BulkImportPreviewTable.vue'

const props = defineProps<{
  isOpen: boolean
  type: BulkImportType
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'success'): void
}>()

const config = computed(() => BULK_CONFIGS[props.type])

const selectedFile = ref<File | null>(null)
const parsedRows = ref<Record<string, any>[]>([])
const parsing = ref(false)
const importing = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Reset state when modal opens or closes
watch(() => props.isOpen, (open) => {
  if (open) {
    selectedFile.value = null
    parsedRows.value = []
    errorMessage.value = null
    successMessage.value = null
    parsing.value = false
    importing.value = false
  }
})

const onFileSelected = async (file: File) => {
  selectedFile.value = file
  errorMessage.value = null
  successMessage.value = null
  parsing.value = true

  try {
    const rows = await parseSpreadsheetFile(file)
    if (!rows || rows.length === 0) {
      errorMessage.value = 'El archivo está vacío o no tiene filas válidas con datos.'
      parsedRows.value = []
    } else {
      parsedRows.value = rows
    }
  } catch (err: any) {
    errorMessage.value = `Error al procesar el archivo: ${err.message || 'Formato no legible'}`
    parsedRows.value = []
  } finally {
    parsing.value = false
  }
}

const onFileCleared = () => {
  selectedFile.value = null
  parsedRows.value = []
  errorMessage.value = null
  successMessage.value = null
}

const validRows = computed(() => {
  if (!config.value || parsedRows.value.length === 0) return []
  return parsedRows.value.filter((row, idx) => config.value.validateRow(row, idx).valid)
})

const executeImport = async () => {
  if (!config.value || validRows.value.length === 0) return

  importing.value = true
  errorMessage.value = null
  successMessage.value = null

  try {
    const result = await config.value.processRows(validRows.value, supabase)
    successMessage.value = result.message || `${result.successCount} registros importados con éxito.`

    setTimeout(() => {
      emit('success')
      emit('close')
    }, 1200)
  } catch (err: any) {
    errorMessage.value = `Error en la importación: ${err.message || 'Error de base de datos'}`
  } finally {
    importing.value = false
  }
}
</script>

<template>
  <BaseModal
    :is-open="props.isOpen"
    size="xl"
    :title="config?.title || 'Carga Masiva de Datos'"
    @close="emit('close')"
  >
    <div v-if="config" class="space-y-5 py-1">
      <!-- Success Banner -->
      <div
        v-if="successMessage"
        class="p-4 rounded-xl border border-emerald-500/50 bg-emerald-950/40 text-emerald-300 text-sm flex items-center gap-3 animate-fade-in"
      >
        <i class="bi bi-check-circle-fill text-emerald-400 text-lg"></i>
        <span>{{ successMessage }}</span>
      </div>

      <!-- Error Banner -->
      <div
        v-if="errorMessage"
        class="p-4 rounded-xl border border-red-500/50 bg-red-950/40 text-red-300 text-sm flex items-center gap-3 animate-fade-in"
      >
        <i class="bi bi-exclamation-octagon-fill text-red-400 text-lg"></i>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Step 1: Template Download -->
      <BulkImportTemplateDownload :config="config" />

      <!-- Step 2: File Drop & Select -->
      <BulkImportFileDrop
        :selected-file="selectedFile"
        :loading="parsing || importing"
        @file-selected="onFileSelected"
        @file-cleared="onFileCleared"
      />

      <!-- Parsing Spinner -->
      <div v-if="parsing" class="py-6 text-center text-slate-400 text-sm">
        <i class="bi bi-arrow-repeat animate-spin text-emerald-400 text-2xl mb-2 inline-block"></i>
        <p>Analizando archivo de hoja de cálculo...</p>
      </div>

      <!-- Step 3: Preview and Validation -->
      <BulkImportPreviewTable
        v-if="!parsing && parsedRows.length > 0"
        :config="config"
        :parsed-rows="parsedRows"
      />
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full">
        <div class="text-xs text-slate-400">
          <span v-if="parsedRows.length > 0 && validRows.length > 0">
            Listo para importar <strong>{{ validRows.length }}</strong> de {{ parsedRows.length }} filas
          </span>
        </div>
        <div class="flex items-center gap-3">
          <BaseButton
            variant="ghost"
            :disabled="importing"
            @click="emit('close')"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            variant="primary"
            :loading="importing"
            :disabled="validRows.length === 0 || importing || !!successMessage"
            @click="executeImport"
          >
            <i class="bi bi-cloud-arrow-up-fill mr-2"></i>
            {{ importing ? 'Importando...' : `Importar ${validRows.length} ${config?.entityName || 'Registros'}` }}
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>
