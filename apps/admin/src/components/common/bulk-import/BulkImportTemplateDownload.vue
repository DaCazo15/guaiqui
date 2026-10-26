<script setup lang="ts">
import { BaseButton, BaseBadge } from '@guaiqui/ui'
import type { BulkImportConfig } from '../../../lib/bulkImportConfig'
import { downloadTemplate } from '../../../lib/bulkImportConfig'

const props = defineProps<{
  config: BulkImportConfig
}>()
</script>

<template>
  <div class="rounded-xl border border-slate-700/60 bg-slate-800/40 p-4 space-y-3">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <h4 class="text-sm font-semibold text-white flex items-center gap-2">
          <i class="bi bi-file-earmark-spreadsheet text-emerald-400 text-base"></i>
          Paso 1: Descargar Plantilla Guía
        </h4>
        <p class="text-xs text-slate-300 mt-0.5">
          Descarga la plantilla con encabezados oficiales y ejemplos reales de Guaiqueríes para evitar errores.
        </p>
      </div>
      <div class="flex items-center gap-2 flex-wrap">
        <BaseButton
          size="sm"
          variant="secondary"
          @click="downloadTemplate(props.config.type, 'xlsx')"
        >
          <i class="bi bi-file-earmark-excel text-emerald-400 mr-1.5"></i>
          Plantilla Excel (.xlsx)
        </BaseButton>
        <BaseButton
          size="sm"
          variant="secondary"
          @click="downloadTemplate(props.config.type, 'csv')"
        >
          <i class="bi bi-file-earmark-text text-sky-400 mr-1.5"></i>
          Plantilla CSV (.csv)
        </BaseButton>
      </div>
    </div>

    <!-- Columns chips list -->
    <div class="pt-2 border-t border-slate-700/40 flex flex-wrap gap-1.5 items-center">
      <span class="text-[11px] font-medium text-slate-400 mr-1">Columnas esperadas:</span>
      <BaseBadge
        v-for="col in props.config.columns"
        :key="col.key"
        size="sm"
        :variant="col.required ? 'primary' : 'soft'"
        class="text-[10px]"
      >
        <i v-if="col.required" class="bi bi-asterisk text-[9px] mr-0.5 text-amber-300"></i>
        {{ col.label }}
      </BaseBadge>
    </div>
  </div>
</template>
