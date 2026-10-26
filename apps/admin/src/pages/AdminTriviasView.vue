<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import TriviasQuestionsTab from '../components/trivia-admin/TriviasQuestionsTab.vue'
import TriviasWhoIsTab from '../components/trivia-admin/TriviasWhoIsTab.vue'
import TriviasPollsTab from '../components/trivia-admin/TriviasPollsTab.vue'
import TriviasOverUnderTab from '../components/trivia-admin/TriviasOverUnderTab.vue'
import TriviasMysteryPlaysTab from '../components/trivia-admin/TriviasMysteryPlaysTab.vue'
import TriviasScorePredictionsTab from '../components/trivia-admin/TriviasScorePredictionsTab.vue'
import TriviasFlashTab from '../components/trivia-admin/TriviasFlashTab.vue'
import TriviasProgressiveCluesTab from '../components/trivia-admin/TriviasProgressiveCluesTab.vue'

type TriviaTab =
  | 'questions'
  | 'who_is'
  | 'polls'
  | 'over_under'
  | 'mystery_plays'
  | 'score_predictions'
  | 'flash_trivia'
  | 'progressive_clues'

const route = useRoute()
const router = useRouter()

const activeTab = ref<TriviaTab>('questions')

const tabs = [
  { id: 'questions' as const, label: 'Trivias de Preguntas', icon: 'bi-question-diamond-fill', description: 'Cuestionarios clásicos por tiempo' },
  { id: 'who_is' as const, label: '«¿Quién es?»', icon: 'bi-person-bounding-box', description: 'Siluetas y dorsales con reveal 5s' },
  { id: 'polls' as const, label: 'Encuestas de Partido', icon: 'bi-bar-chart-fill', description: 'Predicciones con respuesta incógnita' },
  { id: 'over_under' as const, label: 'Mayor o Menor', icon: 'bi-arrow-down-up', description: 'Líneas Over/Under de estadísticas' },
  { id: 'mystery_plays' as const, label: '«¿Qué pasó después?»', icon: 'bi-play-circle-fill', description: 'Jugadas pausadas en video o imagen' },
  { id: 'score_predictions' as const, label: 'Marcador Exacto', icon: 'bi-bullseye', description: 'Pronóstico de resultado final y bote' },
  { id: 'flash_trivia' as const, label: 'Trivia Flash 60s', icon: 'bi-stopwatch-fill', description: 'Contrarreloj con racha y tiempo límite' },
  { id: 'progressive_clues' as const, label: 'Pistas Progresivas', icon: 'bi-puzzle-fill', description: 'Adivina el jugador con menos pistas' },
]

const setTab = (tab: TriviaTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const syncTabFromRoute = () => {
  const queryTab = route.query.tab as string
  if (queryTab && tabs.some(t => t.id === queryTab)) {
    activeTab.value = queryTab as TriviaTab
  } else if (route.query.tab === 'quien-es' || route.query.tab === 'quien_es') {
    activeTab.value = 'who_is'
  } else if (route.query.tab === 'preguntas') {
    activeTab.value = 'questions'
  } else if (route.query.tab === 'encuestas' || route.query.tab === 'predicciones') {
    activeTab.value = 'polls'
  }
}

onMounted(() => {
  syncTabFromRoute()
})

watch(() => route.query.tab, () => {
  syncTabFromRoute()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Section Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-patch-question-fill text-emerald-400"></i>
            Gestión de Trivias y Juegos
          </h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Administra cuestionarios, siluetas, encuestas de partido, líneas over/under, jugadas misteriosas, marcadores, flash 60s y pistas progresivas.
          </p>
        </div>
      </div>

      <!-- Dynamic Tab Buttons Grid -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-2.5 p-2 bg-slate-950/80 border border-slate-800/80 rounded-2xl shadow-inner">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          @click="setTab(tab.id)"
          :class="[
            'px-3.5 py-3 rounded-xl text-left transition-all duration-200 flex flex-col justify-center gap-1 group relative',
            activeTab === tab.id
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-950/60 ring-1 ring-emerald-400/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900/80'
          ]"
        >
          <div class="flex items-center gap-2">
            <i :class="['bi', tab.icon, 'text-base', activeTab === tab.id ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400']"></i>
            <span class="text-xs sm:text-sm font-bold tracking-tight truncate">{{ tab.label }}</span>
          </div>
          <span :class="['text-[11px] truncate', activeTab === tab.id ? 'text-emerald-100' : 'text-slate-500']">
            {{ tab.description }}
          </span>
        </button>
      </div>

      <!-- Dynamic Tab Content Render -->
      <div class="pt-2">
        <TriviasQuestionsTab v-if="activeTab === 'questions'" />
        <TriviasWhoIsTab v-else-if="activeTab === 'who_is'" />
        <TriviasPollsTab v-else-if="activeTab === 'polls'" />
        <TriviasOverUnderTab v-else-if="activeTab === 'over_under'" />
        <TriviasMysteryPlaysTab v-else-if="activeTab === 'mystery_plays'" />
        <TriviasScorePredictionsTab v-else-if="activeTab === 'score_predictions'" />
        <TriviasFlashTab v-else-if="activeTab === 'flash_trivia'" />
        <TriviasProgressiveCluesTab v-else-if="activeTab === 'progressive_clues'" />
      </div>
    </div>
  </AdminLayout>
</template>
