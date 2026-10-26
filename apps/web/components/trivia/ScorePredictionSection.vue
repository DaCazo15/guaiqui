<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseModal, BaseInput, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveScorePrediction } from '@guaiqui/shared'

const props = defineProps<{
  items: ActiveScorePrediction[]
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'voted', payload: { predictionId: string; guaiquiScore: number; rivalScore: number }): void
}>()

const supabase = useSupabaseClient()
const selectedPrediction = ref<ActiveScorePrediction | null>(null)
const guaiquiScore = ref<number | ''>('')
const rivalScore = ref<number | ''>('')
const isModalOpen = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const openPredictModal = (item: ActiveScorePrediction) => {
  if (item.user_vote) return
  selectedPrediction.value = item
  guaiquiScore.value = ''
  rivalScore.value = ''
  errorMessage.value = null
  successMessage.value = null
  isModalOpen.value = true
}

const submitPrediction = async () => {
  if (!selectedPrediction.value || guaiquiScore.value === '' || rivalScore.value === '') {
    errorMessage.value = 'Ingresa los puntos para ambos equipos.'
    return
  }
  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('submit_score_prediction_vote', {
      p_prediction_id: selectedPrediction.value.id,
      p_guaiqueries_score: Number(guaiquiScore.value),
      p_rival_score: Number(rivalScore.value)
    })

    if (error) throw error

    successMessage.value = data?.message || '¡Marcador registrado con éxito!'
    emit('voted', {
      predictionId: selectedPrediction.value.id,
      guaiquiScore: Number(guaiquiScore.value),
      rivalScore: Number(rivalScore.value)
    })

    setTimeout(() => {
      isModalOpen.value = false
    }, 1500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al registrar marcador'
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
          <!-- Game Header -->
          <div class="flex items-center justify-between border-b border-slate-100 pb-2.5">
            <div class="flex items-center gap-2">
              <span class="px-2.5 py-1 rounded-lg text-xs font-black bg-emerald-950 text-emerald-400 font-mono">
                VS {{ item.game.opponent_name.toUpperCase() }}
              </span>
              <span class="text-xs text-slate-500 font-mono">
                {{ formatCaracas(item.game.game_date) }}
              </span>
            </div>
            <PearlAmount :amount="item.exact_reward_pearls" size="sm" />
          </div>

          <!-- Title -->
          <div>
            <h3 class="font-display font-bold text-base text-guaiqui-text leading-snug">
              {{ item.title }}
            </h3>
            <p v-if="item.description" class="text-xs text-guaiqui-text-muted mt-1">
              {{ item.description }}
            </p>
          </div>

          <!-- Reward tiers badge -->
          <div class="p-2.5 bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between text-xs">
            <div class="flex items-center gap-1.5 text-slate-700">
              <i class="bi bi-trophy-fill text-amber-500"></i>
              <span>Marcador Exacto: <strong class="text-emerald-700 font-bold">+{{ item.exact_reward_pearls }}</strong></span>
            </div>
            <div class="text-slate-500 text-[11px]">
              Cercano (≤4 pts): <strong class="text-slate-700">+{{ item.closest_reward_pearls }}</strong>
            </div>
          </div>
        </div>

        <!-- Footer / Action State -->
        <div class="pt-4 mt-3 border-t border-slate-100 flex items-center justify-between">
          <span class="text-[11px] text-slate-400 font-mono">
            Cierra: {{ formatCaracas(item.closes_at) }}
          </span>

          <!-- Resolved State -->
          <div v-if="item.status === 'resolved'" class="text-right">
            <div v-if="item.user_vote?.is_exact_match" class="text-xs font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 inline-flex items-center gap-1">
              <i class="bi bi-trophy-fill text-amber-500"></i> ¡Marcador Exacto! +{{ item.user_vote.pearls_awarded }}
            </div>
            <div v-else-if="item.user_vote?.is_closest_match" class="text-xs font-bold text-amber-800 bg-amber-50 px-2.5 py-1 rounded-full border border-amber-300 inline-flex items-center gap-1">
              <i class="bi bi-check-circle-fill text-amber-600"></i> ¡Marcador Cercano! +{{ item.user_vote.pearls_awarded }}
            </div>
            <div v-else-if="item.user_vote" class="text-xs text-slate-600 bg-slate-100 px-2.5 py-1 rounded-full border border-slate-300 inline-block">
              Predijiste {{ item.user_vote.predicted_guaiqueries_score }} - {{ item.user_vote.predicted_rival_score }}
            </div>
            <div v-else class="text-xs text-slate-500 italic">
              Final: {{ item.final_guaiqueries_score }} - {{ item.final_rival_score }}
            </div>
          </div>

          <!-- Pending Vote -->
          <div v-else-if="item.user_vote" class="text-xs font-bold text-slate-700 bg-slate-100 px-3 py-1.5 rounded-xl border border-slate-200 inline-flex items-center gap-1.5">
            <i class="bi bi-hourglass-split text-emerald-600"></i>
            Pronóstico: <strong class="text-emerald-700 font-mono">{{ item.user_vote.predicted_guaiqueries_score }} - {{ item.user_vote.predicted_rival_score }}</strong>
          </div>

          <!-- Open to Vote -->
          <BaseButton
            v-else
            variant="primary"
            size="sm"
            @click="openPredictModal(item)"
          >
            <i class="bi bi-pencil-fill me-1"></i> Predecir Marcador
          </BaseButton>
        </div>
      </BaseCard>
    </div>

    <!-- Empty State -->
    <div v-else class="p-8 text-center bg-white rounded-2xl border border-guaiqui-border space-y-2">
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-xl">
        <i class="bi bi-bullseye"></i>
      </div>
      <h3 class="font-display font-bold text-slate-700 text-base">No hay predicciones de marcador activas</h3>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Pronto abriremos el bote de marcador exacto para el próximo partido de La Tribu.
      </p>
    </div>

    <!-- Predict Modal -->
    <BaseModal v-model="isModalOpen" title="Adivina el Marcador Final">
      <div v-if="selectedPrediction" class="space-y-4 text-left">
        <div class="p-3 bg-slate-50 border border-slate-200 rounded-xl space-y-1">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Partido Oficial</div>
          <div class="font-bold text-slate-900 text-sm">Guaiqueríes de Margarita vs {{ selectedPrediction.game.opponent_name }}</div>
          <div class="text-xs text-slate-600 font-mono">{{ formatCaracas(selectedPrediction.game.game_date) }}</div>
        </div>

        <p class="text-xs text-slate-600">
          Ingresa la cantidad exacta de puntos que anotará cada equipo al sonar la chicharra final.
        </p>

        <div class="grid grid-cols-2 gap-3 p-4 bg-emerald-950/10 border border-emerald-200 rounded-2xl">
          <div class="space-y-1">
            <label class="text-xs font-bold text-emerald-950 block">Guaiqueríes</label>
            <input
              v-model="guaiquiScore"
              type="number"
              min="0"
              max="200"
              placeholder="85"
              class="w-full text-center text-2xl font-black font-mono py-2 rounded-xl border border-emerald-300 focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white text-emerald-950"
            />
          </div>

          <div class="space-y-1">
            <label class="text-xs font-bold text-slate-700 block truncate">{{ selectedPrediction.game.opponent_name }}</label>
            <input
              v-model="rivalScore"
              type="number"
              min="0"
              max="200"
              placeholder="78"
              class="w-full text-center text-2xl font-black font-mono py-2 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white text-slate-900"
            />
          </div>
        </div>

        <div v-if="errorMessage" class="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ errorMessage }}</span>
        </div>

        <div v-if="successMessage" class="p-3 rounded-lg bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold flex items-center gap-2">
          <i class="bi bi-check-circle-fill text-emerald-600"></i>
          <span>{{ successMessage }}</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="isModalOpen = false" :disabled="isSubmitting">
            Cancelar
          </BaseButton>
          <BaseButton
            variant="primary"
            size="sm"
            :disabled="guaiquiScore === '' || rivalScore === '' || isSubmitting"
            :loading="isSubmitting"
            @click="submitPrediction"
          >
            Confirmar y Enviar Marcador
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
