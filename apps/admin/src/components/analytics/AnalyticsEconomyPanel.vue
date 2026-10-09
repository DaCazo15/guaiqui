<script setup lang="ts">
import { BaseBadge } from '@guaiqui/ui'
import type { AnalyticsEconomy } from '@guaiqui/shared'

defineProps<{
  economy: AnalyticsEconomy | null
  loading: boolean
}>()
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-6">
    <div>
      <h3 class="text-lg font-bold text-white flex items-center gap-2">
        <i class="bi bi-bank text-amber-400"></i>
        Salud de la Economía Digital de Perlitas
      </h3>
      <p class="text-xs text-slate-400">Balance inmutable del libro contable y poder adquisitivo del fanático.</p>
    </div>

    <!-- Key Financial Metrics Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-1">
        <span class="text-xs text-slate-400">Total Emitidas (Histórico)</span>
        <div class="text-xl font-bold font-mono text-emerald-400 tabular-nums">
          +{{ loading || !economy ? '-' : economy.total_issued.toLocaleString() }}
        </div>
      </div>

      <div class="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-1">
        <span class="text-xs text-slate-400">Total Gastadas en Canjes</span>
        <div class="text-xl font-bold font-mono text-rose-400 tabular-nums">
          -{{ loading || !economy ? '-' : economy.total_spent.toLocaleString() }}
        </div>
      </div>

      <div class="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-1">
        <span class="text-xs text-slate-400">En Circulación (Billeteras)</span>
        <div class="text-xl font-bold font-mono text-amber-400 tabular-nums">
          {{ loading || !economy ? '-' : economy.total_in_circulation.toLocaleString() }}
        </div>
      </div>

      <div class="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-1">
        <span class="text-xs text-slate-400">Retenidas (En verificación)</span>
        <div class="text-xl font-bold font-mono text-sky-400 tabular-nums">
          {{ loading || !economy ? '-' : economy.total_held.toLocaleString() }}
        </div>
      </div>
    </div>

    <!-- Health Indicator & Purchase Effort -->
    <div class="p-4 bg-slate-950/80 border border-slate-800 rounded-xl space-y-3">
      <h4 class="text-xs font-bold uppercase tracking-wider text-slate-300">
        Indicador de Esfuerzo de Juego (Poder Adquisitivo Fanático)
      </h4>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="flex items-center justify-between p-3 bg-slate-900 border border-slate-800 rounded-lg">
          <div>
            <span class="text-xs text-slate-400">Producto Más Barato</span>
            <p class="font-bold text-slate-200 font-mono">{{ economy?.cheapest_product_cost ?? 0 }} perlitas</p>
          </div>
          <BaseBadge variant="success" size="md">
            ~{{ economy?.days_needed_for_cheapest ?? 0 }} días de juego
          </BaseBadge>
        </div>

        <div class="flex items-center justify-between p-3 bg-slate-900 border border-slate-800 rounded-lg">
          <div>
            <span class="text-xs text-slate-400">Producto Más Caro</span>
            <p class="font-bold text-slate-200 font-mono">{{ economy?.most_expensive_product_cost ?? 0 }} perlitas</p>
          </div>
          <BaseBadge variant="perlita" size="md">
            ~{{ economy?.days_needed_for_most_expensive ?? 0 }} días de juego
          </BaseBadge>
        </div>
      </div>
    </div>
  </div>
</template>
