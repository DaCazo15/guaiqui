<script setup lang="ts">
import { useRouter } from 'vue-router'
import { BaseButton, BaseTable, BaseBadge } from '@guaiqui/ui'
import type { AnalyticsTopFan } from '@guaiqui/shared'
import { exportToCsv } from '../../lib/exportCsv'

const props = defineProps<{
  fans: AnalyticsTopFan[]
  loading: boolean
}>()

const router = useRouter()

const columns = [
  { key: 'rank', label: '#' },
  { key: 'display_name', label: 'Fanático' },
  { key: 'trivias_played', label: 'Trivias Jugadas', align: 'center' as const },
  { key: 'pearls_earned', label: 'Perlitas Ganadas', align: 'right' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const createTopFansSegment = () => {
  router.push({
    path: '/admin/segmentos',
    query: {
      create: 'true',
      segmentPreset: 'top_fans'
    }
  })
}

const downloadCsv = () => {
  exportToCsv('top_fanaticos_activos', props.fans, {
    display_name: 'Nombre para Mostrar',
    trivias_played: 'Trivias Jugadas',
    pearls_earned: 'Perlitas Ganadas'
  })
}
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <h3 class="text-lg font-bold text-white flex items-center gap-2">
          <i class="bi bi-trophy text-amber-400"></i>
          Fanáticos Más Activos (Strict Privacy: Sin Correos)
        </h3>
        <p class="text-xs text-slate-400">Fans con mayor volumen de trivias e ingresos de perlitas.</p>
      </div>

      <div class="flex items-center gap-2">
        <BaseButton variant="secondary" size="sm" @click="createTopFansSegment">
          <i class="bi bi-funnel mr-1"></i> Crear segmento con esto
        </BaseButton>
        <BaseButton variant="secondary" size="sm" @click="downloadCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>
    </div>

    <BaseTable :columns="columns" :data="fans" :loading="loading" empty-text="No hay fanáticos registrados en el ranking">
      <template #cell-rank="{ index }">
        <span class="font-mono text-xs font-bold text-slate-400">#{{ index + 1 }}</span>
      </template>

      <template #cell-display_name="{ row }">
        <div class="flex items-center gap-2.5">
          <img
            :src="(row as any).avatar_url || 'https://placehold.co/100x100?text=Guaiqueri'"
            class="w-7 h-7 rounded-full object-cover bg-slate-800 border border-slate-700"
          />
          <span class="font-semibold text-slate-100 text-sm">{{ (row as any).display_name }}</span>
        </div>
      </template>

      <template #cell-trivias_played="{ row }">
        <span class="font-mono tabular-nums text-slate-300">{{ (row as any).trivias_played }}</span>
      </template>

      <template #cell-pearls_earned="{ row }">
        <span class="font-mono tabular-nums text-emerald-400 font-bold">+{{ (row as any).pearls_earned.toLocaleString() }}</span>
      </template>

      <template #cell-actions="{ row }">
        <button
          @click="createTopFansSegment"
          class="text-xs text-emerald-400 hover:text-emerald-300 font-medium hover:underline flex items-center gap-1 justify-end ml-auto"
        >
          <i class="bi bi-funnel"></i> Segmentar
        </button>
      </template>
    </BaseTable>
  </div>
</template>
