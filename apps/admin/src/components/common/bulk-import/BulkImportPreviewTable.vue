<script setup lang="ts">
import { computed } from 'vue'
import { BaseBadge } from '@guaiqui/ui'
import type { BulkImportConfig } from '../../../lib/bulkImportConfig'

interface RowValidationResult {
  row: Record<string, any>
  index: number
  valid: boolean
  errors: string[]
}

const props = defineProps<{
  config: BulkImportConfig
  parsedRows: Record<string, any>[]
}>()

const validations = computed<RowValidationResult[]>(() => {
  return props.parsedRows.map((row, index) => {
    const res = props.config.validateRow(row, index)
    return {
      row,
      index,
      valid: res.valid,
      errors: res.errors
    }
  })
})

const validCount = computed(() => validations.value.filter(v => v.valid).length)
const invalidCount = computed(() => validations.value.filter(v => !v.valid).length)
const allErrors = computed(() => validations.value.flatMap(v => v.errors))

// Visible columns (first 4-5 columns to avoid extreme table width in preview)
const previewColumns = computed(() => props.config.columns.slice(0, 5))
</script>

<template>
  <div class="space-y-3">
    <!-- Header with statistics -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-xl bg-slate-800/60 border border-slate-700/60">
      <div>
        <h4 class="text-sm font-semibold text-white flex items-center gap-2">
          <i class="bi bi-eye text-emerald-400"></i>
          Paso 3: Vista Previa y Validación
        </h4>
        <p class="text-xs text-slate-300 mt-0.5">
          Se han detectado {{ props.parsedRows.length }} registros en el archivo cargado.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <BaseBadge variant="success" size="sm" class="flex items-center gap-1">
          <i class="bi bi-check-circle-fill"></i>
          {{ validCount }} válidos
        </BaseBadge>
        <BaseBadge
          v-if="invalidCount > 0"
          variant="danger"
          size="sm"
          class="flex items-center gap-1"
        >
          <i class="bi bi-exclamation-triangle-fill"></i>
          {{ invalidCount }} con errores
        </BaseBadge>
      </div>
    </div>

    <!-- Error list if any -->
    <div
      v-if="invalidCount > 0"
      class="p-3.5 rounded-xl border border-red-500/40 bg-red-950/20 text-red-200 space-y-1.5 max-h-36 overflow-y-auto"
    >
      <div class="flex items-center gap-2 text-xs font-semibold text-red-400">
        <i class="bi bi-x-circle-fill"></i>
        Errores detectados en {{ invalidCount }} fila(s):
      </div>
      <ul class="text-xs space-y-1 list-disc list-inside text-red-300/90">
        <li v-for="(err, idx) in allErrors.slice(0, 8)" :key="idx">
          {{ err }}
        </li>
        <li v-if="allErrors.length > 8" class="text-slate-400 italic">
          ... y {{ allErrors.length - 8 }} error(es) más.
        </li>
      </ul>
    </div>

    <!-- Preview Table -->
    <div class="rounded-xl border border-slate-700/60 overflow-hidden bg-slate-900/60 max-h-60 overflow-y-auto">
      <table class="w-full text-left text-xs text-slate-300">
        <thead class="bg-slate-800 text-[11px] font-semibold uppercase tracking-wider text-slate-400 sticky top-0 z-10">
          <tr>
            <th class="py-2.5 px-3 w-12 text-center">#</th>
            <th class="py-2.5 px-3 w-20 text-center">Estado</th>
            <th
              v-for="col in previewColumns"
              :key="col.key"
              class="py-2.5 px-3"
            >
              {{ col.label }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-800 font-mono text-[11px]">
          <tr
            v-for="item in validations.slice(0, 10)"
            :key="item.index"
            class="hover:bg-slate-800/40 transition-colors"
            :class="!item.valid ? 'bg-red-950/10' : ''"
          >
            <td class="py-2 px-3 text-center text-slate-400 font-sans">
              {{ item.index + 1 }}
            </td>
            <td class="py-2 px-3 text-center">
              <span
                v-if="item.valid"
                class="inline-flex items-center gap-1 text-[10px] text-emerald-400 font-sans font-medium"
              >
                <i class="bi bi-check-circle"></i> OK
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 text-[10px] text-red-400 font-sans font-medium"
                :title="item.errors.join(' | ')"
              >
                <i class="bi bi-exclamation-circle"></i> Error
              </span>
            </td>
            <td
              v-for="col in previewColumns"
              :key="col.key"
              class="py-2 px-3 truncate max-w-[150px]"
            >
              {{ item.row[col.key] || '—' }}
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="validations.length > 10" class="p-2 text-center text-[11px] text-slate-400 border-t border-slate-800 bg-slate-800/30">
        Mostrando los primeros 10 de {{ validations.length }} registros
      </div>
    </div>
  </div>
</template>
