<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type {
  ActiveWhoIsChallenge,
  ActiveTriviaPoll,
  ActiveOverUnder,
  ActiveMysteryPlay,
  ActiveScorePrediction,
  ActiveFlashTrivia,
  ActiveProgressiveClue
} from '@guaiqui/shared'
import { useTriviaStore } from '~/stores/trivias'
import { useAuthStore } from '~/stores/auth'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TriviaPlayButton from '~/components/app/dashboard/TriviaPlayButton.vue'
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

useSeoMeta({
  title: 'Zona de Trivias & Juegos — Guaiqueríes de Margarita',
  description: 'Participa en trivias oficiales, siluetas de «¿Quién es?», pronósticos Over/Under, jugadas misteriosas, marcador exacto, flash 60s y gana perlitas.',
})

const supabase = useSupabaseClient()
const triviaStore = useTriviaStore()
const authStore = useAuthStore()
const { openPicker, fetchFollowedTeams } = useCurrentTeam()

type MainTab =
  | 'questions'
  | 'who_is'
  | 'polls'
  | 'over_under'
  | 'mystery_plays'
  | 'score_predictions'
  | 'flash_trivia'
  | 'progressive_clues'

const activeTab = ref<MainTab>('questions')

const tabs = [
  { id: 'questions' as const, label: 'Trivias Clásicas', icon: 'bi-question-diamond-fill', badge: 'Preguntas' },
  { id: 'who_is' as const, label: '«¿Quién es?»', icon: 'bi-person-bounding-box', badge: 'Reto' },
  { id: 'polls' as const, label: 'Encuestas', icon: 'bi-bar-chart-fill', badge: 'Partido' },
  { id: 'over_under' as const, label: 'Mayor o Menor', icon: 'bi-arrow-down-up', badge: 'Líneas' },
  { id: 'mystery_plays' as const, label: '¿Qué pasó después?', icon: 'bi-play-circle-fill', badge: 'Video' },
  { id: 'score_predictions' as const, label: 'Marcador Exacto', icon: 'bi-bullseye', badge: 'El Bote' },
  { id: 'flash_trivia' as const, label: 'Trivia Flash', icon: 'bi-stopwatch-fill', badge: '60s' },
  { id: 'progressive_clues' as const, label: 'Pistas Progresivas', icon: 'bi-puzzle-fill', badge: 'Escalón' },
]

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

// State for each modality
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

onMounted(async () => {
  const teams = await fetchFollowedTeams()
  if (!teams || teams.length === 0) {
    openPicker('trivias')
    return
  }

  try {
    const storedSlug = typeof window !== 'undefined' ? window.localStorage?.getItem('guaiqui_active_team_slug') : null
    const targetTeam = teams.find(t => t.slug === storedSlug) || teams[0]
    if (targetTeam) {
      await navigateTo(`/app/e/${targetTeam.slug}/trivias`)
      return
    }
  } catch {
    // Non-blocking
  }

  await Promise.all([
    triviaStore.fetchTrivias(),
    loadRosterPlayers(),
    loadWhoIsData(),
    loadPollsData(),
    loadOverUnderData(),
    loadMysteryPlaysData(),
    loadScorePredictionsData(),
    loadFlashData(),
    loadProgressiveCluesData()
  ])
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
    const { data, error } = await callRpc<ActiveOverUnder[]>('get_active_over_under_predictions')
    if (error) throw error
    overUnderList.value = data || []
  } catch (err) {
    console.error('Error cargando Over/Under:', err)
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
    console.error('Error cargando Trivia Flash:', err)
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

// Handlers for voting and events
function openPoll(poll: ActiveTriviaPoll) {
  selectedPoll.value = poll
  isPollModalOpen.value = true
}

async function onPollVoted({ pollId }: { pollId: string }) {
  await loadPollsData()
  if (selectedPoll.value && selectedPoll.value.id === pollId) {
    const updated = polls.value.find(p => p.id === pollId)
    if (updated) selectedPoll.value = updated
  }
  authStore.fetchProfile()
}

function openWhoIsChallenge(challenge: ActiveWhoIsChallenge) {
  selectedWhoIsChallenge.value = challenge
  isWhoIsModalOpen.value = true
}

function onWhoIsVoted({ challengeId, result }: { challengeId: string; result: WhoIsResult }) {
  const idx = whoIsChallenges.value.findIndex(c => c.id === challengeId)
  if (idx !== -1) {
    whoIsChallenges.value[idx] = {
      ...whoIsChallenges.value[idx],
      has_voted: true,
      is_correct: result.is_correct,
      pearls_awarded: result.pearls_awarded,
      player_id: result.correct_player?.id,
      player_name: result.correct_player?.name,
      player_photo_url: result.correct_player?.photo_url,
      player_jersey_number: result.correct_player?.jersey_number
    }
  }
  authStore.fetchProfile()
}

async function onOverUnderVoted() {
  await loadOverUnderData()
  authStore.fetchProfile()
}

async function onMysteryPlayVoted() {
  await loadMysteryPlaysData()
  authStore.fetchProfile()
}

async function onScorePredictionVoted() {
  await loadScorePredictionsData()
  authStore.fetchProfile()
}

async function onFlashCompleted() {
  await loadFlashData()
  authStore.fetchProfile()
}

async function onProgressiveClueVoted() {
  await loadProgressiveCluesData()
  authStore.fetchProfile()
}

function getStatusBadge(trivia: { is_won?: boolean; starts_at: string; ends_at: string; status: string }) {
  if (trivia.is_won) {
    return { label: 'Ganada', class: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30' }
  }
  const now = new Date().getTime()
  const start = new Date(trivia.starts_at).getTime()
  const end = new Date(trivia.ends_at).getTime()

  if (trivia.status !== 'published') {
    return { label: 'Borrador', class: 'bg-gray-500/10 text-gray-400 border-gray-500/30' }
  }
  if (now < start) {
    return { label: 'Próxima', class: 'bg-blue-500/10 text-blue-400 border-blue-500/30' }
  }
  if (now > end) {
    return { label: 'Cerrada', class: 'bg-red-500/10 text-red-400 border-red-500/30' }
  }
  return { label: 'Disponible', class: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' }
}

function getEstimatedReward(t: { reward_rules?: unknown }): number {
  const rules = t?.reward_rules as { per_correct_pearls?: number; perfect_score_bonus?: number } | null
  const perCorrect = Number(rules?.per_correct_pearls) || 50
  const bonus = Number(rules?.perfect_score_bonus) || 100
  return perCorrect + bonus
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header Page -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div class="space-y-1">
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Zona de Juegos & <span class="text-guaiqui-primary">Trivias</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Compite, pon a prueba tus conocimientos sobre Guaiqueríes de Margarita y gana perlitas en cada modalidad.
        </p>
      </div>
    </div>

    <!-- Main Tabs Bar (Responsive 8 Modalities) -->
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 p-1.5 bg-slate-100 rounded-2xl border border-guaiqui-border shadow-inner">
      <button
        v-for="t in tabs"
        :key="t.id"
        type="button"
        @click="activeTab = t.id"
        :class="[
          'px-3 py-2.5 rounded-xl text-left transition-all duration-200 flex items-center gap-2.5',
          activeTab === t.id
            ? 'bg-guaiqui-primary text-white shadow-md'
            : 'text-guaiqui-text-muted hover:text-guaiqui-text hover:bg-white/80'
        ]"
      >
        <div
          class="w-7 h-7 rounded-lg flex items-center justify-center text-sm shrink-0"
          :class="activeTab === t.id ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700'"
        >
          <i :class="['bi', t.icon]"></i>
        </div>
        <div class="min-w-0 flex-1">
          <div class="font-display font-bold text-xs tracking-tight uppercase truncate">
            {{ t.label }}
          </div>
          <span
            class="text-[9px] px-1.5 py-0.2 rounded font-mono font-bold uppercase"
            :class="activeTab === t.id ? 'bg-emerald-800 text-emerald-100' : 'bg-slate-200 text-slate-600'"
          >
            {{ t.badge }}
          </span>
        </div>
      </button>
    </div>

    <!-- PESTAÑA 1: TRIVIAS CLÁSICAS -->
    <div v-if="activeTab === 'questions'" class="space-y-4">
      <div v-if="triviaStore.isLoading" class="space-y-4">
        <BaseCard v-for="i in 3" :key="i" class="p-6 bg-guaiqui-surface border-guaiqui-border animate-pulse h-32" />
      </div>

      <div v-else-if="triviaStore.activeTrivias.length > 0" class="grid gap-4">
        <BaseCard
          v-for="t in triviaStore.activeTrivias"
          :key="t.id"
          class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl hover:border-guaiqui-primary transition-all duration-200 shadow-guaiqui-sm"
        >
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div class="space-y-2">
              <div class="flex items-center gap-3">
                <h2 class="font-display text-xl font-bold text-guaiqui-text">
                  {{ t.title }}
                </h2>
                <span
                  class="px-2.5 py-0.5 text-xs rounded-full border font-medium"
                  :class="getStatusBadge(t).class"
                >
                  {{ getStatusBadge(t).label }}
                </span>
              </div>

              <p class="text-sm text-guaiqui-text-muted">
                {{ t.description || 'Pon a prueba tus conocimientos sobre la historia y plantilla del equipo.' }}
              </p>

              <div class="flex flex-wrap items-center gap-4 text-xs text-guaiqui-text-muted pt-1">
                <span class="flex items-center gap-1">
                  <i class="bi bi-calendar-event text-guaiqui-primary"></i>
                  Inicio: {{ formatCaracas(t.starts_at) }}
                </span>
                <span class="flex items-center gap-1">
                  Recompensa estimada: <PearlAmount :amount="getEstimatedReward(t)" size="sm" />
                </span>
              </div>
            </div>

            <div class="flex items-center gap-3">
              <template v-if="t.is_won">
                <BaseButton variant="secondary" size="md" :disabled="true" class="opacity-60 cursor-not-allowed">
                  <span>Trivia Ganada</span>
                  <i class="bi bi-check-circle-fill ml-1.5 text-emerald-600"></i>
                </BaseButton>
              </template>
              <template v-else>
                <TriviaPlayButton
                  :trivia-id="t.id"
                  label="Jugar Trivia"
                />
              </template>
            </div>
          </div>
        </BaseCard>
      </div>

      <BaseCard v-else class="p-12 text-center bg-white border-guaiqui-border rounded-guaiqui-xl space-y-3 shadow-guaiqui-sm">
        <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
          <i class="bi bi-dribbble"></i>
        </div>
        <h3 class="text-lg font-bold text-guaiqui-text">No hay trivias publicadas</h3>
        <p class="text-sm text-guaiqui-text-muted max-w-sm mx-auto">
          Pronto publicaremos nuevas trivias para que sumes puntos. ¡Mantente atento a los anuncios!
        </p>
      </BaseCard>
    </div>

    <!-- PESTAÑA 2: «¿QUIÉN ES?» -->
    <div v-else-if="activeTab === 'who_is'" class="space-y-4">
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

      <div v-else class="p-12 text-center rounded-3xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border border-emerald-500/30 text-white space-y-3 shadow-xl">
        <div class="w-16 h-16 rounded-2xl bg-emerald-500/20 border border-emerald-400/40 flex items-center justify-center text-3xl text-emerald-400 mx-auto shadow-inner">
          <i class="bi bi-incognito"></i>
        </div>
        <h3 class="font-display font-extrabold text-xl uppercase tracking-wider">No hay retos activos</h3>
        <p class="text-xs sm:text-sm text-slate-300 max-w-md mx-auto">
          Próximamente la administración publicará nuevos retos de «¿Quién es este jugador?» para que pongas a prueba tu memoria con la silueta y dorsales de la plantilla.
        </p>
      </div>
    </div>

    <!-- PESTAÑA 3: ENCUESTAS & PREDICCIONES -->
    <PollsListSection
      v-else-if="activeTab === 'polls'"
      :polls="polls"
      :loading="pollsLoading"
      @select-poll="openPoll"
    />

    <!-- PESTAÑA 4: MAYOR O MENOR (OVER / UNDER) -->
    <OverUnderSection
      v-else-if="activeTab === 'over_under'"
      :items="overUnderList"
      :loading="overUnderLoading"
      @voted="onOverUnderVoted"
    />

    <!-- PESTAÑA 5: «¿QUÉ PASÓ DESPUÉS?» -->
    <MysteryPlaySection
      v-else-if="activeTab === 'mystery_plays'"
      :items="mysteryPlays"
      :loading="mysteryPlaysLoading"
      @voted="onMysteryPlayVoted"
    />

    <!-- PESTAÑA 6: MARCADOR EXACTO -->
    <ScorePredictionSection
      v-else-if="activeTab === 'score_predictions'"
      :items="scorePredictions"
      :loading="scorePredictionsLoading"
      @voted="onScorePredictionVoted"
    />

    <!-- PESTAÑA 7: TRIVIA FLASH 60s -->
    <FlashTriviaSection
      v-else-if="activeTab === 'flash_trivia'"
      :items="flashChallenges"
      :loading="flashLoading"
      @completed="onFlashCompleted"
    />

    <!-- PESTAÑA 8: PISTAS PROGRESIVAS -->
    <ProgressiveCluesSection
      v-else-if="activeTab === 'progressive_clues'"
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
