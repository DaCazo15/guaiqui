<script setup lang="ts">
import { BaseTable, BaseBadge } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { PollRow } from './types'

defineProps<{
  polls: PollRow[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'resolve', poll: PollRow): void
  (e: 'edit', poll: PollRow): void
  (e: 'delete', poll: PollRow): void
}>()

const columns = [
  { key: 'title', label: 'Encuesta / Pregunta' },
  { key: 'game', label: 'Partido Asociado' },
  { key: 'options_preview', label: 'Opciones' },
  { key: 'closes_at', label: 'Cierre de Votación' },
  { key: 'reward_pearls', label: 'Premio', align: 'center' as const },
  { key: 'status_badge', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const },
]

const getPollStatusDisplay = (poll: PollRow) => {
  const now = new Date().toISOString()
  if (poll.status === 'resolved') {
    return { label: 'Resuelta', variant: 'success' as const, icon: 'bi-check-all' }
  }
  if (poll.status === 'draft') {
    return { label: 'Borrador', variant: 'soft' as const, icon: 'bi-pencil-square' }
  }
  if (poll.status === 'cancelled') {
    return { label: 'Cancelada', variant: 'danger' as const, icon: 'bi-x-circle' }
  }
  if (poll.closes_at && now > poll.closes_at) {
    return { label: 'Votación Cerrada', variant: 'warning' as const, icon: 'bi-clock-history' }
  }
  return { label: 'Activa', variant: 'success' as const, icon: 'bi-broadcast' }
}
</script>

<template>
  <BaseTable
    :columns="columns"
    :data="(polls as any[])"
    :loading="loading"
    empty-text="No hay encuestas ni predicciones creadas. Haz clic en 'Nueva Encuesta' para crear la primera."
  >
    <!-- Title Cell -->
    <template #cell-title="{ row }">
      <div class="space-y-1 py-1">
        <div class="font-bold text-white text-sm flex items-center gap-2">
          <span>{{ (row as PollRow).title }}</span>
          <span v-if="(row as PollRow).status === 'resolved'" class="text-[10px] bg-emerald-500/20 text-emerald-300 px-1.5 py-0.5 rounded border border-emerald-500/30">
            <i class="bi bi-trophy-fill mr-1 text-amber-400"></i>Resuelta
          </span>
        </div>
        <p v-if="(row as PollRow).description" class="text-xs text-slate-400 line-clamp-1">
          {{ (row as PollRow).description }}
        </p>
      </div>
    </template>

    <!-- Game Cell -->
    <template #cell-game="{ row }">
      <div v-if="(row as PollRow).game" class="text-xs">
        <span class="font-medium text-slate-200">vs {{ (row as PollRow).game?.opponent }}</span>
        <div class="text-[11px] text-slate-400 font-mono">
          {{ formatCaracas((row as PollRow).game!.game_date) }}
        </div>
      </div>
      <span v-else class="text-xs text-slate-500 italic">General / Sin partido</span>
    </template>

    <!-- Options Preview Cell -->
    <template #cell-options_preview="{ row }">
      <div class="space-y-1">
        <div class="flex flex-wrap gap-1 max-w-xs">
          <span
            v-for="opt in (row as PollRow).options?.slice(0, 3)"
            :key="opt.id || opt.label"
            class="text-[11px] px-2 py-0.5 rounded-full border"
            :class="opt.id === (row as PollRow).correct_option_id
              ? 'bg-emerald-950/80 text-emerald-300 border-emerald-500 font-bold'
              : 'bg-slate-800 text-slate-300 border-slate-700'"
          >
            <i v-if="opt.id === (row as PollRow).correct_option_id" class="bi bi-check-circle-fill text-emerald-400 mr-1"></i>
            {{ opt.label }} ({{ opt.votes_count || 0 }})
          </span>
          <span v-if="((row as PollRow).options?.length || 0) > 3" class="text-[10px] text-slate-400 self-center">
            +{{ ((row as PollRow).options?.length || 0) - 3 }} más
          </span>
        </div>
        <div class="text-[10px] text-slate-400">
          Total votos: <span class="font-semibold text-white">{{ (row as PollRow).total_votes || 0 }}</span>
        </div>
      </div>
    </template>

    <!-- Closes At Cell -->
    <template #cell-closes_at="{ row }">
      <div class="text-xs font-mono text-slate-300">
        {{ formatCaracas((row as PollRow).closes_at) }}
      </div>
    </template>

    <!-- Reward Cell -->
    <template #cell-reward_pearls="{ row }">
      <div class="flex items-center justify-center gap-1 font-bold font-mono text-emerald-400 text-xs">
        <i class="bi bi-circle-fill text-[8px] text-emerald-400"></i>
        <span>+{{ (row as PollRow).reward_pearls }}</span>
      </div>
    </template>

    <!-- Status Badge Cell -->
    <template #cell-status_badge="{ row }">
      <BaseBadge :variant="getPollStatusDisplay(row as PollRow).variant" size="sm" class="flex items-center gap-1 whitespace-nowrap">
        <i :class="['bi', getPollStatusDisplay(row as PollRow).icon]"></i>
        <span>{{ getPollStatusDisplay(row as PollRow).label }}</span>
      </BaseBadge>
    </template>

    <!-- Actions Cell -->
    <template #cell-actions="{ row }">
      <div class="flex items-center justify-end gap-1.5">
        <button
          v-if="(row as PollRow).status !== 'resolved'"
          @click="emit('resolve', row as PollRow)"
          class="px-2.5 py-1 text-xs font-semibold rounded-lg bg-emerald-950/70 border border-emerald-600/60 text-emerald-300 hover:bg-emerald-900 transition-colors flex items-center gap-1"
          title="Resolver encuesta y entregar premios"
        >
          <i class="bi bi-trophy"></i>
          <span>Resolver</span>
        </button>
        <button
          @click="emit('edit', row as PollRow)"
          class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
          title="Editar encuesta"
        >
          <i class="bi bi-pencil"></i>
        </button>
        <button
          @click="emit('delete', row as PollRow)"
          class="p-1.5 text-red-400 hover:bg-red-950/60 rounded-lg transition-colors"
          title="Eliminar encuesta"
        >
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </template>
  </BaseTable>
</template>
