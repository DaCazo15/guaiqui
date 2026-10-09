<script setup lang="ts">
import { ref, onMounted, watch, onUnmounted } from 'vue'
import { BaseButton, BaseTable } from '@guaiqui/ui'
import type { AnalyticsActiveUserPeriod } from '@guaiqui/shared'
import { exportToCsv } from '../../lib/exportCsv'
import * as echarts from 'echarts/core'
import { LineChart, BarChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([LineChart, BarChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer])

const props = defineProps<{
  data: AnalyticsActiveUserPeriod[]
  loading: boolean
}>()

const chartRef = ref<HTMLDivElement | null>(null)
let chartInstance: echarts.ECharts | null = null
const showTableView = ref(false)

const columns = [
  { key: 'period', label: 'Fecha / Período' },
  { key: 'active_users', label: 'Usuarios Activos', align: 'center' as const },
  { key: 'new_registrations', label: 'Nuevos Registros', align: 'center' as const }
]

const initChart = () => {
  if (!chartRef.value) return
  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value)
  }

  const periods = props.data.map((d) => d.period)
  const activeUsers = props.data.map((d) => d.active_users)
  const newRegs = props.data.map((d) => d.new_registrations)

  const option: echarts.EChartsCoreOption = {
    backgroundColor: 'transparent',
    tooltip: { trigger: 'axis' },
    legend: { textStyle: { color: '#94a3b8' } },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: {
      type: 'category',
      data: periods,
      axisLine: { lineStyle: { color: '#334155' } },
      axisLabel: { color: '#94a3b8' }
    },
    yAxis: {
      type: 'value',
      axisLine: { lineStyle: { color: '#334155' } },
      splitLine: { lineStyle: { color: '#1e293b' } },
      axisLabel: { color: '#94a3b8' }
    },
    series: [
      {
        name: 'Usuarios Activos',
        type: 'line',
        smooth: true,
        data: activeUsers,
        itemStyle: { color: '#10b981' },
        lineStyle: { width: 3 }
      },
      {
        name: 'Nuevos Registros',
        type: 'bar',
        data: newRegs,
        itemStyle: { color: '#0284c7' }
      }
    ]
  }

  chartInstance.setOption(option)
}

watch(() => props.data, () => {
  if (!showTableView.value) {
    initChart()
  }
}, { deep: true })

onMounted(() => {
  window.addEventListener('resize', handleResize)
  setTimeout(initChart, 100)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  chartInstance?.dispose()
})

const handleResize = () => chartInstance?.resize()

const downloadCsv = () => {
  exportToCsv('usuarios_activos', props.data, {
    period: 'Fecha',
    active_users: 'Usuarios Activos',
    new_registrations: 'Nuevos Registros'
  })
}
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <h3 class="text-lg font-bold text-white">Evolución de Usuarios Activos y Registros</h3>
        <p class="text-xs text-slate-400">Tendencia de participación diaria/semanal en la plataforma.</p>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="showTableView = !showTableView"
          class="px-3 py-1.5 text-xs font-semibold rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white transition-colors"
        >
          <i :class="['bi', showTableView ? 'bi-graph-up' : 'bi-table', 'mr-1']"></i>
          {{ showTableView ? 'Ver Gráfico' : 'Ver Tabla (Accesibilidad)' }}
        </button>
        <BaseButton variant="secondary" size="sm" @click="downloadCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>
    </div>

    <!-- Chart Canvas Container -->
    <div v-show="!showTableView" ref="chartRef" class="w-full h-72"></div>

    <!-- Accessible Alternative Table View -->
    <div v-show="showTableView" class="pt-2">
      <BaseTable :columns="columns" :data="data" :loading="loading" empty-text="No hay datos registrados en este período">
        <template #cell-period="{ row }">
          <span class="font-mono text-xs text-slate-300">{{ (row as any).period }}</span>
        </template>
        <template #cell-active_users="{ row }">
          <span class="font-mono tabular-nums text-emerald-400 font-bold">{{ (row as any).active_users }}</span>
        </template>
        <template #cell-new_registrations="{ row }">
          <span class="font-mono tabular-nums text-sky-400 font-bold">{{ (row as any).new_registrations }}</span>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
