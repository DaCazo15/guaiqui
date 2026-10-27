<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseModal, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveOverUnder } from '@guaiqui/shared'

const props = defineProps<{
  items: ActiveOverUnder[]
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'voted', payload: { predictionId: string; choice: 'over' | 'under' }): void
}>()

const supabase = useSupabaseClient()
const selectedPrediction = ref<ActiveOverUnder | null>(null)
const selectedChoice = ref<'over' | 'under' | null>(null)
const isModalOpen = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const openVoteModal = (item: ActiveOverUnder) => {
  if (item.user_vote) return
  selectedPrediction.value = item
  selectedChoice.value = null
  errorMessage.value = null
  successMessage.value = null
  isModalOpen.value = true
}

const submitVote = async () => {
  if (!selectedPrediction.value || !selectedChoice.value) return
  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await (supabase.rpc as any)('submit_over_under_vote', {
      p_prediction_id: selectedPrediction.value.id,
      p_choice: selectedChoice.value
    })

    if (error) throw error

    successMessage.value = (data as any)?.message || '¡Pronóstico registrado exitosamente!'
    emit('voted', {
      predictionId: selectedPrediction.value.id,
      choice: selectedChoice.value
    })

    setTimeout(() => {
      isModalOpen.value = false
    }, 1500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al registrar pronóstico'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard v-for="i in 2" :key="i" class="p-6 bg-white border border-guaiqui-border animate-pulse h-40" />
    </div>

    <div v-else-if="items.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <BaseCard
        v-for="item in items"
        :key="item.id"
        class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between transition hover:border-guaiqui-primary"
      >
        <div class="space-y-3">
          <!-- Header: Line & Reward -->
          <div class="flex items-center justify-between gap-2 border-b border-slate-100 pb-2.5">
            <div class="flex items-center gap-2">
              <span class="px-2.5 py-1 rounded-lg text-xs font-black bg-slate-900 text-emerald-400 font-mono">
                LÍNEA {{ item.line_value }}
              </span>
              <span class="text-xs font-bold text-slate-500 uppercase tracking-wider">
                {{ item.stat_type }}
              </span>
            </div>
            <PearlAmount :amount="item.reward_pearls" size="sm" />
          </div>

          <!-- Title & Context -->
          <div>
            <h3 class="font-display font-bold text-base text-guaiqui-text leading-snug">
              {{ item.title }}
            </h3>
            <p v-if="item.description" class="text-xs text-guaiqui-text-muted mt-1">
              {{ item.description }}
            </p>
          </div>

          <!-- Player or Game info if available -->
          <div v-if="item.player" class="flex items-center gap-2 text-xs bg-emerald-50 text-emerald-950 p-2 rounded-lg border border-emerald-100">
            <div class="w-6 h-6 rounded-full bg-emerald-700 text-white font-black flex items-center justify-center text-[10px] shrink-0">
              #{{ item.player.jersey_number }}
            </div>
            <span class="font-bold">{{ item.player.name }}</span>
            <span v-if="item.player.position" class="text-emerald-700 text-[11px]">({{ item.player.position }})</span>
          </div>

          <!-- Community vote split -->
          <div class="space-y-1 pt-1">
            <div class="flex items-center justify-between text-[11px] text-slate-500 font-bold">
              <span class="text-emerald-700">▲ Más de {{ item.line_value }} ({{ item.over_count }})</span>
              <span class="text-amber-800">▼ Menos de {{ item.line_value }} ({{ item.under_count }})</span>
            </div>
            <div class="w-full h-2 rounded-full bg-slate-200 overflow-hidden flex">
              <div
                class="bg-emerald-600 transition-all duration-300"
                :style="{ width: `${item.over_count + item.under_count > 0 ? (item.over_count / (item.over_count + item.under_count)) * 100 : 50}%` }"
              ></div>
              <div
                class="bg-amber-500 transition-all duration-300"
                :style="{ width: `${item.over_count + item.under_count > 0 ? (item.under_count / (item.over_count + item.under_count)) * 100 : 50}%` }"
              ></div>
            </div>
          </div>
        </div>

        <!-- Footer / Action State -->
        <div class="pt-4 mt-3 border-t border-slate-100 flex items-center justify-between">
          <span class="text-[11px] text-slate-400 font-mono">
            Cierra: {{ formatCaracas(item.closes_at) }}
          </span>

          <!-- Resolution state -->
          <div v-if="item.status === 'resolved'" class="text-right">
            <div v-if="item.user_vote?.is_winner" class="text-xs font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 inline-flex items-center gap-1">
              <i class="bi bi-check-circle-fill"></i> ¡Acertaste! +{{ item.user_vote.pearls_awarded }}
            </div>
            <div v-else-if="item.user_vote" class="text-xs font-semibold text-slate-600 bg-slate-100 px-2.5 py-1 rounded-full border border-slate-300 inline-block">
              No acertaste (Ganó {{ item.winning_choice?.toUpperCase() }})
            </div>
            <div v-else class="text-xs text-slate-500 italic">
              Finalizado ({{ item.winning_choice?.toUpperCase() }})
            </div>
          </div>

          <!-- Pending vote state -->
          <div v-else-if="item.user_vote" class="text-xs font-bold text-slate-700 bg-slate-100 px-3 py-1.5 rounded-xl border border-slate-200 inline-flex items-center gap-1.5">
            <i class="bi bi-hourglass-split text-emerald-600"></i>
            Pronóstico: <strong class="text-emerald-700 uppercase">{{ item.user_vote.choice === 'over' ? 'MÁS' : 'MENOS' }}</strong>
          </div>

          <!-- Open to vote -->
          <BaseButton
            v-else
            variant="primary"
            size="sm"
            @click="openVoteModal(item)"
          >
            <i class="bi bi-check-lg me-1"></i>
            Predecir Línea
          </BaseButton>
        </div>
      </BaseCard>
    </div>

    <!-- Empty State -->
    <div v-else class="p-8 text-center bg-white rounded-2xl border border-guaiqui-border space-y-2">
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-xl">
        <i class="bi bi-arrow-down-up"></i>
      </div>
      <h3 class="font-display font-bold text-slate-700 text-base">No hay líneas activas en este momento</h3>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Pronto se publicarán los pronósticos Over/Under para el próximo juego de Guaiqueríes.
      </p>
    </div>

    <!-- Vote Modal -->
    <BaseModal v-model="isModalOpen" title="Pronosticar Mayor o Menor">
      <div v-if="selectedPrediction" class="space-y-4 text-left">
        <div class="p-3 bg-slate-50 border border-slate-200 rounded-xl space-y-1">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Desafío</div>
          <div class="font-bold text-slate-900 text-sm">{{ selectedPrediction.title }}</div>
          <div class="text-xs text-slate-600">
            Línea estadística a superar: <strong class="text-emerald-700 font-black">{{ selectedPrediction.line_value }}</strong>
          </div>
        </div>

        <p class="text-xs text-slate-600">
          Selecciona si el resultado final será <strong class="text-slate-900">MÁS (Over)</strong> o <strong class="text-slate-900">MENOS (Under)</strong> del valor marcado. Solo tienes un intento oficial.
        </p>

        <!-- Choices selection buttons -->
        <div class="grid grid-cols-2 gap-3 pt-1">
          <button
            type="button"
            @click="selectedChoice = 'over'"
            :class="[
              'p-4 rounded-xl border text-center transition flex flex-col items-center justify-center gap-1.5',
              selectedChoice === 'over'
                ? 'bg-emerald-600 text-white border-emerald-700 shadow-md ring-2 ring-emerald-400/40'
                : 'bg-white text-slate-800 border-slate-200 hover:border-emerald-400 hover:bg-emerald-50/50'
            ]"
          >
            <i class="bi bi-arrow-up-circle-fill text-2xl" :class="selectedChoice === 'over' ? 'text-white' : 'text-emerald-600'"></i>
            <span class="font-display font-bold text-sm uppercase">MÁS DE {{ selectedPrediction.line_value }}</span>
            <span class="text-[11px]" :class="selectedChoice === 'over' ? 'text-emerald-100' : 'text-slate-500'">Over</span>
          </button>

          <button
            type="button"
            @click="selectedChoice = 'under'"
            :class="[
              'p-4 rounded-xl border text-center transition flex flex-col items-center justify-center gap-1.5',
              selectedChoice === 'under'
                ? 'bg-amber-600 text-white border-amber-700 shadow-md ring-2 ring-amber-400/40'
                : 'bg-white text-slate-800 border-slate-200 hover:border-amber-400 hover:bg-amber-50/50'
            ]"
          >
            <i class="bi bi-arrow-down-circle-fill text-2xl" :class="selectedChoice === 'under' ? 'text-white' : 'text-amber-600'"></i>
            <span class="font-display font-bold text-sm uppercase">MENOS DE {{ selectedPrediction.line_value }}</span>
            <span class="text-[11px]" :class="selectedChoice === 'under' ? 'text-amber-100' : 'text-slate-500'">Under</span>
          </button>
        </div>

        <!-- Alerts -->
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
            :disabled="!selectedChoice || isSubmitting"
            :loading="isSubmitting"
            @click="submitVote"
          >
            Confirmar y Enviar Pronóstico
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
