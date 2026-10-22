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
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 tracking-wide font-title">Incidencias Reportadas</h1>
          <p class="text-xs text-slate-600">Canjes derivados por problemas de talla, inventario o discrepancia</p>
        </div>

        <button
          @click="fetchIssues"
          :disabled="isLoading"
          class="p-2 text-slate-600 hover:text-slate-900 bg-white border border-slate-200 rounded-xl shadow-xs"
        >
          <i :class="['bi bi-arrow-clockwise text-lg', isLoading ? 'animate-spin' : '']"></i>
        </button>
      </div>

      <div v-if="isLoading" class="p-12 text-center bg-white border border-slate-200 rounded-2xl shadow-xs">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-600 block mb-2"></i>
        <span class="text-xs text-slate-600">Cargando incidencias...</span>
      </div>

      <div v-else-if="issues.length === 0" class="p-12 text-center bg-white border border-slate-200 rounded-2xl text-slate-500 shadow-xs">
        <i class="bi bi-check-circle text-4xl block mb-2 text-emerald-600/50"></i>
        <span class="text-sm font-medium">No existen incidencias pendientes en taquilla.</span>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="item in issues"
          :key="item.id"
          class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs space-y-3"
        >
          <div class="flex items-center justify-between border-b border-slate-100 pb-3">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-slate-100 text-emerald-700 flex items-center justify-center font-bold text-xs border border-slate-200">
                {{ (item.fan_display_name || 'F')[0] }}
              </div>
              <span class="font-bold text-sm text-slate-900">{{ item.fan_display_name }}</span>
            </div>

            <span class="px-2.5 py-0.5 bg-purple-50 border border-purple-200 text-purple-800 rounded-full text-xs font-semibold">
              INCIDENCIA
            </span>
          </div>

          <div class="space-y-1 text-xs">
            <div class="text-slate-800 font-semibold">{{ item.product_name }}</div>
            <div class="text-slate-500">Variante: <span class="font-mono text-slate-900">{{ item.variant || '-' }}</span></div>
            <div class="text-emerald-700 font-medium">{{ item.cost_pearls }} perlitas</div>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
            <RouterLink
              :to="`/staff/canjes/${item.id}`"
              class="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-xl transition-colors"
            >
              Ver Trazabilidad
            </RouterLink>

            <button
              @click="resolveIssue(item)"
              class="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-xl transition-colors"
            >
              Re-aprobar Canje
            </button>
          </div>
        </div>
      </div>
    </div>
  </StaffLayout>
</template>
