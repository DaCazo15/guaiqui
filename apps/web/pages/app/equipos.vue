<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { EmptyState, Skeleton } from '@guaiqui/ui'
import TeamSearchBar from '~/components/teams/TeamSearchBar.vue'
import TeamCard, { type TeamItem } from '~/components/teams/TeamCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Equipos — Fan Zone',
  description: 'Descubre y sigue a tus equipos favoritos de baloncesto para ganar perlitas y desbloquear premios.',
})

const supabase = useSupabaseClient()

const searchQuery = ref('')
const teams = ref<TeamItem[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const togglingTeamId = ref<string | null>(null)

const fetchTeams = async () => {
  loading.value = true
  error.value = null
  try {
    const { data, error: rpcError } = await supabase.rpc('search_teams', {
      p_query: searchQuery.value.trim() || undefined,
      p_limit: 50,
      p_offset: 0,
    })

    if (rpcError) throw rpcError
    teams.value = (data as unknown as TeamItem[]) || []
  } catch (err: any) {
    error.value = err.message || 'Error al buscar equipos'
  } finally {
    loading.value = false
  }
}

const handleToggleFollow = async (team: TeamItem) => {
  if (togglingTeamId.value) return
  togglingTeamId.value = team.id
  error.value = null

  const targetState = !team.is_following
  // Optimistic update
  team.is_following = targetState
  team.follower_count += targetState ? 1 : -1

  try {
    if (targetState) {
      const { error: rpcError } = await supabase.rpc('follow_team', { p_team_id: team.id })
      if (rpcError) throw rpcError
    } else {
      const { error: rpcError } = await supabase.rpc('unfollow_team', { p_team_id: team.id })
      if (rpcError) throw rpcError
    }
  } catch (err: any) {
    // Revert on error
    team.is_following = !targetState
    team.follower_count += targetState ? -1 : 1
    error.value = err.message || 'No se pudo actualizar el seguimiento del equipo'
  } finally {
    togglingTeamId.value = null
  }
}

let debounceTimer: ReturnType<typeof setTimeout> | null = null
const onSearchInput = (val: string) => {
  searchQuery.value = val
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    fetchTeams()
  }, 350)
}

onMounted(() => {
  fetchTeams()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Explorar <span class="text-guaiqui-primary">Equipos</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Sigue a tus clubes de baloncesto favoritos para participar en sus trivias, acumular perlitas exclusivas y canjear premios oficiales.
      </p>
    </div>

    <!-- Search Bar -->
    <div class="max-w-md">
      <TeamSearchBar
        :model-value="searchQuery"
        :loading="loading"
        @update:model-value="onSearchInput"
        @search="fetchTeams"
      />
    </div>

    <!-- Error Alert -->
    <div
      v-if="error"
      class="p-4 bg-red-50 border border-red-200 text-red-700 rounded-guaiqui-lg text-sm flex items-center justify-between"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-triangle-fill text-red-500"></i>
        <span>{{ error }}</span>
      </div>
      <button
        type="button"
        class="text-xs font-bold uppercase underline hover:no-underline cursor-pointer"
        @click="fetchTeams"
      >
        Reintentar
      </button>
    </div>

    <!-- Loading Skeleton -->
    <div
      v-if="loading && teams.length === 0"
      class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
    >
      <div
        v-for="i in 6"
        :key="i"
        class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl space-y-4"
      >
        <div class="flex items-center gap-3">
          <Skeleton variant="circular" width="3.5rem" height="3.5rem" />
          <div class="flex-1 space-y-2">
            <Skeleton variant="text" width="70%" />
            <Skeleton variant="text" width="40%" />
          </div>
        </div>
        <div class="pt-3 border-t border-slate-100 flex justify-end">
          <Skeleton variant="rectangular" width="5rem" height="2rem" />
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!loading && teams.length === 0"
      class="bg-white border border-guaiqui-border rounded-guaiqui-xl p-8 text-center"
    >
      <EmptyState
        title="No se encontraron equipos"
        description="Intenta buscar con otro término o consulta más tarde."
      >
        <template #icon>
          <i class="bi bi-shield-x text-4xl text-slate-400"></i>
        </template>
      </EmptyState>
    </div>

    <!-- Teams Grid -->
    <div
      v-else
      class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
    >
      <TeamCard
        v-for="team in teams"
        :key="team.id"
        :team="team"
        :is-toggling="togglingTeamId === team.id"
        @toggle-follow="handleToggleFollow"
      />
    </div>
  </div>
</template>
