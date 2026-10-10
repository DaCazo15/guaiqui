<script setup lang="ts">
import { RouterLink } from 'vue-router'

defineProps<{
  items: any[]
  isLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'approve', item: any): void
  (e: 'reject', item: any): void
  (e: 'deliver', item: any): void
}>()

const getStatusBadge = (status: string) => {
  switch (status) {
    case 'pending':
      return { class: 'bg-amber-950/80 text-amber-300 border-amber-800', label: 'Pendiente' }
    case 'approved':
      return { class: 'bg-emerald-950/80 text-emerald-300 border-emerald-800', label: 'Aprobado' }
    case 'scheduled':
      return { class: 'bg-blue-950/80 text-blue-300 border-blue-800', label: 'Agendado' }
    case 'delivered':
      return { class: 'bg-teal-950/80 text-teal-300 border-teal-800', label: 'Entregado' }
    case 'completed':
      return { class: 'bg-emerald-900/40 text-emerald-400 border-emerald-700', label: 'Completado' }
    case 'rejected':
      return { class: 'bg-red-950/80 text-red-300 border-red-800', label: 'Rechazado' }
    case 'issue':
      return { class: 'bg-purple-950/80 text-purple-300 border-purple-800', label: 'Incidencia' }
    default:
      return { class: 'bg-slate-800 text-slate-400 border-slate-700', label: status }
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('es-VE', {
    dateStyle: 'short',
    timeStyle: 'short'
  })
}
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
    <div v-if="isLoading" class="p-12 text-center text-slate-400">
      <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-400 block mb-2"></i>
      <span class="text-sm">Cargando cola de canjes...</span>
    </div>

    <div v-else-if="items.length === 0" class="p-12 text-center text-slate-500">
      <i class="bi bi-inbox text-4xl block mb-2 text-slate-600"></i>
      <span class="text-sm font-medium">No se encontraron solicitudes en la cola.</span>
    </div>

    <div v-else class="overflow-x-auto">
      <table class="w-full text-left text-xs text-slate-300">
        <thead class="bg-slate-950/80 text-slate-400 uppercase tracking-wider font-semibold border-b border-slate-800">
          <tr>
            <th class="py-3.5 px-4">Fanático</th>
            <th class="py-3.5 px-4">Producto / Canje</th>
            <th class="py-3.5 px-4 text-center">Variante</th>
            <th class="py-3.5 px-4 text-center">Perlitas</th>
            <th class="py-3.5 px-4 text-center">Estado</th>
            <th class="py-3.5 px-4">Fecha</th>
            <th class="py-3.5 px-4 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-800/60">
          <tr v-for="item in items" :key="item.id" class="hover:bg-slate-800/40 transition-colors">
            <td class="py-3 px-4 font-medium text-white">
              <div class="flex items-center gap-2.5">
                <div class="w-7 h-7 rounded-full bg-slate-800 border border-slate-700 text-emerald-400 flex items-center justify-center font-bold text-xs">
                  {{ (item.fan_display_name || 'F')[0] }}
                </div>
                <span>{{ item.fan_display_name }}</span>
              </div>
            </td>

            <td class="py-3 px-4 font-medium text-slate-200">
              {{ item.product_name }}
            </td>

            <td class="py-3 px-4 text-center font-mono text-slate-400">
              {{ item.variant || '-' }}
            </td>

            <td class="py-3 px-4 text-center font-semibold text-emerald-400">
              {{ item.cost_pearls }} <i class="bi bi-gem text-xs text-emerald-400 ms-0.5"></i>
            </td>

            <td class="py-3 px-4 text-center">
              <span
                :class="[
                  'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border',
                  getStatusBadge(item.status).class
                ]"
              >
                {{ getStatusBadge(item.status).label }}
              </span>
            </td>

            <td class="py-3 px-4 text-slate-400 font-mono text-[11px]">
              {{ formatDate(item.created_at) }}
            </td>

            <td class="py-3 px-4 text-right space-x-1.5">
              <button
                v-if="item.status === 'pending'"
                @click="emit('approve', item)"
                class="px-2.5 py-1 text-[11px] font-semibold bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg transition-colors"
              >
                Aprobar
              </button>

              <button
                v-if="item.status === 'pending'"
                @click="emit('reject', item)"
                class="px-2.5 py-1 text-[11px] font-semibold bg-red-950/60 hover:bg-red-900 border border-red-800 text-red-300 rounded-lg transition-colors"
              >
                Rechazar
              </button>

              <button
                v-if="item.status === 'approved' || item.status === 'scheduled'"
                @click="emit('deliver', item)"
                class="px-2.5 py-1 text-[11px] font-semibold bg-teal-600 hover:bg-teal-500 text-white rounded-lg transition-colors"
              >
                Entregar
              </button>

              <RouterLink
                :to="`/staff/canjes/${item.id}`"
                class="px-2 py-1 text-[11px] font-medium bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg transition-colors inline-block"
                title="Ver detalles"
              >
                <i class="bi bi-eye"></i>
              </RouterLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
