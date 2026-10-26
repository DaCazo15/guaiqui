<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseModal, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveProgressiveClue } from '@guaiqui/shared'

const props = defineProps<{
  items: ActiveProgressiveClue[]
  rosterPlayers: Array<{ id: string; name: string; jersey_number: number; photo_url?: string | null }>
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'voted', payload: { challengeId: string; playerId: string; result: any }): void
}>()

const supabase = useSupabaseClient()
const selectedChallenge = ref<ActiveProgressiveClue | null>(null)
const cluesRevealedCount = ref(1)
const selectedPlayerId = ref<string>('')
const isModalOpen = ref(false)
const isSubmitting = ref(false)
const resultData = ref<any | null>(null)
const errorMessage = ref<string | null>(null)

const openChallengeModal = (item: ActiveProgressiveClue) => {
  selectedChallenge.value = item
  cluesRevealedCount.value = item.user_vote?.clues_revealed_count || 1
  selectedPlayerId.value = ''
  resultData.value = item.user_vote || null
  errorMessage.value = null
  isModalOpen.value = true
}

const revealNextClue = () => {
  if (cluesRevealedCount.value < 3) {
    cluesRevealedCount.value++
  }
}

const submitGuess = async () => {
  if (!selectedChallenge.value || !selectedPlayerId.value) {
    errorMessage.value = 'Selecciona al jugador que crees que es el misterioso.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('submit_progressive_clue_vote', {
      p_challenge_id: selectedChallenge.value.id,
      p_selected_player_id: selectedPlayerId.value,
      p_clues_revealed_count: cluesRevealedCount.value
    })

    if (error) throw error

    resultData.value = data
    emit('voted', {
      challengeId: selectedChallenge.value.id,
      playerId: selectedPlayerId.value,
      result: data
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al enviar respuesta'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard v-for="i in 2" :key="i" class="p-6 bg-white border border-guaiqui-border animate-pulse h-44" />
    </div>

    <div v-else-if="items.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard
        v-for="item in items"
        :key="item.id"
        class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between transition hover:border-guaiqui-primary"
      >
        <div class="space-y-3">
          <div class="flex items-center justify-between border-b border-slate-100 pb-2.5">
            <span class="px-2.5 py-1 rounded-lg text-xs font-black bg-emerald-950 text-emerald-400 font-mono">
              PISTAS ESCALONADAS
            </span>
            <div class="flex items-center gap-1 text-xs text-amber-700 font-bold bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
              <i class="bi bi-gem"></i> Hasta +{{ item.pearls_clue_1 }}
            </div>
          </div>

          <div>
            <h3 class="font-display font-bold text-base text-guaiqui-text leading-snug">
              {{ item.title }}
            </h3>
            <p v-if="item.description" class="text-xs text-guaiqui-text-muted mt-1">
              {{ item.description }}
            </p>
          </div>

          <!-- Clue 1 preview -->
          <div class="p-3 bg-slate-50 border border-slate-200 rounded-xl space-y-1">
            <div class="text-[11px] font-bold text-red-600 uppercase tracking-wider flex items-center gap-1">
              <i class="bi bi-search"></i> Pista #1 (Máximo Premio)
            </div>
            <div class="text-xs text-slate-800 line-clamp-2">
              "{{ item.clue_1 }}"
            </div>
          </div>
        </div>

        <div class="pt-4 mt-3 border-t border-slate-100 flex items-center justify-between">
          <span class="text-[11px] text-slate-400 font-mono">
            Cierra: {{ formatCaracas(item.closes_at) }}
          </span>

          <div v-if="item.user_vote" class="text-xs">
            <span v-if="item.user_vote.is_correct" class="font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 inline-flex items-center gap-1">
              <i class="bi bi-check-circle-fill"></i> ¡Acertaste en pista {{ item.user_vote.clues_revealed_count }}! +{{ item.user_vote.pearls_awarded }}
            </span>
            <span v-else class="font-semibold text-slate-600 bg-slate-100 px-2.5 py-1 rounded-full border border-slate-300 inline-block">
              No acertaste (Era {{ item.target_player_name }})
            </span>
          </div>

          <BaseButton
            v-else
            variant="primary"
            size="sm"
            @click="openChallengeModal(item)"
          >
            <i class="bi bi-eye-fill me-1"></i> Adivinar Jugador
          </BaseButton>
        </div>
      </BaseCard>
    </div>

    <!-- Empty State -->
    <div v-else class="p-8 text-center bg-white rounded-2xl border border-guaiqui-border space-y-2">
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-xl">
        <i class="bi bi-puzzle"></i>
      </div>
      <h3 class="font-display font-bold text-slate-700 text-base">No hay desafíos de pistas progresivas activos</h3>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Pronto tendremos un nuevo jugador misterioso para descifrar con la menor cantidad de pistas.
      </p>
    </div>

    <!-- Game Modal -->
    <BaseModal v-model="isModalOpen" :title="selectedChallenge?.title || 'Jugador Misterioso'" size="lg">
      <div v-if="selectedChallenge" class="space-y-4 text-left">
        <!-- Results Banner if already played -->
        <div v-if="resultData" class="p-4 rounded-xl border text-sm" :class="resultData.is_correct ? 'bg-emerald-50 border-emerald-300 text-emerald-900' : 'bg-slate-100 border-slate-300 text-slate-800'">
          <div class="flex items-center gap-2 font-bold text-base">
            <i :class="resultData.is_correct ? 'bi bi-check-circle-fill text-emerald-600' : 'bi bi-x-circle-fill text-slate-500'"></i>
            <span>{{ resultData.is_correct ? '¡Acertaste al jugador misterioso!' : 'No acertaste esta vez' }}</span>
          </div>
          <p class="text-xs mt-1">
            El jugador misterioso era: <strong class="text-emerald-800 text-sm">{{ resultData.target_player_name }}</strong>
            <span v-if="resultData.pearls_awarded > 0"> ¡Has ganado <strong class="text-amber-800">+{{ resultData.pearls_awarded }} perlitas</strong>!</span>
          </p>
        </div>

        <!-- Clues Progression Cards -->
        <div class="space-y-2.5">
          <!-- Clue 1 -->
          <div class="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl space-y-1">
            <div class="flex items-center justify-between text-xs">
              <span class="font-bold text-red-700 flex items-center gap-1">
                <i class="bi bi-key-fill"></i> Pista #1 (Difícil)
              </span>
              <span class="font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded-full">
                +{{ selectedChallenge.pearls_clue_1 }} Perlitas
              </span>
            </div>
            <p class="text-xs text-slate-800 font-semibold">{{ selectedChallenge.clue_1 }}</p>
          </div>

          <!-- Clue 2 -->
          <div v-if="cluesRevealedCount >= 2" class="p-3.5 bg-amber-50 border border-amber-200 rounded-xl space-y-1">
            <div class="flex items-center justify-between text-xs">
              <span class="font-bold text-amber-800 flex items-center gap-1">
                <i class="bi bi-key-fill"></i> Pista #2 (Media)
              </span>
              <span class="font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded-full">
                +{{ selectedChallenge.pearls_clue_2 }} Perlitas
              </span>
            </div>
            <p class="text-xs text-slate-800 font-semibold">{{ selectedChallenge.clue_2 }}</p>
          </div>
          <button
            v-else-if="!resultData"
            type="button"
            @click="revealNextClue"
            class="w-full py-2.5 px-4 rounded-xl border border-dashed border-amber-400 bg-amber-50/50 hover:bg-amber-100/60 text-xs font-bold text-amber-900 transition flex items-center justify-center gap-2"
          >
            <i class="bi bi-unlock-fill"></i>
            Desbloquear Pista #2 (El premio pasa a +{{ selectedChallenge.pearls_clue_2 }} perlitas)
          </button>

          <!-- Clue 3 -->
          <div v-if="cluesRevealedCount >= 3" class="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl space-y-1">
            <div class="flex items-center justify-between text-xs">
              <span class="font-bold text-emerald-800 flex items-center gap-1">
                <i class="bi bi-key-fill"></i> Pista #3 (Fácil)
              </span>
              <span class="font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded-full">
                +{{ selectedChallenge.pearls_clue_3 }} Perlitas
              </span>
            </div>
            <p class="text-xs text-slate-800 font-semibold">{{ selectedChallenge.clue_3 }}</p>
          </div>
          <button
            v-else-if="cluesRevealedCount === 2 && !resultData"
            type="button"
            @click="revealNextClue"
            class="w-full py-2.5 px-4 rounded-xl border border-dashed border-emerald-400 bg-emerald-50/50 hover:bg-emerald-100/60 text-xs font-bold text-emerald-900 transition flex items-center justify-center gap-2"
          >
            <i class="bi bi-unlock-fill"></i>
            Desbloquear Pista #3 (El premio pasa a +{{ selectedChallenge.pearls_clue_3 }} perlitas)
          </button>
        </div>

        <!-- Player Selection -->
        <div v-if="!resultData" class="space-y-2 pt-2 border-t border-slate-200">
          <label class="text-xs font-bold text-slate-700 block">
            ¿Quién es el jugador misterioso? (Selecciona de la plantilla):
          </label>
          <select
            v-model="selectedPlayerId"
            class="w-full px-3 py-2.5 rounded-xl border border-slate-300 text-sm bg-white text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500 font-medium"
          >
            <option value="" disabled>Selecciona un jugador...</option>
            <option v-for="p in rosterPlayers" :key="p.id" :value="p.id">
              #{{ p.jersey_number }} - {{ p.name }}
            </option>
          </select>
        </div>

        <div v-if="errorMessage" class="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ errorMessage }}</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="isModalOpen = false">
            {{ resultData ? 'Cerrar' : 'Cancelar' }}
          </BaseButton>
          <BaseButton
            v-if="!resultData"
            variant="primary"
            size="sm"
            :disabled="!selectedPlayerId || isSubmitting"
            :loading="isSubmitting"
            @click="submitGuess"
          >
            Confirmar y Enviar Respuesta
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
