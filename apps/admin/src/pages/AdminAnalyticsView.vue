<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseInput } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

import AnalyticsOverviewCards from '../components/analytics/AnalyticsOverviewCards.vue'
import AnalyticsActiveUsersChart from '../components/analytics/AnalyticsActiveUsersChart.vue'
import AnalyticsDemographicsChart from '../components/analytics/AnalyticsDemographicsChart.vue'
import AnalyticsEngagementHeatmap from '../components/analytics/AnalyticsEngagementHeatmap.vue'
import AnalyticsEconomyPanel from '../components/analytics/AnalyticsEconomyPanel.vue'
import AnalyticsFunnelChart from '../components/analytics/AnalyticsFunnelChart.vue'
import AnalyticsTopFansTable from '../components/analytics/AnalyticsTopFansTable.vue'
import AnalyticsTriviasTable from '../components/analytics/AnalyticsTriviasTable.vue'
import AnalyticsProductsTable from '../components/analytics/AnalyticsProductsTable.vue'

import type {
  AnalyticsOverview,
  AnalyticsActiveUserPeriod,
  AnalyticsTopFan,
  AnalyticsTriviaSummary,
  AnalyticsProductSummary,
  AnalyticsDemographics,
  AnalyticsEconomy,
  AnalyticsFunnelStep
} from '@guaiqui/shared'

const loading = ref(true)
const errorMessage = ref<string | null>(null)

// Date Range Filter State
const datePreset = ref<'7d' | '30d' | 'month' | 'year' | 'custom'>('30d')
const startDate = ref('')
const endDate = ref('')

// Analytics Data States
const overviewData = ref<AnalyticsOverview | null>(null)
const activeUsersData = ref<AnalyticsActiveUserPeriod[]>([])
const topFansData = ref<AnalyticsTopFan[]>([])
const triviaSummaryData = ref<AnalyticsTriviaSummary | null>(null)
const productSummaryData = ref<AnalyticsProductSummary | null>(null)
const demographicsData = ref<AnalyticsDemographics | null>(null)
const engagementMatrixData = ref<number[][]>([])
const economyData = ref<AnalyticsEconomy | null>(null)
const funnelData = ref<AnalyticsFunnelStep[]>([])

const applyPreset = (preset: '7d' | '30d' | 'month' | 'year') => {
  datePreset.value = preset
  const now = new Date()

  if (preset === '7d') {
    const start = new Date(now)
    start.setDate(start.getDate() - 7)
    startDate.value = start.toISOString().slice(0, 10)
    endDate.value = now.toISOString().slice(0, 10)
  } else if (preset === '30d') {
    const start = new Date(now)
    start.setDate(start.getDate() - 30)
    startDate.value = start.toISOString().slice(0, 10)
    endDate.value = now.toISOString().slice(0, 10)
  } else if (preset === 'month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1)
    startDate.value = start.toISOString().slice(0, 10)
    endDate.value = now.toISOString().slice(0, 10)
  } else if (preset === 'year') {
    const start = new Date(now.getFullYear(), 0, 1)
    startDate.value = start.toISOString().slice(0, 10)
    endDate.value = now.toISOString().slice(0, 10)
  }

  loadAnalytics()
}

const loadAnalytics = async () => {
  loading.value = true
  errorMessage.value = null

  const sIso = startDate.value ? new Date(`${startDate.value}T00:00:00`).toISOString() : null
  const eIso = endDate.value ? new Date(`${endDate.value}T23:59:59`).toISOString() : null

  try {
    const [
      resOverview,
      resActive,
      resTopFans,
      resTrivias,
      resProducts,
      resDemographics,
      resHeatmap,
      resEconomy,
      resFunnel
    ] = await Promise.all([
      supabase.rpc('analytics_overview', { p_start_date: sIso, p_end_date: eIso }),
      supabase.rpc('analytics_active_users', { p_start_date: sIso, p_end_date: eIso, p_granularity: 'day' }),
      supabase.rpc('analytics_top_fans', { p_limit: 10, p_start_date: sIso, p_end_date: eIso }),
      supabase.rpc('analytics_trivias', { p_start_date: sIso, p_end_date: eIso }),
      supabase.rpc('analytics_products', { p_start_date: sIso, p_end_date: eIso }),
      supabase.rpc('analytics_demographics'),
      supabase.rpc('analytics_engagement_hours', { p_start_date: sIso, p_end_date: eIso }),
      supabase.rpc('analytics_economy'),
      supabase.rpc('analytics_funnel', { p_start_date: sIso, p_end_date: eIso })
    ])

    if (resOverview.error) throw resOverview.error
    overviewData.value = resOverview.data as AnalyticsOverview

    if (resActive.data) activeUsersData.value = resActive.data as AnalyticsActiveUserPeriod[]
    if (resTopFans.data) topFansData.value = resTopFans.data as AnalyticsTopFan[]
    if (resTrivias.data) triviaSummaryData.value = resTrivias.data as AnalyticsTriviaSummary
    if (resProducts.data) productSummaryData.value = resProducts.data as AnalyticsProductSummary
    if (resDemographics.data) demographicsData.value = resDemographics.data as AnalyticsDemographics
    if (resHeatmap.data) engagementMatrixData.value = resHeatmap.data as number[][]
    if (resEconomy.data) economyData.value = resEconomy.data as AnalyticsEconomy
    if (resFunnel.data) funnelData.value = resFunnel.data as AnalyticsFunnelStep[]
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar datos de analítica'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  applyPreset('30d')
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-8">
      <!-- Header & Date Range Bar -->
      <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Dashboard de Analítica & Métricas Club</h1>
          <p class="text-sm text-slate-400">Analítica oficial de fanáticos, consumo de perlitas, salud económica y rendimiento de trivias.</p>
        </div>

        <!-- Date Controls & Presets -->
        <div class="flex flex-wrap items-center gap-2 bg-slate-900 border border-slate-800 p-2 rounded-2xl">
          <button
            @click="applyPreset('7d')"
            :class="['px-3 py-1.5 text-xs font-semibold rounded-xl transition-colors', datePreset === '7d' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white']"
          >
            Últimos 7d
          </button>
          <button
            @click="applyPreset('30d')"
            :class="['px-3 py-1.5 text-xs font-semibold rounded-xl transition-colors', datePreset === '30d' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white']"
          >
            Últimos 30d
          </button>
          <button
            @click="applyPreset('month')"
            :class="['px-3 py-1.5 text-xs font-semibold rounded-xl transition-colors', datePreset === 'month' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white']"
          >
            Mes Actual
          </button>

          <div class="h-4 w-px bg-slate-800 mx-1 hidden sm:block"></div>

          <div class="flex items-center gap-2">
            <input
              type="date"
              v-model="startDate"
              class="bg-slate-950 border border-slate-700 text-slate-200 text-xs rounded-xl px-2.5 py-1 focus:outline-none focus:border-emerald-500"
            />
            <span class="text-xs text-slate-500">a</span>
            <input
              type="date"
              v-model="endDate"
              class="bg-slate-950 border border-slate-700 text-slate-200 text-xs rounded-xl px-2.5 py-1 focus:outline-none focus:border-emerald-500"
            />
            <BaseButton variant="primary" size="sm" :loading="loading" @click="datePreset = 'custom'; loadAnalytics()">
              Filtrar
            </BaseButton>
          </div>
        </div>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- 1. Overview Summary Cards -->
      <AnalyticsOverviewCards :overview="overviewData" :loading="loading" />

      <!-- 2. Active Users Chart & Economy Panel Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <AnalyticsActiveUsersChart :data="activeUsersData" :loading="loading" />
        <AnalyticsEconomyPanel :economy="economyData" :loading="loading" />
      </div>

      <!-- 3. Demographics & Funnel Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <AnalyticsDemographicsChart :demographics="demographicsData" :loading="loading" />
        <AnalyticsFunnelChart :funnel="funnelData" :loading="loading" />
      </div>

      <!-- 4. Engagement Heatmap -->
      <AnalyticsEngagementHeatmap :matrix-data="engagementMatrixData" :loading="loading" />

      <!-- 5. Top Fans & Products Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <AnalyticsTopFansTable :fans="topFansData" :loading="loading" />
        <AnalyticsProductsTable :product-summary="productSummaryData" :loading="loading" />
      </div>

      <!-- 6. Trivias & Hardest Questions Performance -->
      <AnalyticsTriviasTable :trivia-summary="triviaSummaryData" :loading="loading" />
    </div>
  </AdminLayout>
</template>
