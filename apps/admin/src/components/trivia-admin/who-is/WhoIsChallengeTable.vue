<script setup lang="ts">
import { BaseTable, BaseBadge } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { WhoIsRow } from './types'

defineProps<{
  challenges: WhoIsRow[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'edit', row: WhoIsRow): void
  (e: 'delete', row: WhoIsRow): void
}>()

const columns = [
  { key: 'challenge', label: 'Reto & Jugador' },
  { key: 'type', label: 'Modo', align: 'center' as const },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'dates', label: 'Vigencia' },
  { key: 'rewards', label: 'Recompensa', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]
</script>

<template>
  <BaseTable :columns="columns" :data="challenges" :loading="loading">
    <template #cell-challenge="{ row }">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-center overflow-hidden shrink-0">
          <img
            v-if="(row as WhoIsRow).player?.photo_url"
            :src="(row as WhoIsRow).player!.photo_url!"
            :alt="(row as WhoIsRow).player?.name"
            class="w-full h-full object-cover"
          />
          <i v-else class="bi bi-person-fill text-slate-500"></i>
        </div>
        <div class="flex flex-col">
          <span class="font-bold text-white text-sm">{{ (row as WhoIsRow).title }}</span>
          <span class="text-xs text-slate-400">
            Jugador: <strong class="text-emerald-400">{{ (row as WhoIsRow).player?.name || 'Desconocido' }}</strong>
            (#{{ (row as WhoIsRow).player?.jersey_number ?? (row as WhoIsRow).dorsal_number ?? '?' }})
          </span>
          <span v-if="(row as WhoIsRow).clue" class="text-[11px] text-slate-500 italic mt-0.5">
            Pista: "{{ (row as WhoIsRow).clue }}"
          </span>
        </div>
      </div>
    </template>

    <template #cell-type="{ row }">
      <span
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold"
        :class="(row as WhoIsRow).challenge_type === 'silhouette'
          ? 'bg-purple-950/60 text-purple-300 border border-purple-800/60'
          : 'bg-emerald-950/60 text-emerald-300 border border-emerald-800/60'"
      >
        <i :class="['bi', (row as WhoIsRow).challenge_type === 'silhouette' ? 'bi-incognito' : 'bi-123']"></i>
        {{ (row as WhoIsRow).challenge_type === 'silhouette' ? 'Silueta' : 'Dorsal' }}
      </span>
    </template>

    <template #cell-status="{ row }">
      <BaseBadge :variant="(row as WhoIsRow).status === 'published' ? 'success' : (row as WhoIsRow).status === 'draft' ? 'warning' : 'soft'">
        {{ (row as WhoIsRow).status === 'published' ? 'Publicado' : (row as WhoIsRow).status === 'draft' ? 'Borrador' : 'Archivado' }}
      </BaseBadge>
    </template>

    <template #cell-dates="{ row }">
      <div class="flex flex-col text-xs text-slate-400">
        <span><span class="text-slate-500">Inicio:</span> {{ (row as WhoIsRow).starts_at ? formatCaracas((row as WhoIsRow).starts_at) : '' }}</span>
        <span><span class="text-slate-500">Cierre:</span> {{ (row as WhoIsRow).ends_at ? formatCaracas((row as WhoIsRow).ends_at) : '' }}</span>
      </div>
    </template>

    <template #cell-rewards="{ row }">
      <span class="text-xs font-mono font-bold text-emerald-400 bg-emerald-950/40 px-2 py-1 rounded-md border border-emerald-800/40">
        +{{ (row as WhoIsRow).reward_pearls }} perlitas
      </span>
    </template>

    <template #cell-actions="{ row }">
      <div class="flex items-center justify-end gap-1.5">
        <button @click="emit('edit', row as WhoIsRow)" class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar Reto">
          <i class="bi bi-pencil"></i>
        </button>
        <button @click="emit('delete', row as WhoIsRow)" class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors" title="Eliminar Reto">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </template>
  </BaseTable>
</template>
