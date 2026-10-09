<script setup lang="ts">
import { BaseBadge } from '@guaiqui/ui'
import type { AnalyticsOverview } from '@guaiqui/shared'

defineProps<{
  overview: AnalyticsOverview | null
  loading: boolean
}>()
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
    <!-- Card 1: DAU / WAU / MAU -->
    <div class="p-5 bg-slate-900 border border-slate-800 rounded-2xl flex flex-col justify-between space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Usuarios Activos</span>
        <i class="bi bi-people text-emerald-400 text-lg"></i>
      </div>
      <div>
        <div class="text-3xl font-bold font-title text-white font-mono tabular-nums">
          {{ loading || !overview ? '-' : overview.dau }}
        </div>
        <p class="text-xs text-slate-400 mt-1 flex items-center gap-2">
          <span>WAU: <strong class="text-slate-200 font-mono">{{ overview?.wau ?? '-' }}</strong></span>
          <span>•</span>
          <span>MAU: <strong class="text-slate-200 font-mono">{{ overview?.mau ?? '-' }}</strong></span>
        </p>
      </div>
      <BaseBadge variant="success" size="sm" class="self-start">Actividad En Vivo</BaseBadge>
    </div>

    <!-- Card 2: Nuevos Registros -->
    <div class="p-5 bg-slate-900 border border-slate-800 rounded-2xl flex flex-col justify-between space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Nuevos Registros</span>
        <i class="bi bi-person-plus text-sky-400 text-lg"></i>
      </div>
      <div>
        <div class="text-3xl font-bold font-title text-white font-mono tabular-nums">
          {{ loading || !overview ? '-' : overview.new_registrations }}
        </div>
        <p class="text-xs text-slate-400 mt-1">Fanáticos unidos en el período</p>
      </div>
      <BaseBadge variant="info" size="sm" class="self-start">Comunidad</BaseBadge>
    </div>

    <!-- Card 3: Perlitas Emitidas vs Gastadas -->
    <div class="p-5 bg-slate-900 border border-slate-800 rounded-2xl flex flex-col justify-between space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Flujo de Perlitas</span>
        <i class="bi bi-coin text-amber-400 text-lg"></i>
      </div>
      <div>
        <div class="text-2xl font-bold font-title text-emerald-400 font-mono tabular-nums">
          +{{ loading || !overview ? '-' : overview.pearls_issued.toLocaleString() }}
        </div>
        <p class="text-xs text-rose-400 font-mono tabular-nums mt-0.5">
          -{{ loading || !overview ? '-' : overview.pearls_spent.toLocaleString() }} gastadas
        </p>
      </div>
      <BaseBadge variant="perlita" size="sm" class="self-start">Economía Club</BaseBadge>
    </div>

    <!-- Card 4: Tiempo Promedio de Entrega -->
    <div class="p-5 bg-slate-900 border border-slate-800 rounded-2xl flex flex-col justify-between space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Tiempo Entrega Canje</span>
        <i class="bi bi-clock-history text-purple-400 text-lg"></i>
      </div>
      <div>
        <div class="text-3xl font-bold font-title text-white font-mono tabular-nums">
          {{ loading || !overview ? '-' : overview.avg_fulfillment_hours }} h
        </div>
        <p class="text-xs text-slate-400 mt-1">De aprobación a entrega física</p>
      </div>
      <BaseBadge variant="soft" size="sm" class="self-start">Logística Staff</BaseBadge>
    </div>
  </div>
</template>
