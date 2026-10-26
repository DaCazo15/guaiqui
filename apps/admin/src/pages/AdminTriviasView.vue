<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import TriviasQuestionsTab from '../components/trivia-admin/TriviasQuestionsTab.vue'
import TriviasWhoIsTab from '../components/trivia-admin/TriviasWhoIsTab.vue'

type TriviaTab = 'questions' | 'who_is'

const route = useRoute()
const router = useRouter()

const activeTab = ref<TriviaTab>('questions')

const tabs = [
  { id: 'questions' as const, label: 'Trivias de Preguntas', icon: 'bi-question-diamond-fill', description: 'Cuestionarios clásicos por tiempo y preguntas de opción múltiple' },
  { id: 'who_is' as const, label: '¿Quién es?', icon: 'bi-person-bounding-box', description: 'Adivina el jugador por silueta o dorsal con conteo regresivo' }
]

const setTab = (tab: TriviaTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const syncTabFromRoute = () => {
  const queryTab = route.query.tab as string
  if (queryTab && ['questions', 'who_is'].includes(queryTab)) {
    activeTab.value = queryTab as TriviaTab
  } else if (route.query.tab === 'quien-es' || route.query.tab === 'quien_es') {
    activeTab.value = 'who_is'
  } else if (route.query.tab === 'preguntas') {
    activeTab.value = 'questions'
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
            Administra los cuestionarios oficiales de la Tribu y los retos interactivos de «¿Quién es?» por silueta o dorsal.
          </p>
        </div>
      </div>

      <!-- Dynamic Tab Buttons -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 p-1.5 bg-slate-950/80 border border-slate-800/80 rounded-2xl shadow-inner">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          @click="setTab(tab.id)"
          :class="[
            'px-4 py-3 rounded-xl text-left transition-all duration-200 flex flex-col justify-center gap-1 group relative',
            activeTab === tab.id
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-950/60 ring-1 ring-emerald-400/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900/80'
          ]"
        >
          <div class="flex items-center gap-2">
            <i :class="['bi', tab.icon, 'text-base', activeTab === tab.id ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400']"></i>
            <span class="text-xs sm:text-sm font-bold tracking-tight">{{ tab.label }}</span>
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
      </div>
    </div>
  </AdminLayout>
</template>
