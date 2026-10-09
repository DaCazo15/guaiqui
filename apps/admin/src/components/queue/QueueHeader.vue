<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  activeTab: string
  searchQuery: string
  isRealtimeConnected: boolean
  isLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'update:activeTab', tab: string): void
  (e: 'update:searchQuery', query: string): void
  (e: 'refresh'): void
}>()

const tabs = [
  { key: 'all', label: 'Todos' },
  { key: 'pending', label: 'Pendientes' },
  { key: 'approved', label: 'Aprobados' },
  { key: 'scheduled', label: 'Agendados' },
  { key: 'delivered', label: 'Entregados' },
  { key: 'completed', label: 'Completados' },
  { key: 'issue', label: 'Incidencias' },
  { key: 'rejected', label: 'Rechazados' },
]

const currentSearch = computed({
  get: () => props.searchQuery,
  set: (val: string) => emit('update:searchQuery', val)
})
</script>

<template>
  <div class="space-y-4 mb-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-white tracking-wide">Cola de Canjes</h1>
        <p class="text-xs text-slate-400">Gestión e inspección de solicitudes de canje de la fanaticada</p>
      </div>

      <div class="flex items-center gap-3">
        <!-- Realtime status pill -->
        <span
          :class="[
            'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono border',
            isRealtimeConnected
              ? 'bg-emerald-950/60 text-emerald-400 border-emerald-800'
              : 'bg-amber-950/60 text-amber-400 border-amber-800'
          ]"
        >
          <span :class="['w-2 h-2 rounded-full', isRealtimeConnected ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400']"></span>
          {{ isRealtimeConnected ? 'En vivo' : 'Desconectado' }}
        </span>

        <button
          @click="emit('refresh')"
          :disabled="isLoading"
          class="p-2 text-slate-300 hover:text-white bg-slate-900 hover:bg-slate-800 border border-slate-800 rounded-xl transition-all"
          title="Actualizar cola"
        >
          <i :class="['bi bi-arrow-clockwise text-lg', isLoading ? 'animate-spin text-emerald-400' : '']"></i>
        </button>
      </div>
    </div>

    <!-- Filter tabs & search -->
    <div class="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 bg-slate-900/60 p-2 rounded-2xl border border-slate-800">
      <div class="flex items-center gap-1 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
        <button
          v-for="t in tabs"
          :key="t.key"
          @click="emit('update:activeTab', t.key)"
          :class="[
            'px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all',
            activeTab === t.key
              ? 'bg-emerald-600 text-white shadow-xs'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
          ]"
        >
          {{ t.label }}
        </button>
      </div>

      <div class="relative w-full md:w-64">
        <span class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
          <i class="bi bi-search"></i>
        </span>

        <input
          v-model="currentSearch"
          type="text"
          placeholder="Buscar por fan o premio..."
          class="w-full pl-9 pr-3 py-1.5 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
        />
      </div>
    </div>
  </div>
</template>
