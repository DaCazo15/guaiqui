<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSeoMeta, useSupabaseClient } from '#imports'
import { formatPerlitas, formatCaracas } from '@guaiqui/shared'
import { PearlIcon, BaseButton, BaseCard } from '@guaiqui/ui'
import type {
  ActiveWhoIsChallenge,
  ActiveTriviaPoll,
  ActiveOverUnder,
  ActiveMysteryPlay,
  ActiveScorePrediction,
  ActiveFlashTrivia,
  ActiveProgressiveClue,
} from '@guaiqui/shared'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import { useTriviaStore } from '~/stores/trivias'
import { useAuthStore } from '~/stores/auth'
import TeamHubHeader from '~/components/team/hub/TeamHubHeader.vue'
import TeamHubInactiveBanner from '~/components/team/hub/TeamHubInactiveBanner.vue'
import TeamHubTabs from '~/components/team/hub/TeamHubTabs.vue'
import TriviaModalitiesTabs, { type TriviaModalityId } from '~/components/trivia/TriviaModalitiesTabs.vue'
import WhoIsGameModal from '~/components/trivia/WhoIsGameModal.vue'
import PollsListSection from '~/components/trivia/PollsListSection.vue'
import PollVoteModal from '~/components/trivia/PollVoteModal.vue'
import OverUnderSection from '~/components/trivia/OverUnderSection.vue'
import MysteryPlaySection from '~/components/trivia/MysteryPlaySection.vue'
import ScorePredictionSection from '~/components/trivia/ScorePredictionSection.vue'
import FlashTriviaSection from '~/components/trivia/FlashTriviaSection.vue'
import ProgressiveCluesSection from '~/components/trivia/ProgressiveCluesSection.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const triviaStore = useTriviaStore()
const authStore = useAuthStore()

const {
  activeTeam,
  loading: teamLoading,
  loadTeamBySlug,
  openPicker,
} = useCurrentTeam()

const togglingFollow = ref(false)
const activeModalityTab = ref<TriviaModalityId>('questions')
const filterStatus = ref<'all' | 'available' | 'won'>('all')

const teamSlug = computed(() => route.params.slug as string)

// Roster players for WhoIs / Progressive clues
interface PlayerItem {
  id: string
  name: string
  jersey_number: number
  photo_url?: string | null
  position?: string
}

interface WhoIsResult {
  is_correct: boolean
  pearls_awarded: number
  correct_player?: {
    id: string
    name: string
    photo_url?: string | null
    jersey_number: number
  }
}

// Modalities state
const whoIsChallenges = ref<ActiveWhoIsChallenge[]>([])
const rosterPlayers = ref<PlayerItem[]>([])
const whoIsLoading = ref(false)
const selectedWhoIsChallenge = ref<ActiveWhoIsChallenge | null>(null)
const isWhoIsModalOpen = ref(false)

const polls = ref<ActiveTriviaPoll[]>([])
const pollsLoading = ref(false)
const selectedPoll = ref<ActiveTriviaPoll | null>(null)
const isPollModalOpen = ref(false)

const overUnderList = ref<ActiveOverUnder[]>([])
const overUnderLoading = ref(false)

const mysteryPlays = ref<ActiveMysteryPlay[]>([])
const mysteryPlaysLoading = ref(false)

const scorePredictions = ref<ActiveScorePrediction[]>([])
const scorePredictionsLoading = ref(false)

const flashChallenges = ref<ActiveFlashTrivia[]>([])
const flashLoading = ref(false)

const progressiveClues = ref<ActiveProgressiveClue[]>([])
const progressiveCluesLoading = ref(false)

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

async function callRpc<T>(fn: string): Promise<{ data: T | null; error: unknown }> {
  return (supabase as unknown as { rpc: (name: string) => Promise<{ data: T | null; error: unknown }> }).rpc(fn)
}

async function loadRosterPlayers() {
  try {
    const { data } = await supabase
      .from('players')
      .select('id, name, jersey_number, photo_url, position')
      .eq('is_active', true)
      .order('jersey_number', { ascending: true })
    if (data) rosterPlayers.value = (data as unknown as PlayerItem[]) || []
  } catch (err) {
    console.error('Error cargando plantilla:', err)
  }
}

async function loadWhoIsData() {
  whoIsLoading.value = true
  try {
    const { data } = await callRpc<ActiveWhoIsChallenge[]>('get_active_who_is_challenges')
    if (data) whoIsChallenges.value = data || []
  } catch (err) {
    console.error('Error cargando retos ¿Quién es?:', err)
  } finally {
    whoIsLoading.value = false
  }
}

async function loadPollsData() {
  pollsLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveTriviaPoll[]>('get_active_trivia_polls')
    if (error) throw error
    polls.value = data || []
  } catch (err) {
    console.error('Error cargando encuestas:', err)
  } finally {
    pollsLoading.value = false
  }
}

async function loadOverUnderData() {
  overUnderLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveOverUnder[]>('get_active_over_under_challenges')
    if (error) throw error
    overUnderList.value = data || []
  } catch (err) {
    console.error('Error cargando Mayor/Menor:', err)
  } finally {
    overUnderLoading.value = false
  }
}

async function loadMysteryPlaysData() {
  mysteryPlaysLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveMysteryPlay[]>('get_active_mystery_plays')
    if (error) throw error
    mysteryPlays.value = data || []
  } catch (err) {
    console.error('Error cargando Jugadas Misteriosas:', err)
  } finally {
    mysteryPlaysLoading.value = false
  }
}

async function loadScorePredictionsData() {
  scorePredictionsLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveScorePrediction[]>('get_active_score_predictions')
    if (error) throw error
    scorePredictions.value = data || []
  } catch (err) {
    console.error('Error cargando Marcador Exacto:', err)
  } finally {
    scorePredictionsLoading.value = false
  }
}

async function loadFlashData() {
  flashLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveFlashTrivia[]>('get_active_flash_trivia')
    if (error) throw error
    flashChallenges.value = data || []
  } catch (err) {
    console.error('Error cargando Trivias Flash:', err)
  } finally {
    flashLoading.value = false
  }
}

async function loadProgressiveCluesData() {
  progressiveCluesLoading.value = true
  try {
    const { data, error } = await callRpc<ActiveProgressiveClue[]>('get_active_progressive_clues')
    if (error) throw error
    progressiveClues.value = data || []
  } catch (err) {
    console.error('Error cargando Pistas Progresivas:', err)
  } finally {
    progressiveCluesLoading.value = false
  }
}

function openWhoIsChallenge(challenge: ActiveWhoIsChallenge) {
  selectedWhoIsChallenge.value = challenge
  isWhoIsModalOpen.value = true
}

function openPoll(poll: ActiveTriviaPoll) {
  selectedPoll.value = poll
  isPollModalOpen.value = true
}

function onPollVoted() {
  loadPollsData()
  authStore.refreshWallet()
}

function onWhoIsVoted({ challengeId, result }: { challengeId: string; result: WhoIsResult }) {
  const idx = whoIsChallenges.value.findIndex((c) => c.id === challengeId)
  if (idx !== -1) {
    whoIsChallenges.value[idx] = {
      ...whoIsChallenges.value[idx],
      has_voted: true,
      is_correct: result.is_correct,
      pearls_awarded: result.pearls_awarded,
      player_id: result.correct_player?.id,
      player_name: result.correct_player?.name,
      player_photo_url: result.correct_player?.photo_url,
      player_jersey_number: result.correct_player?.jersey_number,
    }
  }
  authStore.refreshWallet()
}

async function onOverUnderVoted() {
  await loadOverUnderData()
  authStore.refreshWallet()
}

async function onMysteryPlayVoted() {
  await loadMysteryPlaysData()
  authStore.refreshWallet()
}

async function onScorePredictionVoted() {
  await loadScorePredictionsData()
  authStore.refreshWallet()
}

async function onFlashCompleted() {
  await loadFlashData()
  authStore.refreshWallet()
}

async function onProgressiveClueVoted() {
  await loadProgressiveCluesData()
  authStore.refreshWallet()
}

const loadData = async () => {
  const currentSlug = teamSlug.value || 'guaiqueries'
  const team = await loadTeamBySlug(currentSlug)
  if (!team) return

  if (team.status === 'active') {
    await Promise.all([
      triviaStore.fetchTrivias(team.id),
      loadRosterPlayers(),
      loadWhoIsData(),
      loadPollsData(),
      loadOverUnderData(),
      loadMysteryPlaysData(),
      loadScorePredictionsData(),
      loadFlashData(),
      loadProgressiveCluesData(),
    ])
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
      <div class="h-40 rounded-3xl bg-slate-100 border border-slate-200"></div>
      <div class="h-10 w-64 rounded-xl bg-slate-100"></div>
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
      <div v-if="activeTeam.status === 'active'" class="space-y-6">
        <!-- Section Title (High Contrast on White Background) -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2">
          <div>
            <h2 class="font-display font-extrabold text-2xl sm:text-3xl text-guaiqui-text uppercase tracking-wide">
              Trivias & Retos de {{ activeTeam.name }}
            </h2>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted mt-0.5">
              Demuestra tu pasión por el club, acumula perlitas exclusivas y canjea premios oficiales.
            </p>
          </div>
        </div>

        <!-- Barra de Clasificación de Modalidades de Trivia (8 Tipos) -->
        <TriviaModalitiesTabs
          v-model:active-tab="activeModalityTab"
        />

        <!-- MODALIDAD 1: TRIVIAS CLÁSICAS -->
        <div v-if="activeModalityTab === 'questions'" class="space-y-5">
          <!-- Status Filters -->
          <div class="flex items-center justify-between gap-3">
            <span class="text-xs font-bold text-guaiqui-text-muted uppercase tracking-wider">
              Preguntas de Conocimiento
            </span>

            <div class="flex items-center gap-1.5 p-1 rounded-2xl bg-slate-100 border border-slate-200">
              <button
                type="button"
                @click="filterStatus = 'all'"
                class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer"
                :class="[
                  filterStatus === 'all'
                    ? 'bg-guaiqui-primary text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                ]"
              >
                Todas ({{ triviaStore.activeTrivias.length }})
              </button>
              <button
                type="button"
                @click="filterStatus = 'available'"
                class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer"
                :class="[
                  filterStatus === 'available'
                    ? 'bg-guaiqui-primary text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                ]"
              >
                Disponibles
              </button>
              <button
                type="button"
                @click="filterStatus = 'won'"
                class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer"
                :class="[
                  filterStatus === 'won'
                    ? 'bg-guaiqui-primary text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                ]"
              >
                Completadas
              </button>
            </div>
          </div>

          <!-- Trivias Grid -->
          <div v-if="triviaStore.isLoading" class="py-16 text-center text-slate-500">
            <i class="bi bi-arrow-repeat text-2xl animate-spin inline-block mb-2 text-guaiqui-primary"></i>
            <p class="text-xs font-medium">Cargando trivias del equipo...</p>
          </div>

          <div
            v-else-if="filteredTrivias.length === 0"
            class="py-16 px-4 text-center rounded-3xl bg-white border border-guaiqui-border shadow-xs"
          >
            <div class="w-14 h-14 mx-auto mb-3 rounded-2xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-400">
              <i class="bi bi-patch-question text-2xl"></i>
            </div>
            <h4 class="text-base font-bold text-guaiqui-text mb-1">
              No hay trivias para mostrar
            </h4>
            <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto">
              {{ filterStatus === 'won' ? 'Aún no has completado ninguna trivia de este equipo.' : 'Este equipo no tiene trivias publicadas en este momento. Vuelve más tarde.' }}
            </p>
          </div>

          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div
              v-for="trivia in filteredTrivias"
              :key="trivia.id"
              class="p-5 rounded-3xl bg-gradient-to-b from-slate-900 via-slate-900 to-slate-950 border transition-all duration-200 flex flex-col justify-between shadow-md"
              :class="[
                trivia.is_won
                  ? 'border-slate-800 opacity-85'
                  : 'border-emerald-500/30 hover:border-emerald-500/60 hover:shadow-emerald-950/20'
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

                  <span class="text-xs text-slate-400 flex items-center gap-1 font-mono">
                    <i class="bi bi-stopwatch text-xs"></i>
                    <span>{{ trivia.time_limit_seconds || 60 }}s</span>
                  </span>
                </div>

                <h3 class="text-base font-bold text-white mb-1.5 leading-snug">
                  {{ trivia.title }}
                </h3>
                <p class="text-xs text-slate-300 line-clamp-2 mb-4 leading-relaxed font-normal">
                  {{ trivia.description || 'Responde correctamente para ganar perlitas de ' + activeTeam.name + '.' }}
                </p>
              </div>

              <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between">
                <span class="text-xs font-bold text-amber-300 flex items-center gap-1.5">
                  <PearlIcon size="xs" animated />
                  <span>Gana perlitas</span>
                </span>

                <NuxtLink
                  :to="`/app/e/${activeTeam.slug}/trivias/${trivia.id}`"
                  class="px-4 py-2 rounded-xl font-display font-bold uppercase tracking-wider text-xs transition-colors shadow-sm"
                  :class="[
                    trivia.is_won
                      ? 'bg-slate-800 hover:bg-slate-700 text-slate-200'
                      : 'bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white'
                  ]"
                >
                  {{ trivia.is_won ? 'Ver Jugada' : 'Jugar Trivia' }}
                </NuxtLink>
              </div>
            </div>
          </div>
        </div>

        <!-- MODALIDAD 2: «¿QUIÉN ES?» -->
        <div v-else-if="activeModalityTab === 'who_is'" class="space-y-4">
          <div v-if="whoIsLoading" class="space-y-4">
            <BaseCard v-for="i in 2" :key="i" class="p-6 bg-slate-900 border-slate-800 animate-pulse h-40 rounded-3xl" />
          </div>

          <div v-else-if="whoIsChallenges.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div
              v-for="c in whoIsChallenges"
              :key="c.id"
              class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border-2 border-emerald-500/30 p-5 text-white shadow-xl flex flex-col justify-between gap-5 group hover:border-emerald-400/60 transition-all duration-300"
            >
              <div class="absolute -top-12 -right-12 w-40 h-40 bg-emerald-500/15 blur-2xl pointer-events-none"></div>

              <div>
                <div class="flex items-center justify-between gap-2 pb-3 border-b border-emerald-500/20 text-xs">
                  <span
                    class="px-2.5 py-0.5 rounded-full font-bold uppercase text-[10px] tracking-wider"
                    :class="c.challenge_type === 'silhouette'
                      ? 'bg-purple-950/80 text-purple-300 border border-purple-700/60'
                      : 'bg-emerald-900/80 text-emerald-300 border border-emerald-600/60'"
                  >
                    <i :class="['bi', c.challenge_type === 'silhouette' ? 'bi-incognito' : 'bi-123', 'mr-1']"></i>
                    {{ c.challenge_type === 'silhouette' ? 'Modo Silueta' : 'Modo Dorsal' }}
                  </span>

                  <span class="font-mono font-bold text-amber-300 bg-emerald-950/80 px-2.5 py-0.5 rounded-full border border-emerald-500/30 text-[11px] flex items-center gap-1">
                    <i class="bi bi-gem"></i> +{{ c.reward_pearls }} perlitas
                  </span>
                </div>

                <div class="flex items-center gap-4 py-4">
                  <div class="relative w-20 h-20 rounded-2xl bg-slate-950/90 border border-emerald-500/40 p-1.5 flex items-center justify-center shrink-0 overflow-hidden shadow-inner">
                    <template v-if="c.challenge_type === 'dorsal'">
                      <div class="flex flex-col items-center justify-center font-display font-black text-emerald-400 text-xl leading-none">
                        <span class="text-[8px] text-emerald-200 font-bold uppercase">Dorsal</span>
                        #{{ c.has_voted ? c.player_jersey_number : c.dorsal_number }}
                      </div>
                    </template>
                    <template v-else>
                      <img
                        :src="c.has_voted ? (c.player_photo_url || '/logo.png') : (c.custom_image_url || '/logo.png')"
                        :alt="c.title"
                        class="w-full h-full object-contain"
                        :class="c.has_voted ? 'filter-none' : 'filter brightness-0 contrast-200'"
                      />
                    </template>

                    <span v-if="c.has_voted" class="absolute bottom-0 inset-x-0 bg-emerald-600 text-slate-950 text-[8px] font-black uppercase text-center py-0.2">
                      Revelado
                    </span>
                  </div>

                  <div class="min-w-0 flex-1">
                    <h3 class="font-display font-black text-lg text-white uppercase tracking-tight leading-snug">
                      {{ c.title }}
                    </h3>
                    <p v-if="c.clue" class="text-xs text-emerald-200/80 italic mt-1 truncate">
                      Pista: "{{ c.clue }}"
                    </p>
                    <span v-if="c.has_voted" class="text-xs text-slate-300 font-semibold block mt-1">
                      Solución: <strong class="text-white">{{ c.player_name }}</strong> (#{{ c.player_jersey_number }})
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex items-center justify-between gap-3 pt-3 border-t border-emerald-500/20">
                <div>
                  <template v-if="c.has_voted">
                    <span
                      class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider"
                      :class="c.is_correct ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40' : 'bg-rose-500/20 text-rose-300 border border-rose-500/40'"
                    >
                      <i :class="['bi', c.is_correct ? 'bi-check-circle-fill text-emerald-400' : 'bi-x-circle-fill text-rose-400']"></i>
                      {{ c.is_correct ? '¡Acertaste!' : 'Fallaste' }}
                    </span>
                  </template>
                  <template v-else>
                    <span class="text-[11px] text-slate-400 flex items-center gap-1">
                      <i class="bi bi-clock-history text-emerald-400"></i>
                      1 intento al votar
                    </span>
                  </template>
                </div>

                <BaseButton
                  :variant="c.has_voted ? 'secondary' : 'primary'"
                  size="sm"
                  @click="openWhoIsChallenge(c)"
                >
                  <i :class="['bi', c.has_voted ? 'bi-eye' : 'bi-play-fill', 'mr-1']"></i>
                  {{ c.has_voted ? 'Ver Resultado' : 'Adivinar Jugador' }}
                </BaseButton>
              </div>
            </div>
          </div>

          <div v-else class="p-12 text-center rounded-3xl bg-white border border-guaiqui-border shadow-xs space-y-3">
            <div class="w-16 h-16 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-3xl text-emerald-600 mx-auto">
              <i class="bi bi-incognito"></i>
            </div>
            <h3 class="font-display font-extrabold text-xl text-guaiqui-text uppercase tracking-wider">No hay retos activos</h3>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted max-w-md mx-auto">
              Próximamente se publicarán nuevos retos de «¿Quién es este jugador?» para poner a prueba tu memoria con la silueta y dorsales de la plantilla.
            </p>
          </div>
        </div>

        <!-- MODALIDAD 3: ENCUESTAS & PREDICCIONES -->
        <PollsListSection
          v-else-if="activeModalityTab === 'polls'"
          :polls="polls"
          :loading="pollsLoading"
          @select-poll="openPoll"
        />

        <!-- MODALIDAD 4: MAYOR O MENOR (OVER / UNDER) -->
        <OverUnderSection
          v-else-if="activeModalityTab === 'over_under'"
          :items="overUnderList"
          :loading="overUnderLoading"
          @voted="onOverUnderVoted"
        />

        <!-- MODALIDAD 5: «¿QUÉ PASÓ DESPUÉS?» -->
        <MysteryPlaySection
          v-else-if="activeModalityTab === 'mystery_plays'"
          :items="mysteryPlays"
          :loading="mysteryPlaysLoading"
          @voted="onMysteryPlayVoted"
        />

        <!-- MODALIDAD 6: MARCADOR EXACTO -->
        <ScorePredictionSection
          v-else-if="activeModalityTab === 'score_predictions'"
          :items="scorePredictions"
          :loading="scorePredictionsLoading"
          @voted="onScorePredictionVoted"
        />

        <!-- MODALIDAD 7: TRIVIA FLASH 60s -->
        <FlashTriviaSection
          v-else-if="activeModalityTab === 'flash_trivia'"
          :items="flashChallenges"
          :loading="flashLoading"
          @completed="onFlashCompleted"
        />

        <!-- MODALIDAD 8: PISTAS PROGRESIVAS -->
        <ProgressiveCluesSection
          v-else-if="activeModalityTab === 'progressive_clues'"
          :items="progressiveClues"
          :roster-players="rosterPlayers"
          :loading="progressiveCluesLoading"
          @voted="onProgressiveClueVoted"
        />

        <!-- Modal Interactivo "¿Quién es?" -->
        <WhoIsGameModal
          :is-open="isWhoIsModalOpen"
          :challenge="selectedWhoIsChallenge"
          :players="rosterPlayers"
          @close="isWhoIsModalOpen = false"
          @voted="onWhoIsVoted"
        />

        <!-- Modal Interactivo Encuestas de Partido -->
        <PollVoteModal
          :is-open="isPollModalOpen"
          :poll="selectedPoll"
          @close="isPollModalOpen = false"
          @voted="onPollVoted"
        />
      </div>
    </template>
  </div>
</template>
