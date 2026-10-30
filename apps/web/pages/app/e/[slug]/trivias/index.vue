<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSeoMeta, useSupabaseClient } from '#imports'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import { useTriviaStore, type TriviaRow } from '~/stores/trivias'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const triviaStore = useTriviaStore()

const {
  activeTeam,
  loading: teamLoading,
  loadTeamBySlug,
  openPicker,
} = useCurrentTeam()

const togglingFollow = ref(false)
const filterStatus = ref<'all' | 'available' | 'won'>('all')

const teamSlug = computed(() => route.params.slug as string)

const filteredTrivias = computed(() => {
  const list = triviaStore.activeTrivias || []
  if (filterStatus.value === 'available') {
    return list.filter((t) => !t.is_won && t.status === 'published')
  }
  if (filterStatus.value === 'won') {
    return list.filter((t) => t.is_won)
  }
  return list
})

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await triviaStore.fetchTrivias(team.id)
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

useSeoMeta({
  title: computed(() =>
    activeTeam.value ? `Trivias de ${activeTeam.value.name} — Fan Zone` : 'Trivias de Equipo'
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

    <template v-else-if="activeTeam">
      <!-- Team Header -->
      <TeamHubHeader
        :team="activeTeam"
        :toggling="togglingFollow"
        @toggle-follow="handleToggleFollow"
        @switch-team="openPicker('trivias')"
      />

      <!-- Inactive Alert Banner -->
      <TeamHubInactiveBanner
        v-if="activeTeam.status === 'inactive'"
        :team-name="activeTeam.name"
      />

      <!-- Navigation Tabs -->
      <TeamHubTabs
        :slug="activeTeam.slug"
        active-tab="trivias"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Content Area -->
      <div v-if="activeTeam.status === 'active'" class="space-y-5">
        <!-- Filters Header -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2">
          <div>
            <h2 class="text-xl font-bold text-white">
              Trivias Oficiales
            </h2>
            <p class="text-xs text-slate-400">
              Juega y acumula perlitas exclusivas para canjear en la tienda de {{ activeTeam.name }}.
            </p>
          </div>

          <!-- Status Filters -->
          <div class="flex items-center gap-1.5 p-1 rounded-2xl bg-slate-900/80 border border-slate-800 self-start sm:self-auto">
            <button
              type="button"
              @click="filterStatus = 'all'"
              class="px-3 py-1.5 rounded-xl text-xs font-bold transition-colors cursor-pointer"
              :class="[
                filterStatus === 'all'
                  ? 'bg-emerald-500 text-slate-950 shadow-xs'
                  : 'text-slate-400 hover:text-white'
              ]"
            >
              Todas ({{ triviaStore.activeTrivias.length }})
            </button>
            <button
              type="button"
              @click="filterStatus = 'available'"
              class="px-3 py-1.5 rounded-xl text-xs font-bold transition-colors cursor-pointer"
              :class="[
                filterStatus === 'available'
                  ? 'bg-emerald-500 text-slate-950 shadow-xs'
                  : 'text-slate-400 hover:text-white'
              ]"
            >
              Disponibles
            </button>
            <button
              type="button"
              @click="filterStatus = 'won'"
              class="px-3 py-1.5 rounded-xl text-xs font-bold transition-colors cursor-pointer"
              :class="[
                filterStatus === 'won'
                  ? 'bg-emerald-500 text-slate-950 shadow-xs'
                  : 'text-slate-400 hover:text-white'
              ]"
            >
              Completadas
            </button>
          </div>
        </div>

        <!-- Trivias Grid -->
        <div v-if="triviaStore.isLoading" class="py-16 text-center text-slate-400">
          <i class="bi bi-arrow-repeat text-2xl animate-spin inline-block mb-2 text-emerald-400"></i>
          <p class="text-xs">Cargando trivias del equipo...</p>
        </div>

        <div
          v-else-if="filteredTrivias.length === 0"
          class="py-16 px-4 text-center rounded-3xl bg-slate-900/40 border border-slate-800"
        >
          <div class="w-14 h-14 mx-auto mb-3 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-500">
            <i class="bi bi-patch-question text-2xl"></i>
          </div>
          <h4 class="text-sm font-bold text-white mb-1">
            No hay trivias para mostrar
          </h4>
          <p class="text-xs text-slate-400 max-w-sm mx-auto">
            {{ filterStatus === 'won' ? 'Aún no has completado ninguna trivia de este equipo.' : 'Este equipo no tiene trivias publicadas en este momento. Vuelve más tarde.' }}
          </p>
        </div>

        <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            v-for="trivia in filteredTrivias"
            :key="trivia.id"
            class="p-5 rounded-3xl bg-gradient-to-b from-slate-900 to-slate-950 border transition-all duration-200 flex flex-col justify-between"
            :class="[
              trivia.is_won
                ? 'border-slate-800 opacity-80'
                : 'border-emerald-500/30 hover:border-emerald-500/60 shadow-lg hover:shadow-emerald-950/20'
            ]"
          >
            <div>
              <div class="flex items-center justify-between gap-2 mb-2">
                <span
                  class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md"
                  :class="[
                    trivia.is_won
                      ? 'bg-emerald-950/70 border border-emerald-800/50 text-emerald-300'
                      : 'bg-slate-800 border border-slate-700 text-slate-300'
                  ]"
                >
                  {{ trivia.is_won ? 'Completada' : 'Disponible' }}
                </span>

                <span class="text-xs text-slate-400 flex items-center gap-1">
                  <i class="bi bi-stopwatch text-xs"></i>
                  <span>{{ trivia.time_limit_seconds || 60 }}s</span>
                </span>
              </div>

              <h3 class="text-base font-bold text-white mb-1.5">
                {{ trivia.title }}
              </h3>
              <p class="text-xs text-slate-400 line-clamp-2 mb-4 leading-relaxed">
                {{ trivia.description || 'Responde correctamente para ganar perlitas de ' + activeTeam.name + '.' }}
              </p>
            </div>

            <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between">
              <span class="text-xs font-bold text-emerald-400 flex items-center gap-1.5">
                <PearlIcon size="xs" animated />
                <span>Gana perlitas</span>
              </span>

              <NuxtLink
                :to="`/app/e/${activeTeam.slug}/trivias/${trivia.id}`"
                class="px-4 py-2 rounded-xl font-display font-bold uppercase tracking-wider text-xs transition-colors shadow-sm"
                :class="[
                  trivia.is_won
                    ? 'bg-slate-800 hover:bg-slate-700 text-slate-300'
                    : 'bg-emerald-500 hover:bg-emerald-400 text-slate-950'
                ]"
              >
                {{ trivia.is_won ? 'Ver Jugada' : 'Jugar Trivia' }}
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
