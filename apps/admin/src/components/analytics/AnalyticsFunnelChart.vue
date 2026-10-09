<script setup lang="ts">
import { BaseBadge, BaseTable } from '@guaiqui/ui'
import type { AnalyticsFunnelStep } from '@guaiqui/shared'

defineProps<{
  funnel: AnalyticsFunnelStep[]
  loading: boolean
}>()

const columns = [
  { key: 'step', label: 'Paso' },
  { key: 'name', label: 'Etapa del Embudo' },
  { key: 'count', label: 'Usuarios', align: 'center' as const },
  { key: 'conversion_rate', label: 'Tasa de Conversión', align: 'right' as const }
]
</script>

<template>
  <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
    <div>
      <h3 class="text-lg font-bold text-white flex items-center gap-2">
        <i class="bi bi-funnel text-sky-400"></i>
        Embudo de Conversión de Fanáticos
      </h3>
      <p class="text-xs text-slate-400">Paso a paso desde el registro inicial hasta el primer canje exitoso.</p>
    </div>

    <!-- Visual Funnel Step Progress Cards -->
    <div class="space-y-3">
      <div
        v-for="item in funnel"
        :key="item.step"
        class="p-4 bg-slate-950 border border-slate-800 rounded-xl flex items-center justify-between gap-4"
      >
        <div class="flex items-center gap-3">
          <span class="w-8 h-8 rounded-full bg-slate-900 border border-slate-700 flex items-center justify-center font-bold text-slate-200 text-sm font-mono">
            {{ item.step }}
          </span>
          <div>
            <h4 class="font-bold text-slate-200 text-sm">{{ item.name }}</h4>
            <span class="text-xs text-slate-400 font-mono tabular-nums">{{ item.count }} fanáticos</span>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <!-- Step bar visualization -->
          <div class="hidden sm:block w-32 bg-slate-900 rounded-full h-2.5 overflow-hidden border border-slate-800">
            <div
              class="bg-gradient-to-r from-emerald-500 to-sky-500 h-full transition-all duration-300"
              :style="{ width: `${item.conversion_rate}%` }"
            ></div>
          </div>
          <BaseBadge :variant="item.conversion_rate >= 50 ? 'success' : item.conversion_rate >= 20 ? 'info' : 'warning'" size="md">
            {{ item.conversion_rate }}%
          </BaseBadge>
        </div>
      </div>
    </div>
  </div>
</template>
