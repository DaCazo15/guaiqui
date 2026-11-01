<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useSupabaseClient, useSeoMeta } from '#imports'
import { BaseCard, BaseBadge, Skeleton } from '@guaiqui/ui'
import type { Player } from '@guaiqui/shared'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'

type PlayerRow = Player

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
const players = ref<PlayerRow[]>([])
const loading = ref(true)
const activeFilter = ref<'all' | 'pg' | 'sg' | 'sf' | 'pf' | 'c'>('all')

const filterOptions = [
  { key: 'all', label: 'Todos' },
  { key: 'pg', label: 'Bases' },
  { key: 'sg', label: 'Escoltas' },
  { key: 'sf', label: 'Aleros' },
  { key: 'pf', label: 'Ala-Pívots' },
  { key: 'c', label: 'Pívots' },
]

const teamSlug = computed(() => route.params.slug as string)

const loadPlayers = async (teamId: string) => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('players')
      .select('*')
      .eq('team_id', teamId)
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })

    if (error) throw error
    players.value = (data as unknown as Player[]) || []
  } catch (err) {
    console.error('Error fetching roster for team:', err)
    players.value = []
  } finally {
    loading.value = false
  }
}

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await loadPlayers(team.id)
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

const filteredPlayers = computed(() => {
  if (activeFilter.value === 'all') return players.value
  if (activeFilter.value === 'pg') {
    return players.value.filter((p) => p.position.includes('Base') || p.position.includes('PG'))
  }
  if (activeFilter.value === 'sg') {
    return players.value.filter((p) => p.position.includes('Escolta') || p.position.includes('SG'))
  }
  if (activeFilter.value === 'sf') {
    return players.value.filter((p) => p.position.includes('Alero') || p.position.includes('SF'))
  }
  if (activeFilter.value === 'pf') {
    return players.value.filter((p) => p.position.includes('Ala-Pívot') || p.position.includes('PF'))
  }
  if (activeFilter.value === 'c') {
    return players.value.filter((p) => p.position.includes('Pívot') || p.position.includes('C'))
  }
  return players.value
})

useSeoMeta({
  title: computed(() =>
    activeTeam.value ? `Plantilla Oficial — ${activeTeam.value.name}` : 'Plantilla Oficial'
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
        active-tab="plantilla"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Content (When active) -->
      <div v-if="activeTeam.status === 'active'" class="space-y-6">
        <!-- Subheader -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 class="font-display text-xl sm:text-2xl font-bold text-guaiqui-text uppercase tracking-wider">
              Plantilla <span class="text-guaiqui-primary">Oficial</span>
            </h2>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted mt-0.5">
              Conoce a los jugadores que defienden los colores de {{ activeTeam.name }}.
            </p>
          </div>
        </div>

        <!-- Position Filters (only when players exist) -->
        <div v-if="players.length > 0" class="flex flex-wrap gap-2 border-b border-guaiqui-border pb-3">
          <button
            v-for="opt in filterOptions"
            :key="opt.key"
            type="button"
            class="px-4 py-2 rounded-lg text-xs font-bold uppercase transition-all duration-200 cursor-pointer"
            :class="activeFilter === opt.key ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'"
            @click="activeFilter = opt.key as any"
          >
            {{ opt.label }}
          </button>
        </div>

        <!-- Loading Skeleton -->
        <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <Skeleton v-for="i in 6" :key="i" class="h-64 rounded-guaiqui-xl bg-guaiqui-surface" />
        </div>

        <!-- Empty State: Zero players registered -->
        <div
          v-else-if="players.length === 0"
          class="text-center py-16 text-guaiqui-text-muted space-y-3 bg-white rounded-guaiqui-xl border border-guaiqui-border p-6 max-w-5xl mx-auto"
        >
          <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
            <i class="bi bi-people"></i>
          </div>
          <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
            Roster en Actualización
          </h3>
          <p class="text-sm">
            La lista de jugadores de {{ activeTeam.name }} se publicará próximamente.
          </p>
        </div>

        <!-- Filter Empty State -->
        <div
          v-else-if="filteredPlayers.length === 0"
          class="text-center py-12 text-guaiqui-text-muted space-y-2 bg-white rounded-guaiqui-xl border border-guaiqui-border"
        >
          <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
            <i class="bi bi-person-x"></i>
          </div>
          <p>No hay jugadores en esta posición para este equipo.</p>
        </div>

        <!-- Players Grid -->
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <BaseCard
            v-for="player in filteredPlayers"
            :key="player.id"
            class="p-0 bg-white border-guaiqui-border hover:border-guaiqui-primary rounded-guaiqui-xl shadow-guaiqui-sm overflow-hidden group transition-all duration-300"
          >
            <!-- Card Header: Image & Jersey Number -->
            <div class="relative h-60 bg-gradient-to-t from-slate-950 via-slate-900 to-slate-800 flex items-end justify-center overflow-hidden">
              <img
                v-if="player.photo_url"
                :src="player.photo_url"
                :alt="player.full_name"
                class="h-full w-full object-cover object-top group-hover:scale-105 transition-transform duration-500"
                loading="lazy"
              />
              <div v-else class="w-full h-full flex items-center justify-center text-slate-700">
                <i class="bi bi-person-bounding-box text-6xl"></i>
              </div>

              <!-- Jersey Pill -->
              <div class="absolute top-3 left-3 bg-white/90 backdrop-blur-xs text-guaiqui-text font-display font-black text-xl w-10 h-10 rounded-full flex items-center justify-center shadow-md border border-white">
                #{{ player.jersey_number ?? '-' }}
              </div>

              <!-- Position Badge -->
              <div class="absolute top-3 right-3">
                <BaseBadge variant="default" class="bg-guaiqui-primary text-white border-none font-bold text-xs uppercase">
                  {{ player.position }}
                </BaseBadge>
              </div>

              <!-- Gradient overlay with name -->
              <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent p-4 text-white">
                <h3 class="font-display font-bold text-xl uppercase tracking-wide truncate">
                  {{ player.full_name }}
                </h3>
                <p class="text-xs text-emerald-400 font-medium">
                  {{ player.nationality || 'Venezuela' }}
                </p>
              </div>
            </div>

            <!-- Card Body: Stats details -->
            <div class="p-4 grid grid-cols-2 gap-3 text-xs bg-slate-50 border-t border-slate-100">
              <div class="space-y-0.5">
                <span class="text-guaiqui-text-muted text-[11px] uppercase block font-semibold">Altura</span>
                <span class="font-bold text-guaiqui-text">{{ player.height_cm ? `${player.height_cm} cm` : 'N/D' }}</span>
              </div>
              <div class="space-y-0.5">
                <span class="text-guaiqui-text-muted text-[11px] uppercase block font-semibold">Peso</span>
                <span class="font-bold text-guaiqui-text">{{ player.weight_kg ? `${player.weight_kg} kg` : 'N/D' }}</span>
              </div>
            </div>
          </BaseCard>
        </div>
      </div>
    </template>
  </div>
</template>
