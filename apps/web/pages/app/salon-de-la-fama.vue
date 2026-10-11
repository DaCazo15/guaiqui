<script setup lang="ts">
import { ref, computed } from 'vue'
import { BaseCard, BaseButton, BaseBadge } from '@guaiqui/ui'
import { retiredJerseys, legendaryFigures, championshipsList, type RetiredJersey, type LegendFigure } from '~/data/hallOfFameData'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Salón de la Fama — Fan Zone Guaiqueríes',
  description: 'Explora los dorsales retirados, leyendas inmortales y trofeos históricos del club.',
})

const activeTab = ref<'jerseys' | 'legends' | 'trophies'>('jerseys')
const selectedJersey = ref<RetiredJersey | null>(null)
const selectedLegend = ref<LegendFigure | null>(null)

const legendsFilter = ref<'all' | 'gold_era' | 'modern_era' | 'builder'>('all')

const filteredLegends = computed(() => {
  if (legendsFilter.value === 'all') return legendaryFigures
  return legendaryFigures.filter((l) => l.category === legendsFilter.value)
})

function openJerseyModal(jersey: RetiredJersey) {
  selectedJersey.value = jersey
}

function closeJerseyModal() {
  selectedJersey.value = null
}

function openLegendModal(legend: LegendFigure) {
  selectedLegend.value = legend
}

function closeLegendModal() {
  selectedLegend.value = null
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header Fan Zone -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-guaiqui-border pb-4">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="text-xs font-mono font-bold uppercase tracking-wider text-guaiqui-primary bg-guaiqui-primary-soft px-2.5 py-0.5 rounded-full border border-guaiqui-primary/20">
            Fan Zone • Historia
          </span>
        </div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Salón de la <span class="text-guaiqui-primary">Fama</span>
        </h1>
        <p class="text-xs sm:text-sm text-guaiqui-text-muted">
          El templo donde viven las camisetas retiradas, las leyendas eternas y los 9 trofeos de la Tribu Verde.
        </p>
      </div>

      <!-- Quick Link to Trivias -->
      <NuxtLink to="/app/trivias" class="shrink-0">
        <BaseButton variant="primary" size="sm">
          <i class="bi bi-patch-question-fill mr-1.5"></i>
          <span>Trivias de Historia</span>
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Navigation Tabs -->
    <div class="flex items-center gap-2 border-b border-guaiqui-border overflow-x-auto pb-1">
      <button
        type="button"
        @click="activeTab = 'jerseys'"
        :class="[
          'px-4 py-2.5 text-xs sm:text-sm font-bold uppercase tracking-wider transition-all border-b-2 flex items-center gap-2 whitespace-nowrap cursor-pointer',
          activeTab === 'jerseys'
            ? 'border-guaiqui-primary text-guaiqui-primary font-black'
            : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text'
        ]"
      >
        <i class="bi bi-star-fill text-xs"></i>
        <span>Dorsales Retirados ({{ retiredJerseys.length }})</span>
      </button>

      <button
        type="button"
        @click="activeTab = 'legends'"
        :class="[
          'px-4 py-2.5 text-xs sm:text-sm font-bold uppercase tracking-wider transition-all border-b-2 flex items-center gap-2 whitespace-nowrap cursor-pointer',
          activeTab === 'legends'
            ? 'border-guaiqui-primary text-guaiqui-primary font-black'
            : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text'
        ]"
      >
        <i class="bi bi-people-fill text-xs"></i>
        <span>Leyendas & Ídolos ({{ legendaryFigures.length }})</span>
      </button>

      <button
        type="button"
        @click="activeTab = 'trophies'"
        :class="[
          'px-4 py-2.5 text-xs sm:text-sm font-bold uppercase tracking-wider transition-all border-b-2 flex items-center gap-2 whitespace-nowrap cursor-pointer',
          activeTab === 'trophies'
            ? 'border-guaiqui-primary text-guaiqui-primary font-black'
            : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text'
        ]"
      >
        <i class="bi bi-trophy-fill text-xs"></i>
        <span>Vitrina de Títulos ({{ championshipsList.length }})</span>
      </button>
    </div>

    <!-- TAB 1: RETIRED JERSEYS -->
    <div v-if="activeTab === 'jerseys'" class="space-y-6">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <BaseCard
          v-for="jersey in retiredJerseys"
          :key="jersey.number"
          class="p-0 overflow-hidden bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm hover:shadow-guaiqui-md transition-all duration-200 cursor-pointer group flex flex-col justify-between"
          @click="openJerseyModal(jersey)"
        >
          <!-- Card Jersey Header -->
          <div class="bg-gradient-to-br from-guaiqui-primary to-emerald-950 text-white p-5 text-center relative overflow-hidden">
            <div class="font-display font-black text-6xl text-white tracking-tighter group-hover:scale-110 transition-transform">
              #{{ jersey.number }}
            </div>
            <div class="mt-1 text-xs text-emerald-200 font-medium">
              {{ jersey.position }} • {{ jersey.years }}
            </div>
          </div>

          <div class="p-5 space-y-3 flex-1 flex flex-col justify-between">
            <div class="space-y-1">
              <div class="flex items-center justify-between">
                <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
                  {{ jersey.name }}
                </h3>
                <BaseBadge variant="warning" size="sm">
                  {{ jersey.titlesCount }} {{ jersey.titlesCount === 1 ? 'título' : 'títulos' }}
                </BaseBadge>
              </div>
              <p class="text-xs font-semibold text-guaiqui-primary italic">
                "{{ jersey.nickname }}"
              </p>
              <p class="text-xs text-guaiqui-text-muted line-clamp-2 pt-1">
                {{ jersey.description }}
              </p>
            </div>

            <div class="pt-2 border-t border-guaiqui-border flex items-center justify-between text-xs text-guaiqui-text font-medium">
              <span class="truncate text-guaiqui-text-muted">{{ jersey.highlight }}</span>
              <i class="bi bi-chevron-right text-guaiqui-primary ml-1 shrink-0"></i>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>

    <!-- TAB 2: LEGENDS & FIGURES -->
    <div v-else-if="activeTab === 'legends'" class="space-y-6">
      <!-- Secondary category filter -->
      <div class="flex items-center gap-2 flex-wrap">
        <button
          type="button"
          @click="legendsFilter = 'all'"
          :class="[
            'px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            legendsFilter === 'all'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
          ]"
        >
          Todos
        </button>
        <button
          type="button"
          @click="legendsFilter = 'gold_era'"
          :class="[
            'px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            legendsFilter === 'gold_era'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
          ]"
        >
          Época de Oro
        </button>
        <button
          type="button"
          @click="legendsFilter = 'modern_era'"
          :class="[
            'px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            legendsFilter === 'modern_era'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
          ]"
        >
          Era Moderna
        </button>
        <button
          type="button"
          @click="legendsFilter = 'builder'"
          :class="[
            'px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
            legendsFilter === 'builder'
              ? 'bg-guaiqui-primary text-white shadow-xs'
              : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
          ]"
        >
          Entrenadores
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <BaseCard
          v-for="legend in filteredLegends"
          :key="legend.id"
          class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm hover:border-guaiqui-primary/50 transition-all cursor-pointer space-y-4 flex flex-col justify-between"
          @click="openLegendModal(legend)"
        >
          <div class="space-y-3">
            <div class="flex items-start justify-between gap-2">
              <div class="w-10 h-10 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center font-bold text-base shrink-0 border border-guaiqui-primary/20">
                <i v-if="legend.role === 'coach'" class="bi bi-clipboard-data-fill text-sm"></i>
                <i v-else class="bi bi-person-fill text-base"></i>
              </div>
              <span class="text-[11px] font-mono font-bold text-guaiqui-primary uppercase">
                {{ legend.era }}
              </span>
            </div>

            <div>
              <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
                {{ legend.name }}
              </h3>
              <p class="text-xs font-semibold text-guaiqui-primary italic">
                "{{ legend.nickname }}"
              </p>
              <p class="text-xs text-guaiqui-text-muted mt-1 line-clamp-3">
                {{ legend.bio }}
              </p>
            </div>
          </div>

          <div class="pt-3 border-t border-guaiqui-border flex items-center justify-between text-xs font-medium text-guaiqui-text">
            <span class="text-amber-600 font-semibold truncate">
              <i class="bi bi-trophy-fill mr-1"></i>
              {{ legend.titles.length }} {{ legend.titles.length === 1 ? 'título' : 'títulos' }}
            </span>
            <span class="text-guaiqui-primary text-xs hover:underline flex items-center gap-1">
              Ver ficha <i class="bi bi-arrow-right"></i>
            </span>
          </div>
        </BaseCard>
      </div>
    </div>

    <!-- TAB 3: TROPHIES -->
    <div v-else-if="activeTab === 'trophies'" class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <BaseCard
          v-for="championship in championshipsList"
          :key="championship.year"
          class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-3 flex flex-col justify-between"
          :class="championship.isHexa ? 'border-l-4 border-l-amber-500' : 'border-l-4 border-l-guaiqui-primary'"
        >
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="font-display font-black text-3xl text-guaiqui-text tracking-tight">
                {{ championship.year }}
              </span>
              <span
                v-if="championship.isHexa"
                class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-amber-100 text-amber-800 border border-amber-300"
              >
                Hexacampeonato
              </span>
              <span
                v-else
                class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/20"
              >
                Campeón LPB / SPB
              </span>
            </div>

            <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
              {{ championship.tournament }}
            </h3>

            <p class="text-xs text-guaiqui-text-muted">
              Subcampeón: <strong class="text-guaiqui-text">{{ championship.runnerUp }}</strong>
            </p>

            <p class="text-xs text-guaiqui-text leading-relaxed pt-1">
              {{ championship.highlight }}
            </p>
          </div>

          <div class="pt-3 border-t border-guaiqui-border flex items-center gap-1.5 text-[11px] text-guaiqui-text-muted">
            <i class="bi bi-geo-alt-fill text-guaiqui-primary text-xs"></i>
            <span>La Asunción, Isla de Margarita</span>
          </div>
        </BaseCard>
      </div>
    </div>

    <!-- MODAL: RETIRED JERSEY DETAIL -->
    <Teleport to="body">
      <div
        v-if="selectedJersey"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs"
        @click.self="closeJerseyModal"
      >
        <div class="relative w-full max-w-lg bg-white rounded-guaiqui-xl shadow-2xl border border-guaiqui-border overflow-hidden">
          <!-- Circular Close Button -->
          <button
            type="button"
            @click="closeJerseyModal"
            class="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-white/80 hover:bg-red-600 hover:text-white text-gray-700 flex items-center justify-center transition-all cursor-pointer shadow-sm"
          >
            <i class="bi bi-x-lg text-xs font-bold"></i>
          </button>

          <!-- Top Banner -->
          <div class="bg-gradient-to-r from-guaiqui-primary to-emerald-950 p-6 text-white text-center">
            <span class="text-xs font-mono uppercase tracking-widest text-emerald-300 font-bold">Dorsal Inmortal Retirado</span>
            <div class="font-display font-black text-6xl my-1">
              #{{ selectedJersey.number }}
            </div>
            <h2 class="font-display font-bold text-2xl uppercase">
              {{ selectedJersey.name }}
            </h2>
            <p class="text-xs text-emerald-200 italic">
              "{{ selectedJersey.nickname }}"
            </p>
          </div>

          <!-- Body -->
          <div class="p-6 space-y-4">
            <div class="grid grid-cols-2 gap-3 text-center">
              <div class="p-3 bg-guaiqui-surface rounded-guaiqui-md border border-guaiqui-border">
                <span class="text-[10px] uppercase font-bold text-guaiqui-text-muted block">Posición</span>
                <span class="text-xs font-bold text-guaiqui-text">{{ selectedJersey.position }}</span>
              </div>
              <div class="p-3 bg-guaiqui-surface rounded-guaiqui-md border border-guaiqui-border">
                <span class="text-[10px] uppercase font-bold text-guaiqui-text-muted block">Años Activo</span>
                <span class="text-xs font-bold text-guaiqui-text">{{ selectedJersey.years }}</span>
              </div>
            </div>

            <div class="space-y-1">
              <h3 class="text-xs font-bold uppercase tracking-wider text-guaiqui-primary">Legado Histórico</h3>
              <p class="text-xs sm:text-sm text-guaiqui-text leading-relaxed">
                {{ selectedJersey.description }}
              </p>
            </div>

            <div class="p-3 bg-amber-50 rounded-guaiqui-md border border-amber-200 flex items-center gap-3">
              <i class="bi bi-trophy-fill text-amber-600 text-xl shrink-0"></i>
              <div>
                <span class="text-xs font-bold text-amber-900 block">Palmarés con Guaiqueríes</span>
                <span class="text-xs text-amber-800">{{ selectedJersey.titlesCount }} Títulos Nacionales</span>
              </div>
            </div>

            <div class="pt-2 flex justify-end">
              <NuxtLink to="/app/trivias">
                <BaseButton variant="primary" size="sm">
                  <i class="bi bi-patch-question mr-1.5"></i>
                  <span>Trivia del Club</span>
                </BaseButton>
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- MODAL: LEGEND DETAIL -->
    <Teleport to="body">
      <div
        v-if="selectedLegend"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs"
        @click.self="closeLegendModal"
      >
        <div class="relative w-full max-w-lg bg-white rounded-guaiqui-xl shadow-2xl border border-guaiqui-border overflow-hidden">
          <button
            type="button"
            @click="closeLegendModal"
            class="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-slate-100 hover:bg-red-600 hover:text-white text-gray-700 flex items-center justify-center transition-all cursor-pointer shadow-sm"
          >
            <i class="bi bi-x-lg text-xs font-bold"></i>
          </button>

          <div class="p-6 space-y-4">
            <div class="space-y-1">
              <span class="text-[11px] font-mono font-bold uppercase tracking-wider text-guaiqui-primary">
                {{ selectedLegend.era }} • {{ selectedLegend.position || 'Director Técnico' }}
              </span>
              <h2 class="font-display font-extrabold text-2xl text-guaiqui-text uppercase">
                {{ selectedLegend.name }}
              </h2>
              <p class="text-xs font-semibold text-guaiqui-primary italic">
                "{{ selectedLegend.nickname }}"
              </p>
            </div>

            <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed">
              {{ selectedLegend.bio }}
            </p>

            <div class="space-y-2">
              <h3 class="text-xs font-bold uppercase tracking-wider text-guaiqui-text">Logros y Distinciones</h3>
              <div class="space-y-1.5">
                <div
                  v-for="item in selectedLegend.achievements"
                  :key="item"
                  class="flex items-center gap-2 text-xs text-guaiqui-text bg-guaiqui-surface p-2 rounded-guaiqui-md border border-guaiqui-border"
                >
                  <i class="bi bi-check-circle-fill text-guaiqui-primary shrink-0"></i>
                  <span>{{ item }}</span>
                </div>
              </div>
            </div>

            <div class="p-3 bg-amber-50 rounded-guaiqui-md border border-amber-200 text-xs text-amber-900">
              <strong>Campeonatos Conquistados:</strong> {{ selectedLegend.titles.join(', ') }}
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
