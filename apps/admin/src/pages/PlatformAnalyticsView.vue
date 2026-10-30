<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface TeamBreakdown {
  team_id: string
  team_name: string
  team_slug: string
  status: string
  sport: string
  followers: number
  active_staff: number
  pearls_issued: number
  pearls_redeemed: number
  redemptions_count: number
}

interface TrendDay {
  date: string
  pearls_issued: number
  pearls_redeemed: number
}

interface PlatformAnalyticsData {
  total_teams: number
  active_teams: number
  total_fans: number
  total_pearls_issued: number
  total_pearls_redeemed: number
  teams: TeamBreakdown[]
  trend_30d: TrendDay[]
}

const analytics = ref<PlatformAnalyticsData | null>(null)
const loading = ref(true)
const errorMessage = ref<string | null>(null)

const fetchAnalytics = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_get_platform_analytics')
    if (error) throw error
    analytics.value = data as PlatformAnalyticsData
  } catch (err: any) {
    errorMessage.value = err.message || 'Error cargando analítica de plataforma'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchAnalytics()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
        <div>
          <div class="flex items-center gap-2">
            <span class="px-2.5 py-0.5 text-xs font-mono font-bold bg-amber-950/80 text-amber-400 border border-amber-800 rounded-full">
              Plataforma Master
            </span>
            <h1 class="text-2xl font-bold font-title text-white tracking-wide">Analítica Global Cross-Team</h1>
          </div>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Métricas consolidadas de emisión y canje de perlitas, seguidores por franquicia y adopción multi-equipo.
          </p>
        </div>

        <BaseButton
          variant="secondary"
          size="sm"
          class="!bg-slate-800 !text-slate-200 !border-slate-700 hover:!bg-slate-700"
          @click="fetchAnalytics"
        >
          <i class="bi bi-arrow-clockwise mr-1"></i> Actualizar
        </BaseButton>
      </div>

      <!-- Error State -->
      <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-xs">
        {{ errorMessage }}
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="p-16 text-center text-slate-400 bg-slate-850 border border-slate-800 rounded-xl">
        <i class="bi bi-arrow-repeat animate-spin text-3xl text-emerald-500 mb-2 inline-block"></i>
        <p class="text-xs">Consolidando métricas de todos los clubes...</p>
      </div>

      <template v-else-if="analytics">
        <!-- KPI Cards Grid -->
        <div class="grid grid-cols-2 md:grid-cols-5 gap-3 sm:gap-4">
          <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
            <div class="text-xs text-slate-400 flex items-center gap-1.5 font-medium">
              <i class="bi bi-shield-shaded text-slate-400"></i> Clubes Activos
            </div>
            <div class="text-2xl font-bold text-white mt-1 font-mono">
              {{ analytics.active_teams }} <span class="text-xs text-slate-500 font-normal">/ {{ analytics.total_teams }}</span>
            </div>
          </div>

          <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
            <div class="text-xs text-slate-400 flex items-center gap-1.5 font-medium">
              <i class="bi bi-people-fill text-slate-400"></i> Fanáticos Activos
            </div>
            <div class="text-2xl font-bold text-slate-200 mt-1 font-mono">
              {{ analytics.total_fans.toLocaleString() }}
            </div>
          </div>

          <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
            <div class="text-xs text-emerald-400 flex items-center gap-1.5 font-medium">
              <i class="bi bi-coin text-emerald-400"></i> Perlitas Emitidas
            </div>
            <div class="text-2xl font-bold text-emerald-400 mt-1 font-mono">
              {{ analytics.total_pearls_issued.toLocaleString() }}
            </div>
          </div>

          <div class="p-4 rounded-xl bg-slate-850 border border-slate-800">
            <div class="text-xs text-purple-400 flex items-center gap-1.5 font-medium">
              <i class="bi bi-gift-fill text-purple-400"></i> Perlitas Canjeadas
            </div>
            <div class="text-2xl font-bold text-purple-400 mt-1 font-mono">
              {{ analytics.total_pearls_redeemed.toLocaleString() }}
            </div>
          </div>

          <div class="p-4 rounded-xl bg-slate-850 border border-slate-800 col-span-2 md:col-span-1">
            <div class="text-xs text-blue-400 flex items-center gap-1.5 font-medium">
              <i class="bi bi-percent text-blue-400"></i> Tasa de Canje
            </div>
            <div class="text-2xl font-bold text-blue-400 mt-1 font-mono">
              {{ analytics.total_pearls_issued > 0 ? ((analytics.total_pearls_redeemed / analytics.total_pearls_issued) * 100).toFixed(1) : '0.0' }}%
            </div>
          </div>
        </div>

        <!-- Cross-Team Breakdown Table -->
        <div class="bg-slate-850 border border-slate-800 rounded-xl overflow-hidden shadow-sm">
          <div class="p-4 border-b border-slate-800 flex items-center justify-between">
            <h3 class="text-sm font-bold text-white flex items-center gap-2">
              <i class="bi bi-table text-emerald-400"></i> Comparativa por Club
            </h3>
            <span class="text-xs text-slate-400 font-mono">{{ analytics.teams.length }} equipos registrados</span>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left border-collapse text-xs">
              <thead>
                <tr class="border-b border-slate-800 bg-slate-900/60 text-slate-400 font-semibold uppercase tracking-wider">
                  <th class="py-3 px-4">Club</th>
                  <th class="py-3 px-4">Deporte</th>
                  <th class="py-3 px-4">Estado</th>
                  <th class="py-3 px-4 text-center">Seguidores</th>
                  <th class="py-3 px-4 text-center">Staff Activo</th>
                  <th class="py-3 px-4 text-right">Perlitas Emitidas</th>
                  <th class="py-3 px-4 text-right">Perlitas Canjeadas</th>
                  <th class="py-3 px-4 text-center">Canjes</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-800 text-slate-300">
                <tr v-for="team in analytics.teams" :key="team.team_id" class="hover:bg-slate-800/40">
                  <td class="py-3 px-4 font-semibold text-white">
                    {{ team.team_name }}
                    <span class="text-[11px] text-slate-500 font-normal font-mono block">slug: {{ team.team_slug }}</span>
                  </td>
                  <td class="py-3 px-4 capitalize">{{ team.sport }}</td>
                  <td class="py-3 px-4">
                    <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold uppercase', team.status === 'active' ? 'bg-emerald-950/80 text-emerald-400 border border-emerald-800' : 'bg-red-950/80 text-red-400 border border-red-800']">
                      {{ team.status }}
                    </span>
                  </td>
                  <td class="py-3 px-4 text-center font-mono font-semibold">{{ team.followers.toLocaleString() }}</td>
                  <td class="py-3 px-4 text-center font-mono">{{ team.active_staff }}</td>
                  <td class="py-3 px-4 text-right font-mono text-emerald-400 font-semibold">{{ team.pearls_issued.toLocaleString() }}</td>
                  <td class="py-3 px-4 text-right font-mono text-purple-400 font-semibold">{{ team.pearls_redeemed.toLocaleString() }}</td>
                  <td class="py-3 px-4 text-center font-mono">{{ team.redemptions_count }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- 30-Day Activity Trend -->
        <div class="bg-slate-850 border border-slate-800 rounded-xl p-4 space-y-3">
          <h3 class="text-sm font-bold text-white flex items-center gap-2">
            <i class="bi bi-graph-up text-blue-400"></i> Tendencia de Actividad (Últimos 30 días)
          </h3>
          <div class="max-h-60 overflow-y-auto">
            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2">
              <div
                v-for="day in analytics.trend_30d.slice().reverse()"
                :key="day.date"
                class="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-[11px]"
              >
                <div class="font-mono text-slate-400 text-[10px]">{{ day.date }}</div>
                <div class="text-emerald-400 font-mono font-semibold mt-1">
                  +{{ day.pearls_issued.toLocaleString() }}
                </div>
                <div class="text-purple-400 font-mono text-[10px]">
                  -{{ day.pearls_redeemed.toLocaleString() }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
  </AdminLayout>
</template>
