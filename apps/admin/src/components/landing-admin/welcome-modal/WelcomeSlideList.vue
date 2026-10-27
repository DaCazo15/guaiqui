<script setup lang="ts">
import type { LoginModalSlide } from './types'

defineProps<{
  slides: LoginModalSlide[]
  selectedSlide: LoginModalSlide | null
  loading: boolean
  publishedCount: number
}>()

const emit = defineEmits<{
  (e: 'select', slide: LoginModalSlide): void
}>()
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4">
    <div class="flex items-center justify-between border-b border-slate-800 pb-3 mb-3">
      <h4 class="text-xs font-semibold text-slate-300 uppercase tracking-wider">
        Diapositivas ({{ slides.length }}/5)
      </h4>
      <span class="text-[11px] font-mono text-emerald-400 bg-emerald-950 px-2 py-0.5 rounded border border-emerald-800">
        {{ publishedCount }} publicadas
      </span>
    </div>

    <div v-if="loading" class="p-6 text-center text-slate-500 text-xs">
      <i class="bi bi-arrow-repeat animate-spin text-lg mb-1 block"></i>
      <span>Cargando lista...</span>
    </div>

    <div v-else-if="slides.length === 0" class="p-6 text-center text-slate-500 text-xs">
      No hay diapositivas registradas. Haz clic en "Nueva Diapositiva".
    </div>

    <div v-else class="space-y-2">
      <div
        v-for="slide in slides"
        :key="slide.id"
        @click="emit('select', slide)"
        :class="[
          'p-3 rounded-xl border transition-all cursor-pointer flex items-center justify-between gap-3',
          selectedSlide?.id === slide.id ? 'bg-slate-800 border-emerald-500 shadow-md' : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
        ]"
      >
        <div class="flex items-center gap-3 min-w-0">
          <span class="w-6 h-6 rounded-md bg-slate-800 text-emerald-400 font-mono text-xs font-bold flex items-center justify-center shrink-0 border border-slate-700">
            #{{ slide.position }}
          </span>
          <div class="min-w-0">
            <p class="text-xs font-bold text-white truncate">{{ slide.title }}</p>
            <p class="text-[11px] text-slate-400 truncate">{{ slide.cta_url }}</p>
          </div>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <span :class="['px-2 py-0.5 text-[10px] font-semibold rounded', slide.status === 'published' ? 'bg-emerald-950 text-emerald-300 border border-emerald-800' : 'bg-slate-800 text-slate-400']">
            {{ slide.status === 'published' ? 'Publicado' : 'Borrador' }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
