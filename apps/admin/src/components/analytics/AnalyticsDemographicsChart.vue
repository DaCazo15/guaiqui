<script setup lang="ts">
import { ref, onMounted, watch, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { BaseButton, BaseTable } from '@guaiqui/ui'
import type { AnalyticsDemographics } from '@guaiqui/shared'
import { exportToCsv } from '../../lib/exportCsv'
import * as echarts from 'echarts/core'
import { PieChart } from 'echarts/charts'
import { TooltipComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([PieChart, TooltipComponent, LegendComponent, CanvasRenderer])

const props = defineProps<{
  demographics: AnalyticsDemographics | null
  loading: boolean
}>()

const router = useRouter()
const chartRef = ref<HTMLDivElement | null>(null)
let chartInstance: echarts.ECharts | null = null
const showTableView = ref(false)
const activeTab = ref<'municipality' | 'gender' | 'age'>('municipality')

const columns = [
  { key: 'name', label: 'Categoría' },
  { key: 'count', label: 'Cantidad de Fanáticos', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const getActiveData = () => {
  if (!props.demographics) return []
  if (activeTab.value === 'municipality') return props.demographics.by_municipality
  if (activeTab.value === 'gender') return props.demographics.by_gender
  return props.demographics.by_age_group
}

const initChart = () => {
  if (!chartRef.value) return
  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value)
  }

  const currentData = getActiveData()
  const pieData = currentData.map((d) => ({ name: d.name, value: d.count }))

  const option: echarts.EChartsCoreOption = {
    backgroundColor: 'transparent',
    tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
    legend: { orient: 'vertical', right: '5%', top: 'center', textStyle: { color: '#94a3b8' } },
    series: [
      {
        name: 'Demografía',
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['40%', '50%'],
        avoidLabelOverlap: true,
        itemStyle: { borderRadius: 8, borderColor: '#0f172a', borderWidth: 2 },
        label: { show: false },
        data: pieData
      }
    ]
  }

  chartInstance.setOption(option)
}

watch([() => props.demographics, activeTab], () => {
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

const createSegmentWithCategory = (categoryName: string) => {
  router.push({
    path: '/admin/segmentos',
    query: {
      create: 'true',
      categoryType: activeTab.value,
      categoryValue: categoryName
    }
  })
}

const downloadCsv = () => {
  exportToCsv(`demografia_${activeTab.value}`, getActiveData(), {
    name: 'Categoría',
    count: 'Fanáticos'
  })
}
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <h3 class="text-lg font-bold text-white">Demografía de Fanáticos (k=5 Protegido)</h3>
        <p class="text-xs text-slate-400">Distribución por municipio, género y grupo de edad. Grupos menores de 5 personas son suprimidos.</p>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="showTableView = !showTableView"
          class="px-3 py-1.5 text-xs font-semibold rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white transition-colors"
        >
          <i :class="['bi', showTableView ? 'bi-pie-chart-fill' : 'bi-table', 'mr-1']"></i>
          {{ showTableView ? 'Ver Gráfico' : 'Ver Tabla' }}
        </button>
        <BaseButton variant="secondary" size="sm" @click="downloadCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>
    </div>

    <!-- Sub-tabs -->
    <div class="flex items-center gap-2 border-b border-slate-800 pb-2 text-xs font-semibold">
      <button
        @click="activeTab = 'municipality'"
        :class="['px-3 py-1.5 rounded-lg transition-colors', activeTab === 'municipality' ? 'bg-emerald-600/20 text-emerald-400 border border-emerald-500/40' : 'text-slate-400 hover:text-white']"
      >
        Por Municipio
      </button>
      <button
        @click="activeTab = 'gender'"
        :class="['px-3 py-1.5 rounded-lg transition-colors', activeTab === 'gender' ? 'bg-emerald-600/20 text-emerald-400 border border-emerald-500/40' : 'text-slate-400 hover:text-white']"
      >
        Por Género
      </button>
      <button
        @click="activeTab = 'age'"
        :class="['px-3 py-1.5 rounded-lg transition-colors', activeTab === 'age' ? 'bg-emerald-600/20 text-emerald-400 border border-emerald-500/40' : 'text-slate-400 hover:text-white']"
      >
        Por Rango de Edad
      </button>
    </div>

    <!-- Chart Canvas Container -->
    <div v-show="!showTableView" ref="chartRef" class="w-full h-72"></div>

    <!-- Accessible Alternative Table View -->
    <div v-show="showTableView" class="pt-2">
      <BaseTable :columns="columns" :data="getActiveData()" :loading="loading" empty-text="Sin datos demográficos registrados">
        <template #cell-name="{ row }">
          <span class="font-semibold text-slate-200">{{ (row as any).name }}</span>
        </template>
        <template #cell-count="{ row }">
          <span class="font-mono tabular-nums text-emerald-400 font-bold">{{ (row as any).count }}</span>
        </template>
        <template #cell-actions="{ row }">
          <button
            @click="createSegmentWithCategory((row as any).name)"
            class="text-xs text-emerald-400 hover:text-emerald-300 font-medium hover:underline flex items-center gap-1 justify-end ml-auto"
            title="Crear un segmento automático con esta categoría precargada"
          >
            <i class="bi bi-funnel"></i> Crear segmento con esto
          </button>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
