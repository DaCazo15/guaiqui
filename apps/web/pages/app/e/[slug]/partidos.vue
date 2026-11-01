<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useSupabaseClient, useSeoMeta } from '#imports'
import { BaseCard, Skeleton } from '@guaiqui/ui'
import type { Game } from '@guaiqui/shared'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'

type GameRow = Game

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
const games = ref<GameRow[]>([])
const loading = ref(true)
const activeTab = ref<'all' | 'scheduled' | 'finished'>('all')

const teamSlug = computed(() => route.params.slug as string)

const loadGames = async (teamId: string) => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('games')
      .select('*')
      .eq('team_id', teamId)
      .order('game_date', { ascending: false })

    if (error) throw error
    games.value = (data as unknown as Game[]) || []
  } catch (err) {
    console.error('Error fetching games for team:', err)
    games.value = []
  } finally {
    loading.value = false
  }
}

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await loadGames(team.id)
  }
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

const filteredGames = computed(() => {
  if (activeTab.value === 'all') return games.value
  if (activeTab.value === 'scheduled') {
    return games.value.filter((g) => g.status === 'scheduled' || g.status === 'live')
  }
  if (activeTab.value === 'finished') {
    return games.value.filter((g) => g.status === 'finished')
  }
  return games.value
})

const formatDate = (dateStr: string) => {
  if (!dateStr) return 'Fecha por definir'
  const d = new Date(dateStr)
  return d.toLocaleDateString('es-VE', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

useSeoMeta({
  title: computed(() =>
    activeTeam.value ? `Partidos — ${activeTeam.value.name}` : 'Partidos del Equipo'
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
        active-tab="partidos"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Content (When active) -->
      <div v-if="activeTeam.status === 'active'" class="space-y-6">
        <!-- Subheader -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 class="font-display text-xl sm:text-2xl font-bold text-guaiqui-text uppercase tracking-wider">
              Partidos & <span class="text-guaiqui-primary">Resultados</span>
            </h2>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted mt-0.5">
              Calendario oficial y resultados de la temporada de {{ activeTeam.name }}.
            </p>
          </div>
        </div>

        <!-- Status Tabs (only when games exist) -->
        <div v-if="games.length > 0" class="flex items-center gap-2 border-b border-guaiqui-border pb-3">
          <button
            @click="activeTab = 'all'"
            class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
            :class="activeTab === 'all' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
          >
            Todos ({{ games.length }})
          </button>
          <button
            @click="activeTab = 'scheduled'"
            class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
            :class="activeTab === 'scheduled' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
          >
            <i class="bi bi-clock mr-1"></i> Próximos
          </button>
          <button
            @click="activeTab = 'finished'"
            class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
            :class="activeTab === 'finished' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
          >
            <i class="bi bi-check-circle mr-1"></i> Finalizados
          </button>
        </div>

        <!-- Loading Skeleton -->
        <div v-if="loading" class="space-y-3">
          <Skeleton v-for="i in 3" :key="i" class="h-28 rounded-guaiqui-xl bg-guaiqui-surface" />
        </div>

        <!-- Empty State: Zero games registered -->
        <div
          v-else-if="games.length === 0"
          class="text-center py-16 text-guaiqui-text-muted space-y-3 bg-white rounded-guaiqui-xl border border-guaiqui-border p-6 max-w-5xl mx-auto"
        >
          <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
            <i class="bi bi-calendar-event"></i>
          </div>
          <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
            Calendario en Programación
          </h3>
          <p class="text-sm">
            No hay partidos programados ni resultados registrados actualmente para {{ activeTeam.name }}.
          </p>
        </div>

        <!-- Filter Empty State -->
        <div
          v-else-if="filteredGames.length === 0"
          class="text-center py-12 text-guaiqui-text-muted space-y-2 bg-white rounded-guaiqui-xl border border-guaiqui-border"
        >
          <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-calendar-x"></i>
          </div>
          <p>No hay partidos en esta categoría seleccionada.</p>
        </div>

        <!-- Games List -->
        <div v-else class="space-y-4">
          <BaseCard
            v-for="game in filteredGames"
            :key="game.id"
            class="p-5 bg-white border-guaiqui-border hover:border-guaiqui-primary rounded-guaiqui-xl shadow-guaiqui-sm transition-all duration-200 space-y-4"
          >
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-guaiqui-border/60 pb-3">
              <div class="flex items-center gap-2">
                <span
                  class="px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase tracking-wider"
                  :class="game.status === 'live' ? 'bg-red-100 text-red-700 animate-pulse' : game.status === 'finished' ? 'bg-slate-100 text-slate-700' : 'bg-guaiqui-primary-soft text-guaiqui-primary'"
                >
                  {{ game.status === 'live' ? 'En Vivo' : game.status === 'finished' ? 'Finalizado' : 'Programado' }}
                </span>
                <span class="text-xs font-medium text-guaiqui-text-muted">
                  {{ formatDate(game.game_date) }}
                </span>
              </div>

              <span v-if="game.venue" class="text-xs text-guaiqui-text-muted flex items-center gap-1">
                <i class="bi bi-geo-alt"></i>
                {{ game.venue }}
              </span>
            </div>

            <!-- Scoreboard -->
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-3 flex-1 min-w-0">
                <div class="w-10 h-10 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center overflow-hidden shrink-0">
                  <img v-if="game.home_team_logo" :src="game.home_team_logo" :alt="game.home_team_name" class="w-7 h-7 object-contain" />
                  <i v-else class="bi bi-shield text-slate-400"></i>
                </div>
                <span class="font-bold text-sm text-guaiqui-text truncate">{{ game.home_team_name }}</span>
              </div>

              <div class="px-4 py-1.5 rounded-xl bg-slate-50 border border-slate-200 font-display font-black text-lg text-slate-800">
                <template v-if="game.status === 'finished' || game.status === 'live'">
                  {{ game.home_score ?? 0 }} - {{ game.away_score ?? 0 }}
                </template>
                <template v-else>VS</template>
              </div>

              <div class="flex items-center justify-end gap-3 flex-1 min-w-0 text-right">
                <span class="font-bold text-sm text-guaiqui-text truncate">{{ game.away_team_name }}</span>
                <div class="w-10 h-10 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center overflow-hidden shrink-0">
                  <img v-if="game.away_team_logo" :src="game.away_team_logo" :alt="game.away_team_name" class="w-7 h-7 object-contain" />
                  <i v-else class="bi bi-shield text-slate-400"></i>
                </div>
              </div>
            </div>
          </BaseCard>
        </div>
      </div>
    </template>
  </div>
</template>
