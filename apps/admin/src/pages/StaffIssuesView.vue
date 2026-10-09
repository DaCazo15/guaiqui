<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import StaffLayout from '../components/layout/StaffLayout.vue'
import { supabase } from '../lib/supabase'

const issues = ref<any[]>([])
const isLoading = ref(true)

const fetchIssues = async () => {
  isLoading.value = true
  try {
    const { data, error } = await supabase.rpc('staff_redemption_queue', {
      p_status: 'issue',
      p_search: null,
      p_cursor: null,
      p_limit: 50
    })

    if (error) {
      console.error('Error fetching issues:', error)
      issues.value = []
    } else {
      issues.value = data || []
    }
  } finally {
    isLoading.value = false
  }
}

const resolveIssue = async (item: any) => {
  if (!confirm(`¿Re-aprobar el canje de ${item.fan_display_name} para reintentar la entrega?`)) return
  try {
    const { error } = await supabase.rpc('approve_redemption', {
      p_redemption_id: item.id
    })

    if (error) alert('Error al re-aprobar: ' + error.message)
    else await fetchIssues()
  } catch (err: any) {
    alert('Error al resolver incidencia: ' + err.message)
  }
}

onMounted(() => {
  fetchIssues()
})
</script>

<template>
  <StaffLayout>
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-white tracking-wide">Incidencias Reportadas</h1>
          <p class="text-xs text-slate-400">Canjes derivados por problemas de talla, inventario o discrepancia</p>
        </div>

        <button
          @click="fetchIssues"
          :disabled="isLoading"
          class="p-2 text-slate-300 hover:text-white bg-slate-900 border border-slate-800 rounded-xl"
        >
          <i :class="['bi bi-arrow-clockwise text-lg', isLoading ? 'animate-spin' : '']"></i>
        </button>
      </div>

      <div v-if="isLoading" class="p-12 text-center bg-slate-900 border border-slate-800 rounded-2xl">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-400 block mb-2"></i>
        <span class="text-xs text-slate-300">Cargando incidencias...</span>
      </div>

      <div v-else-if="issues.length === 0" class="p-12 text-center bg-slate-900 border border-slate-800 rounded-2xl text-slate-500">
        <i class="bi bi-check-circle text-4xl block mb-2 text-emerald-500/50"></i>
        <span class="text-sm font-medium">No existen incidencias pendientes en taquilla.</span>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="item in issues"
          :key="item.id"
          class="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-xl space-y-3"
        >
          <div class="flex items-center justify-between border-b border-slate-800 pb-3">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-slate-800 text-emerald-400 flex items-center justify-center font-bold text-xs">
                {{ (item.fan_display_name || 'F')[0] }}
              </div>
              <span class="font-bold text-sm text-white">{{ item.fan_display_name }}</span>
            </div>

            <span class="px-2.5 py-0.5 bg-purple-950 border border-purple-800 text-purple-300 rounded-full text-xs font-semibold">
              INCIDENCIA
            </span>
          </div>

          <div class="space-y-1 text-xs">
            <div class="text-slate-300 font-semibold">{{ item.product_name }}</div>
            <div class="text-slate-400">Variante: <span class="font-mono text-white">{{ item.variant || '-' }}</span></div>
            <div class="text-emerald-400 font-medium">{{ item.cost_pearls }} perlitas</div>
          </div>

          <div class="pt-3 border-t border-slate-800 flex items-center justify-between gap-2">
            <RouterLink
              :to="`/staff/canjes/${item.id}`"
              class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl"
            >
              Ver Trazabilidad
            </RouterLink>

            <button
              @click="resolveIssue(item)"
              class="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-xl"
            >
              Re-aprobar Canje
            </button>
          </div>
        </div>
      </div>
    </div>
  </StaffLayout>
</template>
