<script setup lang="ts">
import { ref, onMounted, watch, onUnmounted } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { exportToCsv } from '../../lib/exportCsv'
import * as echarts from 'echarts/core'
import { HeatmapChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, VisualMapComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([HeatmapChart, GridComponent, TooltipComponent, VisualMapComponent, CanvasRenderer])

const props = defineProps<{
  matrixData: number[][] // [day_of_week (0-6), hour (0-23), count]
  loading: boolean
}>()

const chartRef = ref<HTMLDivElement | null>(null)
let chartInstance: echarts.ECharts | null = null
const showTableView = ref(false)

const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
const hours = Array.from({ length: 24 }, (_, i) => `${i}:00`)

const initChart = () => {
  if (!chartRef.value) return
  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value)
  }

  const maxVal = Math.max(...props.matrixData.map((item) => item[2] || 0), 10)

  const option: echarts.EChartsCoreOption = {
    backgroundColor: 'transparent',
    tooltip: { position: 'top' },
    grid: { height: '65%', top: '10%' },
    xAxis: { type: 'category', data: hours, splitArea: { show: true }, axisLabel: { color: '#94a3b8' } },
    yAxis: { type: 'category', data: days, splitArea: { show: true }, axisLabel: { color: '#94a3b8' } },
    visualMap: {
      min: 0,
      max: maxVal,
      calculable: true,
      orient: 'horizontal',
      left: 'center',
      bottom: '0%',
      inRange: { color: ['#0f172a', '#065f46', '#10b981', '#34d399', '#a7f3d0'] },
      textStyle: { color: '#94a3b8' }
    },
    series: [
      {
        name: 'Intento de Trivias',
        type: 'heatmap',
        data: props.matrixData,
        label: { show: false },
        emphasis: { itemStyle: { shadowBlur: 10, shadowColor: 'rgba(0, 0, 0, 0.5)' } }
      }
    ]
  }

  chartInstance.setOption(option)
}

watch(() => props.matrixData, () => {
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

const getCountForCell = (dIdx: number, hIdx: number) => {
  const match = props.matrixData.find((m) => m[0] === dIdx && m[1] === hIdx)
  return match ? match[2] : 0
}

const downloadCsv = () => {
  const exportRows = days.map((dayName, dIdx) => {
    const rowObj: Record<string, any> = { Dia: dayName }
    hours.forEach((hName, hIdx) => {
      rowObj[hName] = getCountForCell(dIdx, hIdx)
    })
    return rowObj
  })

  exportToCsv('mapa_calor_actividad', exportRows)
}
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div>
        <h3 class="text-lg font-bold text-white">Mapa de Calor de Actividad (Hora Caracas)</h3>
        <p class="text-xs text-slate-400">Concentración de intentos de trivias por día de la semana y hora del día.</p>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="showTableView = !showTableView"
          class="px-3 py-1.5 text-xs font-semibold rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white transition-colors"
        >
          <i :class="['bi', showTableView ? 'bi-grid-3x3-gap-fill' : 'bi-table', 'mr-1']"></i>
          {{ showTableView ? 'Ver Mapa de Calor' : 'Ver Matriz (Tabla)' }}
        </button>
        <BaseButton variant="secondary" size="sm" @click="downloadCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>
    </div>

    <!-- Chart Canvas Container -->
    <div v-show="!showTableView" ref="chartRef" class="w-full h-80"></div>

    <!-- Accessible Matrix Table View -->
    <div v-show="showTableView" class="overflow-x-auto pt-2">
      <table class="w-full text-xs text-left text-slate-300 border border-slate-800">
        <thead class="bg-slate-950 text-slate-400 font-mono">
          <tr>
            <th class="p-2 border border-slate-800">Día \ Hora</th>
            <th v-for="h in hours" :key="h" class="p-1 border border-slate-800 text-center">{{ h }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(dName, dIdx) in days" :key="dName" class="border-b border-slate-800 hover:bg-slate-800/50">
            <td class="p-2 font-bold text-slate-200 border border-slate-800">{{ dName }}</td>
            <td
              v-for="(_, hIdx) in hours"
              :key="hIdx"
              class="p-1 border border-slate-800 text-center font-mono tabular-nums"
              :class="[getCountForCell(dIdx, hIdx) > 0 ? 'bg-emerald-950/60 text-emerald-400 font-bold' : 'text-slate-600']"
            >
              {{ getCountForCell(dIdx, hIdx) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
