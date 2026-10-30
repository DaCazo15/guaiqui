<script setup lang="ts">
import { BaseButton } from '@guaiqui/ui'

defineProps<{
  totalCount: number
  activeCount: number
  currentBillingCount: number
  expiringOrExpiredCount: number
  search: string
  statusFilter: string
  billingFilter: string
}>()

const emit = defineEmits<{
  (e: 'update:search', val: string): void
  (e: 'update:statusFilter', val: string): void
  (e: 'update:billingFilter', val: string): void
  (e: 'openCreateModal'): void
  (e: 'refresh'): void
}>()
</script>

<template>
  <div class="space-y-6">
    <!-- Header title and CTA -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
      <div>
        <div class="flex items-center gap-2">
          <span class="px-2.5 py-0.5 text-xs font-mono font-bold bg-amber-950/80 text-amber-400 border border-amber-800 rounded-full">
            Plataforma Master
          </span>
          <h1 class="text-2xl font-bold font-title text-white tracking-wide">Gestión de Clubes & Equipos</h1>
        </div>
        <p class="text-xs sm:text-sm text-slate-400 mt-1">
          Administración centralizada de franquicias, altas con invitación a directivos, cobros y estatus de servicio.
        </p>
      </div>

      <div class="flex items-center gap-2.5">
        <BaseButton
          variant="secondary"
          size="sm"
          class="!bg-slate-800 !text-slate-200 !border-slate-700 hover:!bg-slate-700"
          @click="emit('refresh')"
        >
          <i class="bi bi-arrow-clockwise mr-1"></i> Actualizar
        </BaseButton>
        <BaseButton
          variant="primary"
          size="sm"
          class="!bg-emerald-600 hover:!bg-emerald-500 !text-white font-semibold shadow-lg shadow-emerald-950/50"
          @click="emit('openCreateModal')"
        >
          <i class="bi bi-plus-lg mr-1.5"></i> Alta de Nuevo Equipo
        </BaseButton>
      </div>
    </div>

    <!-- KPI Summary Cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4">
      <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
        <div class="text-xs font-medium text-slate-400 flex items-center gap-1.5">
          <i class="bi bi-shield-shaded text-slate-400"></i> Total Franquicias
        </div>
        <div class="text-2xl font-bold text-white mt-1 font-mono">{{ totalCount }}</div>
      </div>

      <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
        <div class="text-xs font-medium text-emerald-400 flex items-center gap-1.5">
          <i class="bi bi-check-circle-fill text-emerald-400"></i> Equipos Activos
        </div>
        <div class="text-2xl font-bold text-emerald-400 mt-1 font-mono">{{ activeCount }}</div>
      </div>

      <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
        <div class="text-xs font-medium text-blue-400 flex items-center gap-1.5">
          <i class="bi bi-credit-card-fill text-blue-400"></i> Pagos Al Día
        </div>
        <div class="text-2xl font-bold text-blue-400 mt-1 font-mono">{{ currentBillingCount }}</div>
      </div>

      <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
        <div class="text-xs font-medium text-amber-400 flex items-center gap-1.5">
          <i class="bi bi-exclamation-triangle-fill text-amber-400"></i> Vencidos / Por Vencer
        </div>
        <div class="text-2xl font-bold text-amber-400 mt-1 font-mono">{{ expiringOrExpiredCount }}</div>
      </div>
    </div>

    <!-- Filters & Search Toolbar -->
    <div class="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 p-3 bg-slate-850/80 border border-slate-800 rounded-xl">
      <div class="relative flex-1 max-w-md">
        <i class="bi bi-search absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-xs pointer-events-none"></i>
        <input
          type="text"
          :value="search"
          placeholder="Buscar por nombre o slug..."
          class="w-full bg-slate-900 border border-slate-700/80 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
          @input="emit('update:search', ($event.target as HTMLInputElement).value)"
        />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <!-- Status Filter -->
        <select
          :value="statusFilter"
          class="bg-slate-900 border border-slate-700/80 rounded-lg px-2.5 py-1.5 text-xs text-slate-300 focus:outline-none focus:ring-1 focus:ring-emerald-500"
          @change="emit('update:statusFilter', ($event.target as HTMLSelectElement).value)"
        >
          <option value="all">Estatus: Todos</option>
          <option value="active">Solo Activos</option>
          <option value="inactive">Solo Inactivos</option>
        </select>

        <!-- Billing Filter -->
        <select
          :value="billingFilter"
          class="bg-slate-900 border border-slate-700/80 rounded-lg px-2.5 py-1.5 text-xs text-slate-300 focus:outline-none focus:ring-1 focus:ring-emerald-500"
          @change="emit('update:billingFilter', ($event.target as HTMLSelectElement).value)"
        >
          <option value="all">Pagos: Todos</option>
          <option value="current">Al Día</option>
          <option value="expiring_soon">Por Vencer (≤ 7 días)</option>
          <option value="expired">Vencidos</option>
          <option value="no_payment">Sin Pago Registrado</option>
        </select>
      </div>
    </div>
  </div>
</template>
