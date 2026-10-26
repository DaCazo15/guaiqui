<script setup lang="ts">
import { ref, computed } from 'vue'
import { legendaryFigures as fallbackLegends, type LegendFigure } from '~/data/hallOfFameData'

const supabase = useSupabaseClient()
const activeCategory = ref<'all' | 'gold_era' | 'modern_era' | 'builder'>('all')

const { data: dbLegends } = await useAsyncData('hall-of-fame-legends', async () => {
  try {
    const { data, error } = await supabase
      .from('hall_of_fame_legends')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (error || !data || data.length === 0) return null
    return data.map((l: any): LegendFigure => ({
      id: l.id,
      name: l.name,
      nickname: l.nickname || '',
      role: l.role,
      category: l.category,
      era: l.era || '',
      position: l.position || undefined,
      titles: Array.isArray(l.titles) ? l.titles : [],
      achievements: Array.isArray(l.achievements) ? l.achievements : [],
      bio: l.bio || '',
      image_url: l.image_url || '/images/historia/san-shepherd.png'
    }))
  } catch (_e) {
    return null
  }
})

const legendaryFigures = computed(() => dbLegends.value || fallbackLegends)

const filteredLegends = computed(() => {
  if (activeCategory.value === 'all') return legendaryFigures.value
  return legendaryFigures.value.filter((l) => l.category === activeCategory.value)
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
          class="bg-white rounded-guaiqui-xl border border-guaiqui-border shadow-guaiqui-sm hover:shadow-guaiqui-md transition-all duration-200 overflow-hidden flex flex-col justify-between group"
        >
          <!-- Legend Photo Header -->
          <div class="relative h-56 w-full bg-slate-900 overflow-hidden">
            <img
              :src="legend.image_url"
              :alt="legend.name"
              class="w-full h-full object-cover object-top group-hover:scale-105 transition-transform duration-300"
              loading="lazy"
            />
            <!-- Gradient Overlay for readability -->
            <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/20 to-transparent" />

            <!-- Floating Era & Role Badges -->
            <div class="absolute top-3 left-3 right-3 flex items-center justify-between">
              <span class="px-2.5 py-1 rounded-full bg-slate-950/80 backdrop-blur-xs text-emerald-400 font-mono font-bold text-[11px] uppercase border border-emerald-500/30">
                {{ legend.era }}
              </span>
              <span class="px-2.5 py-1 rounded-full bg-amber-500/90 text-slate-950 font-bold text-[11px] uppercase tracking-wider flex items-center gap-1 shadow-xs">
                <i class="bi bi-trophy-fill text-[10px]"></i>
                <span>{{ legend.titles.length }} {{ legend.titles.length === 1 ? 'Título' : 'Títulos' }}</span>
              </span>
            </div>

            <!-- Position Banner in Photo -->
            <div class="absolute bottom-3 left-3 right-3">
              <span class="text-xs font-semibold text-emerald-300 uppercase tracking-wide">
                {{ legend.position || 'Director Técnico' }}
              </span>
              <h3 class="font-display font-extrabold text-2xl text-white uppercase tracking-tight leading-tight drop-shadow-sm">
                {{ legend.name }}
              </h3>
              <p class="text-xs font-bold text-amber-400 italic">
                "{{ legend.nickname }}"
              </p>
            </div>
          </div>

          <!-- Body Content -->
          <div class="p-5 space-y-3 flex-1 flex flex-col justify-between">
            <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed">
              {{ legend.bio }}
            </p>

            <div class="space-y-2 pt-3 border-t border-guaiqui-border">
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="achievement in legend.achievements"
                  :key="achievement"
                  class="px-2 py-0.5 rounded-full bg-guaiqui-surface text-guaiqui-text text-[11px] font-medium border border-guaiqui-border"
                >
                  <i class="bi bi-check-circle-fill text-guaiqui-primary mr-1 text-[10px]"></i>
                  {{ achievement }}
                </span>
              </div>

              <div class="text-[11px] text-guaiqui-text-muted font-medium pt-1 flex items-center gap-1.5">
                <i class="bi bi-award-fill text-amber-500 text-xs shrink-0"></i>
                <span class="truncate">Años campeón: {{ legend.titles.join(', ') }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
