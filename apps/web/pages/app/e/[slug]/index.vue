<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSupabaseClient, useSeoMeta } from '#imports'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import { useTriviaStore } from '~/stores/trivias'
import { useCatalog } from '~/composables/useCatalog'
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
const user = useSupabaseUser()
const triviaStore = useTriviaStore()
const { products, fetchProducts } = useCatalog()

const {
  activeTeam,
  loading: teamLoading,
  loadTeamBySlug,
  openPicker,
} = useCurrentTeam()

const togglingFollow = ref(false)
const streakData = ref<{ streak_days: number; bonus_awarded: number } | null>(null)

const teamSlug = computed(() => route.params.slug as string)

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await Promise.all([
      triviaStore.fetchHomeSummary(team.id),
      triviaStore.fetchTrivias(team.id),
      fetchProducts(team.id),
    ])

    // Load streak for this team
    if (user.value?.id) {
      try {
        const { data: streakRes } = await supabase.rpc('get_streak_info', {
          p_fan_id: user.value.id,
          p_team_id: team.id,
        })
        if (streakRes) {
          streakData.value = streakRes as any
        }
      } catch {
        // Non-blocking
      }
    }
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
    activeTeam.value ? `${activeTeam.value.name} — Fan Zone` : 'Hub de Equipo'
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
        active-tab="hub"
        :is-inactive="activeTeam.status === 'inactive'"
      />

      <!-- Main Overview Content (When active) -->
      <div v-if="activeTeam.status === 'active'" class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Daily Trivia & Streak Card -->
        <div class="bg-gradient-to-b from-slate-900 to-slate-950 border border-emerald-500/20 rounded-3xl p-6 shadow-xl flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between gap-2 mb-3">
              <span class="text-[11px] font-bold uppercase tracking-wider text-emerald-400">
                Trivia del Día
              </span>
              <div v-if="streakData && streakData.streak_days > 0" class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-950/80 border border-emerald-600/40 text-emerald-300 text-xs font-black">
                <i class="bi bi-lightning-charge-fill text-amber-400"></i>
                <span>Racha: {{ streakData.streak_days }}d</span>
              </div>
            </div>

            <h3 class="text-xl font-bold text-white mb-2">
              {{ triviaStore.homeSummary?.active_trivia?.title || 'Trivias de ' + activeTeam.short_name }}
            </h3>
            <p class="text-xs text-slate-400 line-clamp-2 mb-5">
              {{ triviaStore.homeSummary?.active_trivia?.description || 'Demuestra tus conocimientos y gana perlitas oficiales para este equipo.' }}
            </p>
          </div>

          <div class="pt-4 border-t border-slate-800/80 flex items-center justify-between">
            <span class="text-xs font-bold text-emerald-400 flex items-center gap-1">
              <PearlIcon size="xs" />
              <span>Gana perlitas</span>
            </span>

            <NuxtLink
              v-if="triviaStore.homeSummary?.active_trivia?.id"
              :to="`/app/e/${activeTeam.slug}/trivias/${triviaStore.homeSummary.active_trivia.id}`"
              class="px-5 py-2.5 rounded-xl font-display font-bold uppercase tracking-wider text-xs bg-emerald-500 hover:bg-emerald-400 text-slate-950 transition-colors shadow-md"
            >
              Jugar Ahora
            </NuxtLink>
            <NuxtLink
              v-else
              :to="`/app/e/${activeTeam.slug}/trivias`"
              class="px-5 py-2.5 rounded-xl font-display font-bold uppercase tracking-wider text-xs bg-slate-800 hover:bg-slate-700 text-white transition-colors"
            >
              Ver Trivias
            </NuxtLink>
          </div>
        </div>

        <!-- Team Store Preview Card -->
        <div class="bg-gradient-to-b from-slate-900 to-slate-950 border border-emerald-500/20 rounded-3xl p-6 shadow-xl flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between gap-2 mb-3">
              <span class="text-[11px] font-bold uppercase tracking-wider text-emerald-400">
                Catálogo de Premios
              </span>
              <span class="text-xs text-slate-400">
                {{ products.length }} premios disponibles
              </span>
            </div>

            <h3 class="text-xl font-bold text-white mb-2">
              Tienda Oficial {{ activeTeam.short_name }}
            </h3>
            <p class="text-xs text-slate-400 line-clamp-2 mb-5">
              Canjea tus perlitas acumuladas de este equipo por camisetas, gorras, accesos VIP y saludos exclusivos.
            </p>
          </div>

          <div class="pt-4 border-t border-slate-800/80 flex items-center justify-between">
            <span class="text-xs text-slate-400">
              Saldo: <strong class="text-amber-300 font-black">{{ formatPerlitas(activeTeam.balance) }}</strong>
            </span>

            <NuxtLink
              :to="`/app/e/${activeTeam.slug}/tienda`"
              class="px-5 py-2.5 rounded-xl font-display font-bold uppercase tracking-wider text-xs bg-emerald-500 hover:bg-emerald-400 text-slate-950 transition-colors shadow-md"
            >
              Ir a la Tienda
            </NuxtLink>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
