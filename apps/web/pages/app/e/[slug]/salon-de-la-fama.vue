<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useSupabaseClient, useSeoMeta } from '#imports'
import { BaseCard, BaseButton, BaseBadge } from '@guaiqui/ui'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'
import { retiredJerseys, legendaryFigures, championshipsList, type RetiredJersey, type LegendFigure } from '~/data/hallOfFameData'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const supabase = useSupabaseClient()

const {
  activeTeam,
  loading: teamLoading,
  loadTeamBySlug,
  openPicker,
} = useCurrentTeam()

const togglingFollow = ref(false)
const activeTab = ref<'jerseys' | 'legends' | 'trophies'>('jerseys')
const selectedJersey = ref<RetiredJersey | null>(null)
const selectedLegend = ref<LegendFigure | null>(null)
const legendsFilter = ref<'all' | 'gold_era' | 'modern_era' | 'builder'>('all')

const teamSlug = computed(() => route.params.slug as string)

const isGuaiqueries = computed(() => {
  return activeTeam.value?.slug === 'guaiqueries'
})

const filteredLegends = computed(() => {
  if (legendsFilter.value === 'all') return legendaryFigures
  return legendaryFigures.filter((l) => l.category === legendsFilter.value)
})

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  await loadTeamBySlug(currentSlug)
}

const handleToggleFollow = async () => {
  if (!activeTeam.value || togglingFollow.value) return
  togglingFollow.value = true
  const team = activeTeam.value
  const targetState = !team.is_following

  try {
    if (targetState) {
      await supabase.rpc('follow_team', { p_team_id: team.id })
    } else {
      await supabase.rpc('unfollow_team', { p_team_id: team.id })
    }
    await loadTeamBySlug(team.slug)
  } catch (err) {
    console.error('Error al alternar seguimiento:', err)
  } finally {
    togglingFollow.value = false
  }
}

watch(teamSlug, () => {
  loadData()
})

onMounted(() => {
  loadData()
})

useSeoMeta({
  title: computed(() =>
    activeTeam.value ? `Salón de la Fama — ${activeTeam.value.name}` : 'Salón de la Fama'
  ),
})
</script>

<template>
  <div class="space-y-6">
    <!-- Loading skeleton -->
    <div v-if="teamLoading && !activeTeam" class="space-y-4 animate-pulse">
      <div class="h-40 rounded-3xl bg-slate-900 border border-slate-800"></div>
      <div class="h-10 w-64 rounded-xl bg-slate-900"></div>
    </div>

    <!-- Active Team Layout -->
    <template v-else-if="activeTeam">
      <!-- Team Header -->
      <TeamHubHeader
        :team="activeTeam"
        :toggling="togglingFollow"
        @toggle-follow="handleToggleFollow"
        @switch-team="openPicker('hub')"
      />

      <!-- Inactive Alert Banner -->
      <TeamHubInactiveBanner
        v-if="activeTeam.status === 'inactive'"
        :team-name="activeTeam.name"
      />

      <!-- Navigation Tabs -->
      <TeamHubTabs
        :slug="activeTeam.slug"
        active-tab="salon-de-la-fama"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Content (When active) -->
      <div v-if="activeTeam.status === 'active'" class="space-y-6">
        <!-- Subheader -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 class="font-display text-xl sm:text-2xl font-bold text-guaiqui-text uppercase tracking-wider">
              Salón de la <span class="text-guaiqui-primary">Fama</span>
            </h2>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted mt-0.5">
              Camisetas retiradas, leyendas inmortales y trofeos históricos de {{ activeTeam.name }}.
            </p>
          </div>
        </div>

        <!-- If Team has registered historic hall of fame data (e.g. Guaiqueríes) -->
        <template v-if="isGuaiqueries">
          <!-- Hall of Fame Tabs -->
          <div class="flex items-center gap-2 border-b border-guaiqui-border pb-3">
            <button
              @click="activeTab = 'jerseys'"
              class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
              :class="activeTab === 'jerseys' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
            >
              <i class="bi bi-shield-check mr-1.5"></i>
              Dorsales Retirados ({{ retiredJerseys.length }})
            </button>
            <button
              @click="activeTab = 'legends'"
              class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
              :class="activeTab === 'legends' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
            >
              <i class="bi bi-star-fill mr-1.5"></i>
              Leyendas ({{ legendaryFigures.length }})
            </button>
            <button
              @click="activeTab = 'trophies'"
              class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
              :class="activeTab === 'trophies' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
            >
              <i class="bi bi-trophy-fill mr-1.5"></i>
              Palmarés ({{ championshipsList.length }})
            </button>
          </div>

          <!-- 1. Dorsales Retirados Grid -->
          <div v-if="activeTab === 'jerseys'" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <BaseCard
              v-for="jersey in retiredJerseys"
              :key="jersey.number"
              class="p-6 bg-white border-guaiqui-border hover:border-guaiqui-primary rounded-guaiqui-xl shadow-guaiqui-sm transition-all duration-200 space-y-4 cursor-pointer"
              @click="selectedJersey = jersey"
            >
              <div class="flex items-start justify-between">
                <div class="w-14 h-14 rounded-2xl bg-guaiqui-primary-soft text-guaiqui-primary font-display font-black text-2xl flex items-center justify-center border border-guaiqui-primary/30">
                  #{{ jersey.number }}
                </div>
                <BaseBadge variant="default" class="bg-amber-100 text-amber-800 border-none font-bold text-xs">
                  {{ jersey.titlesBadge || `${jersey.titlesCount} títulos` }}
                </BaseBadge>
              </div>

              <div>
                <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
                  {{ jersey.name }}
                </h3>
                <p class="text-xs text-guaiqui-primary font-semibold">
                  {{ jersey.nickname }} · {{ jersey.position }}
                </p>
                <p class="text-xs text-slate-500 mt-2 line-clamp-2">
                  {{ jersey.description }}
                </p>
              </div>
            </BaseCard>
          </div>

          <!-- 2. Leyendas Grid -->
          <div v-else-if="activeTab === 'legends'" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <BaseCard
              v-for="legend in filteredLegends"
              :key="legend.id"
              class="p-6 bg-white border-guaiqui-border hover:border-guaiqui-primary rounded-guaiqui-xl shadow-guaiqui-sm transition-all duration-200 space-y-3 cursor-pointer"
              @click="selectedLegend = legend"
            >
              <div class="flex items-center gap-3">
                <div class="w-12 h-12 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center text-xl text-slate-700 font-bold overflow-hidden">
                  <i class="bi bi-person-fill"></i>
                </div>
                <div>
                  <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
                    {{ legend.name }}
                  </h3>
                  <p class="text-xs text-guaiqui-primary font-semibold">
                    {{ legend.nickname }}
                  </p>
                </div>
              </div>
              <p class="text-xs text-slate-500 line-clamp-3">
                {{ legend.bio }}
              </p>
            </BaseCard>
          </div>

          <!-- 3. Palmarés Grid -->
          <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <BaseCard
              v-for="title in championshipsList"
              :key="title.year"
              class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex items-center gap-4"
            >
              <div class="w-12 h-12 rounded-xl bg-amber-500/10 text-amber-500 flex items-center justify-center text-2xl border border-amber-500/20 shrink-0">
                <i class="bi bi-trophy-fill"></i>
              </div>
              <div>
                <span class="text-xs font-mono font-bold text-guaiqui-primary block">
                  CAMPEÓN {{ title.year }}
                </span>
                <h4 class="font-display font-bold text-sm text-guaiqui-text uppercase">
                  {{ title.tournament }}
                </h4>
                <p class="text-xs text-slate-400">
                  Subcampeón: {{ title.runnerUp }}
                </p>
              </div>
            </BaseCard>
          </div>
        </template>

        <!-- Empty state for clubs without Hall of Fame yet -->
        <div
          v-else
          class="text-center py-16 text-guaiqui-text-muted space-y-3 bg-white rounded-guaiqui-xl border border-guaiqui-border p-6 max-w-5xl mx-auto"
        >
          <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
            <i class="bi bi-award"></i>
          </div>
          <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
            Salón de la Fama en Preparación
          </h3>
          <p class="text-sm">
            El palmarés, camisetas retiradas y leyendas de {{ activeTeam.name }} se publicarán próximamente.
          </p>
        </div>
      </div>
    </template>
  </div>
</template>
