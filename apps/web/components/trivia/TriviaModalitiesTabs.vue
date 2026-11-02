<script setup lang="ts">
export type TriviaModalityId =
  | 'questions'
  | 'who_is'
  | 'polls'
  | 'over_under'
  | 'mystery_plays'
  | 'score_predictions'
  | 'flash_trivia'
  | 'progressive_clues'

export interface TriviaModalityTab {
  id: TriviaModalityId
  label: string
  icon: string
  badge: string
}

const props = withDefaults(
  defineProps<{
    activeTab: TriviaModalityId
  }>(),
  {
    activeTab: 'questions',
  }
)

const emit = defineEmits<{
  (e: 'update:activeTab', id: TriviaModalityId): void
}>()

const tabs: TriviaModalityTab[] = [
  { id: 'questions', label: 'Trivias Clásicas', icon: 'bi-question-diamond-fill', badge: 'Preguntas' },
  { id: 'who_is', label: '«¿Quién es?»', icon: 'bi-person-bounding-box', badge: 'Reto' },
  { id: 'polls', label: 'Encuestas', icon: 'bi-bar-chart-fill', badge: 'Partido' },
  { id: 'over_under', label: 'Mayor o Menor', icon: 'bi-arrow-down-up', badge: 'Líneas' },
  { id: 'mystery_plays', label: '¿Qué pasó después?', icon: 'bi-play-circle-fill', badge: 'Video' },
  { id: 'score_predictions', label: 'Marcador Exacto', icon: 'bi-bullseye', badge: 'El Bote' },
  { id: 'flash_trivia', label: 'Trivia Flash', icon: 'bi-stopwatch-fill', badge: '60s' },
  { id: 'progressive_clues', label: 'Pistas Progresivas', icon: 'bi-puzzle-fill', badge: 'Escalón' },
]

function selectTab(id: TriviaModalityId) {
  emit('update:activeTab', id)
}
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 p-1.5 bg-slate-100 rounded-2xl border border-guaiqui-border shadow-inner">
    <button
      v-for="t in tabs"
      :key="t.id"
      type="button"
      @click="selectTab(t.id)"
      class="px-3 py-2.5 rounded-xl text-left transition-all duration-200 flex items-center gap-2.5 cursor-pointer select-none"
      :class="[
        activeTab === t.id
          ? 'bg-guaiqui-primary text-white shadow-md'
          : 'text-guaiqui-text-muted hover:text-guaiqui-text hover:bg-white/80'
      ]"
    >
      <div
        class="w-7 h-7 rounded-lg flex items-center justify-center text-sm shrink-0"
        :class="activeTab === t.id ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700'"
      >
        <i :class="['bi', t.icon]"></i>
      </div>
      <div class="min-w-0 flex-1">
        <div class="font-display font-bold text-xs tracking-tight uppercase truncate">
          {{ t.label }}
        </div>
        <span
          class="text-[9px] px-1.5 py-0.2 rounded font-mono font-bold uppercase inline-block"
          :class="activeTab === t.id ? 'bg-emerald-800 text-emerald-100' : 'bg-slate-200 text-slate-600'"
        >
          {{ t.badge }}
        </span>
      </div>
    </button>
  </div>
</template>
