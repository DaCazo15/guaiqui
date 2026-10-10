<script setup lang="ts">
import { BaseCard, BaseButton, BaseBadge } from '@guaiqui/ui'
import type { LedgerItem } from '~/composables/useWallet'

defineProps<{
  entries: LedgerItem[]
  loading: boolean
  loadingMore: boolean
  hasMore: boolean
  currentFilter: string
}>()

const emit = defineEmits<{
  (e: 'filter-change', filter: string): void
  (e: 'load-more'): void
}>()

const filters = [
  { id: 'all', label: 'Todos' },
  { id: 'trivia_reward', label: 'Trivias' },
  { id: 'ad_reward', label: 'Anuncios' },
  { id: 'redemption', label: 'Canjes' },
  { id: 'refund', label: 'Reembolsos' },
  { id: 'bonus', label: 'Bonos' },
]

const formatDate = (dateStr: string) => {
  try {
    const d = new Date(dateStr)
    return d.toLocaleDateString('es-VE', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return dateStr
  }
}

const getEntryIcon = (type: string) => {
  switch (type) {
    case 'trivia_reward':
      return 'bi-patch-question-fill text-guaiqui-primary'
    case 'ad_reward':
      return 'bi-play-btn-fill text-purple-600'
    case 'redemption':
      return 'bi-bag-check-fill text-guaiqui-accent'
    case 'refund':
      return 'bi-arrow-counterclockwise text-emerald-600'
    case 'streak_bonus':
      return 'bi-lightning-charge-fill text-amber-500'
    case 'admin_adjustment':
      return 'bi-shield-check text-blue-600'
    default:
      return 'bi-gem text-amber-500'
  }
}
</script>

<template>
  <div class="space-y-4">
    <!-- Header & Filter Tabs -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <h2 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        Historial de Movimientos
      </h2>

      <!-- Filtros -->
      <div class="flex flex-wrap gap-1.5 bg-guaiqui-surface p-1 rounded-guaiqui-lg border border-guaiqui-border">
        <button
          v-for="f in filters"
          :key="f.id"
          type="button"
          :class="[
            'px-3 py-1 text-xs font-semibold rounded-guaiqui-md transition-all cursor-pointer',
            currentFilter === f.id
              ? 'bg-white text-guaiqui-primary shadow-xs font-bold'
              : 'text-guaiqui-text-muted hover:text-guaiqui-text',
          ]"
          @click="emit('filter-change', f.id)"
        >
          {{ f.label }}
        </button>
      </div>
    </div>

    <!-- Lista de Entradas -->
    <BaseCard class="p-0 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm overflow-hidden divide-y divide-guaiqui-border">
      <!-- Loading State Inicial -->
      <div v-if="loading && entries.length === 0" class="p-12 text-center text-guaiqui-text-muted space-y-3">
        <div class="inline-block animate-spin text-2xl text-guaiqui-primary">
          <i class="bi bi-arrow-repeat"></i>
        </div>
        <p class="text-sm font-medium">Cargando transacciones...</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="entries.length === 0" class="p-12 text-center text-guaiqui-text-muted space-y-2">
        <div class="w-12 h-12 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-2xl mx-auto">
          <i class="bi bi-inbox"></i>
        </div>
        <p class="text-sm font-semibold text-guaiqui-text">No hay movimientos registrados</p>
        <p class="text-xs text-guaiqui-text-muted">
          {{ currentFilter === 'all' ? 'Tus actividades y canjes se reflejarán aquí.' : 'No hay movimientos con este filtro.' }}
        </p>
      </div>

      <!-- Rows -->
      <div
        v-for="entry in entries"
        v-else
        :key="entry.id"
        class="p-4 sm:px-6 flex items-center justify-between hover:bg-guaiqui-surface/50 transition-colors"
      >
        <div class="flex items-center gap-3 min-w-0">
          <div class="w-10 h-10 rounded-full bg-guaiqui-surface flex items-center justify-center text-lg shrink-0">
            <i :class="['bi', getEntryIcon(entry.type)]"></i>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-guaiqui-text truncate">
              {{ entry.description }}
            </p>
            <div class="flex items-center gap-2 text-xs text-guaiqui-text-muted mt-0.5">
              <span>{{ formatDate(entry.created_at) }}</span>
              <span v-if="entry.status !== 'confirmed'">
                <BaseBadge variant="warning" size="sm">
                  {{ entry.status === 'pending' ? 'En revisión' : entry.status }}
                </BaseBadge>
              </span>
            </div>
          </div>
        </div>

        <!-- Monto -->
        <div class="text-right shrink-0 pl-3">
          <span
            :class="[
              'font-display font-bold text-lg',
              entry.amount > 0 ? 'text-guaiqui-primary' : 'text-guaiqui-accent',
            ]"
          >
            {{ entry.amount > 0 ? '+' : '' }}{{ entry.amount.toLocaleString('es-VE') }}
          </span>
          <span class="text-xs text-guaiqui-text-muted block font-medium">perlitas</span>
        </div>
      </div>

      <!-- Load More Footer -->
      <div v-if="hasMore && entries.length > 0" class="p-4 text-center bg-guaiqui-surface/40">
        <BaseButton
          variant="secondary"
          size="sm"
          :loading="loadingMore"
          :disabled="loadingMore"
          @click="emit('load-more')"
        >
          <i class="bi bi-chevron-down mr-1"></i>
          Ver más movimientos
        </BaseButton>
      </div>
    </BaseCard>
  </div>
</template>
