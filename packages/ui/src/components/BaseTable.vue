<script setup lang="ts">
export interface TableColumn {
  key: string
  label: string
  align?: 'left' | 'center' | 'right'
  width?: string
}

interface Props {
  columns: TableColumn[]
  data: any[]
  loading?: boolean
  emptyText?: string
}

withDefaults(defineProps<Props>(), {
  columns: () => [],
  data: () => [],
  loading: false,
  emptyText: 'No hay datos disponibles',
})

</script>

<template>
  <div class="w-full overflow-x-auto rounded-guaiqui-lg border border-guaiqui-border bg-guaiqui-surface shadow-guaiqui-sm">
    <table class="w-full text-left border-collapse text-sm">
      <thead class="bg-guaiqui-surface-hover/30 border-b border-guaiqui-border text-xs uppercase tracking-wider text-guaiqui-text-muted font-bold">
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            :style="{ width: col.width }"
            :class="[
              'px-4 py-3 sm:px-6',
              col.align === 'center' ? 'text-center' : col.align === 'right' ? 'text-right' : 'text-left',
            ]"
          >
            {{ col.label }}
          </th>
        </tr>
      </thead>

      <tbody class="divide-y divide-guaiqui-border text-guaiqui-text font-body">
        <tr v-if="loading">
          <td :colspan="columns.length" class="px-4 py-8 text-center">
            <div class="flex items-center justify-center gap-3 text-guaiqui-text-muted">
              <svg class="animate-spin h-5 w-5 text-guaiqui-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
              </svg>
              <span>Cargando datos...</span>
            </div>
          </td>
        </tr>

        <tr v-else-if="!data || data.length === 0">
          <td :colspan="columns.length" class="px-4 py-8 text-center text-guaiqui-text-muted">
            <slot name="empty">
              {{ emptyText }}
            </slot>
          </td>
        </tr>

        <tr
          v-for="(row, rowIndex) in data"
          v-else
          :key="rowIndex"
          class="hover:bg-guaiqui-surface-hover/50 transition-colors duration-150"
        >
          <td
            v-for="col in columns"
            :key="col.key"
            :class="[
              'px-4 py-3.5 sm:px-6',
              col.align === 'center' ? 'text-center' : col.align === 'right' ? 'text-right' : 'text-left',
            ]"
          >
            <slot :name="`cell-${col.key}`" :row="row" :value="row[col.key]" :index="rowIndex">
              {{ row[col.key] }}
            </slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
