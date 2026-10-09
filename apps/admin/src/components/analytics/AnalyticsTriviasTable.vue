<script setup lang="ts">
import { BaseButton, BaseTable, BaseBadge } from '@guaiqui/ui'
import type { AnalyticsTriviaSummary } from '@guaiqui/shared'
import { exportToCsv } from '../../lib/exportCsv'

const props = defineProps<{
  triviaSummary: AnalyticsTriviaSummary | null
  loading: boolean
}>()

const popularColumns = [
  { key: 'title', label: 'Título de Trivia' },
  { key: 'attempts_count', label: 'Intentos', align: 'center' as const },
  { key: 'avg_score', label: 'Puntaje Promedio', align: 'center' as const },
  { key: 'completion_rate', label: '% Finalización', align: 'right' as const }
]

const hardestColumns = [
  { key: 'trivia_title', label: 'Trivia' },
  { key: 'question_text', label: 'Pregunta Difícil' },
  { key: 'total_answers', label: 'Respuestas', align: 'center' as const },
  { key: 'correct_rate', label: '% Aciertos', align: 'right' as const }
]

const downloadPopularCsv = () => {
  if (!props.triviaSummary) return
  exportToCsv('trivias_populares', props.triviaSummary.popular_trivias, {
    title: 'Título',
    attempts_count: 'Intentos',
    avg_score: 'Puntaje Promedio',
    completion_rate: 'Tasa Finalización %'
  })
}

const downloadHardestCsv = () => {
  if (!props.triviaSummary) return
  exportToCsv('preguntas_dificiles', props.triviaSummary.hardest_questions, {
    trivia_title: 'Trivia',
    question_text: 'Pregunta',
    total_answers: 'Respuestas Totales',
    correct_rate: 'Tasa Aciertos %'
  })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Section 1: Popular Trivias -->
    <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-question-circle text-emerald-400"></i>
            Rendimiento de Trivias
          </h3>
          <p class="text-xs text-slate-400">Participación, promedios de puntaje y tasa de completitud.</p>
        </div>
        <BaseButton variant="secondary" size="sm" @click="downloadPopularCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>

      <BaseTable
        :columns="popularColumns"
        :data="triviaSummary?.popular_trivias || []"
        :loading="loading"
        empty-text="Sin trivias registradas en este período"
      >
        <template #cell-title="{ row }">
          <span class="font-semibold text-slate-100">{{ (row as any).title }}</span>
        </template>
        <template #cell-attempts_count="{ row }">
          <span class="font-mono tabular-nums text-slate-300">{{ (row as any).attempts_count }}</span>
        </template>
        <template #cell-avg_score="{ row }">
          <span class="font-mono tabular-nums text-amber-400 font-bold">{{ (row as any).avg_score }} pts</span>
        </template>
        <template #cell-completion_rate="{ row }">
          <BaseBadge :variant="(row as any).completion_rate >= 80 ? 'success' : 'soft'">
            {{ (row as any).completion_rate }}%
          </BaseBadge>
        </template>
      </BaseTable>
    </div>

    <!-- Section 2: Hardest Questions -->
    <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-exclamation-triangle text-amber-400"></i>
            Preguntas con Menor Tasa de Acierto (Top 5 Más Difíciles)
          </h3>
          <p class="text-xs text-slate-400">Identificar preguntas con alta dificultad para ajustar futuras trivias.</p>
        </div>
        <BaseButton variant="secondary" size="sm" @click="downloadHardestCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>

      <BaseTable
        :columns="hardestColumns"
        :data="triviaSummary?.hardest_questions || []"
        :loading="loading"
        empty-text="No hay datos de preguntas difíciles"
      >
        <template #cell-trivia_title="{ row }">
          <span class="text-xs font-mono text-slate-400">{{ (row as any).trivia_title }}</span>
        </template>
        <template #cell-question_text="{ row }">
          <span class="font-semibold text-slate-200">{{ (row as any).question_text }}</span>
        </template>
        <template #cell-total_answers="{ row }">
          <span class="font-mono tabular-nums text-slate-300">{{ (row as any).total_answers }}</span>
        </template>
        <template #cell-correct_rate="{ row }">
          <BaseBadge variant="danger">
            {{ (row as any).correct_rate }}% aciertos
          </BaseBadge>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
