<script setup lang="ts">
import { ref } from 'vue'

defineProps<{
  preview: {
    title: string
    subtitle: string
    image_url: string
    cta_label: string
  }
}>()

const previewDevice = ref<'desktop' | 'mobile'>('desktop')
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-4">
    <div class="flex items-center justify-between border-b border-slate-800 pb-3">
      <h4 class="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-2">
        <i class="bi bi-eye"></i> Vista Previa en Tiempo Real
      </h4>
      <div class="flex items-center gap-2 bg-slate-950 p-1 rounded-lg border border-slate-800">
        <button
          @click="previewDevice = 'desktop'"
          :class="['px-2.5 py-1 text-xs font-semibold rounded-md transition', previewDevice === 'desktop' ? 'bg-slate-800 text-emerald-400' : 'text-slate-400']"
        >
          <i class="bi bi-display mr-1"></i> Escritorio
        </button>
        <button
          @click="previewDevice = 'mobile'"
          :class="['px-2.5 py-1 text-xs font-semibold rounded-md transition', previewDevice === 'mobile' ? 'bg-slate-800 text-emerald-400' : 'text-slate-400']"
        >
          <i class="bi bi-phone mr-1"></i> Móvil
        </button>
      </div>
    </div>

    <!-- Preview Frame -->
    <div class="flex items-center justify-center p-4 bg-slate-950 rounded-xl">
      <div
        :class="[
          'bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-2xl space-y-4 p-5 transition-all',
          previewDevice === 'desktop' ? 'w-full max-w-[560px]' : 'w-[280px]'
        ]"
      >
        <div class="w-full aspect-video bg-gradient-to-br from-emerald-950 via-slate-900 to-slate-950 rounded-xl overflow-hidden relative flex items-center justify-center border border-slate-800">
          <img
            v-if="preview.image_url"
            :src="preview.image_url"
            class="w-full h-full object-cover"
          />
          <div v-else class="p-4 text-center">
            <span class="text-xs text-slate-500 font-mono">Sin imagen (Fondo de marca)</span>
          </div>
        </div>

        <div class="space-y-2">
          <span class="text-[10px] font-mono text-emerald-400 uppercase font-bold">Novedades del Club</span>
          <h5 class="text-base font-bold text-white uppercase tracking-wide leading-tight">
            {{ preview.title || 'Título de ejemplo' }}
          </h5>
          <p class="text-xs text-slate-300 leading-relaxed">
            {{ preview.subtitle || 'Subtítulo descriptivo de la diapositiva...' }}
          </p>
        </div>

        <div class="pt-3 border-t border-slate-800 flex items-center justify-between">
          <div class="flex gap-1">
            <span class="w-4 h-1.5 bg-emerald-400 rounded-full"></span>
            <span class="w-1.5 h-1.5 bg-slate-700 rounded-full"></span>
          </div>
          <button class="px-4 py-1.5 bg-emerald-600 text-white font-bold text-[11px] uppercase tracking-wider rounded-lg">
            {{ preview.cta_label || 'Ver más' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
