<script setup lang="ts">
import { ref, computed } from 'vue'
import { legendaryFigures } from '~/data/hallOfFameData'

const activeCategory = ref<'all' | 'gold_era' | 'modern_era' | 'builder'>('all')

const filteredLegends = computed(() => {
  if (activeCategory.value === 'all') return legendaryFigures
  return legendaryFigures.filter((l) => l.category === activeCategory.value)
})
</script>

<template>
  <section class="py-14 sm:py-20 bg-white px-4 sm:px-8 border-b border-guaiqui-border">
    <div class="max-w-6xl mx-auto space-y-10">
      <div class="text-center max-w-2xl mx-auto space-y-3">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full border border-guaiqui-primary/20">
          Figuras Inmortales
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Leyendas y Forjadores
        </h2>
        <p class="text-sm text-guaiqui-text-muted">
          Los jugadores emblemáticos y entrenadores históricos que escribieron las páginas doradas del equipo.
        </p>
      </div>

      <!-- Filter Tabs -->
      <div class="flex items-center justify-center gap-2 flex-wrap">
        <button
          type="button"
          @click="activeCategory = 'all'"
          :class="[
            'px-4 py-2 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            activeCategory === 'all'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
          ]"
        >
          Todos
        </button>
        <button
          type="button"
          @click="activeCategory = 'gold_era'"
          :class="[
            'px-4 py-2 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            activeCategory === 'gold_era'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
          ]"
        >
          Época de Oro (Hexacampeonato)
        </button>
        <button
          type="button"
          @click="activeCategory = 'modern_era'"
          :class="[
            'px-4 py-2 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            activeCategory === 'modern_era'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
          ]"
        >
          Era Moderna
        </button>
        <button
          type="button"
          @click="activeCategory = 'builder'"
          :class="[
            'px-4 py-2 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            activeCategory === 'builder'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
          ]"
        >
          Directores Técnicos
        </button>
      </div>

      <!-- Legends Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="legend in filteredLegends"
          :key="legend.id"
          class="bg-guaiqui-surface rounded-guaiqui-xl border border-guaiqui-border p-6 space-y-4 hover:border-guaiqui-primary/50 transition-colors shadow-xs flex flex-col justify-between"
        >
          <div class="space-y-3">
            <div class="flex items-start justify-between gap-3">
              <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-display font-black text-lg shrink-0 border border-guaiqui-primary/20">
                <i v-if="legend.role === 'coach'" class="bi bi-clipboard-data-fill text-base"></i>
                <i v-else class="bi bi-person-fill text-lg"></i>
              </div>
              <div class="text-right">
                <span class="text-[11px] font-mono font-bold uppercase text-guaiqui-primary tracking-wider block">
                  {{ legend.era }}
                </span>
                <span v-if="legend.position" class="text-xs text-guaiqui-text-muted font-medium">
                  {{ legend.position }}
                </span>
                <span v-else class="text-xs text-guaiqui-text-muted font-medium">
                  Director Técnico
                </span>
              </div>
            </div>

            <div>
              <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
                {{ legend.name }}
              </h3>
              <p class="text-xs font-semibold text-guaiqui-primary italic">
                "{{ legend.nickname }}"
              </p>
            </div>

            <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed">
              {{ legend.bio }}
            </p>
          </div>

          <div class="space-y-2 pt-3 border-t border-guaiqui-border">
            <div class="flex flex-wrap gap-1.5">
              <span
                v-for="achievement in legend.achievements"
                :key="achievement"
                class="px-2 py-0.5 rounded-full bg-white text-guaiqui-text text-[11px] font-medium border border-guaiqui-border"
              >
                <i class="bi bi-check-circle-fill text-guaiqui-primary mr-1 text-[10px]"></i>
                {{ achievement }}
              </span>
            </div>

            <div class="text-[11px] text-guaiqui-text-muted font-medium pt-1 flex items-center gap-1.5">
              <i class="bi bi-trophy-fill text-amber-500 text-xs shrink-0"></i>
              <span>Títulos: {{ legend.titles.join(', ') }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
