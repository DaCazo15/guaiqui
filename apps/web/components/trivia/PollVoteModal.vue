<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { BaseModal, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveTriviaPoll } from '@guaiqui/shared'

const props = defineProps<{
  isOpen: boolean
  poll: ActiveTriviaPoll | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'voted', payload: { pollId: string; optionId: string }): void
}>()

const supabase = useSupabaseClient()

const selectedOptionId = ref<string>('')
const isSubmitting = ref<boolean>(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Total votes computed from options
const totalVotes = computed(() => {
  if (!props.poll?.options) return 0
  return props.poll.options.reduce((acc, curr) => acc + (curr.votes_count || 0), 0)
})

// Whether fan has already participated
const hasVoted = computed(() => {
  return Boolean(props.poll?.user_vote?.vote_id) || Boolean(successMessage.value)
})

// Current user voted option id
const userVotedOptionId = computed(() => {
  return props.poll?.user_vote?.option_id || selectedOptionId.value
})

// Reset or init state
watch(() => [props.isOpen, props.poll], () => {
  if (props.isOpen && props.poll) {
    errorMessage.value = null
    successMessage.value = null
    selectedOptionId.value = props.poll.user_vote?.option_id || ''
  }
})

const getOptionPercentage = (votesCount: number) => {
  if (!totalVotes.value) return 0
  return Math.round((votesCount / totalVotes.value) * 100)
}

const submitVote = async () => {
  if (!props.poll || !selectedOptionId.value) return

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('submit_trivia_poll_vote', {
      p_poll_id: props.poll.id,
      p_option_id: selectedOptionId.value
    })

    if (error) throw error

    successMessage.value = data?.message || '¡Predicción registrada exitosamente!'
    emit('voted', { pollId: props.poll.id, optionId: selectedOptionId.value })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al registrar tu voto.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <BaseModal
    v-if="isOpen && poll"
    :is-open="isOpen"
    :title="poll.title"
    @close="emit('close')"
  >
    <div class="space-y-5">
      <!-- Game & Reward Banner -->
      <div class="bg-gradient-to-br from-slate-900 to-slate-950 p-4 rounded-xl border border-emerald-500/30 space-y-2.5">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <!-- Game tag -->
          <div v-if="poll.game" class="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-400 bg-emerald-950/80 px-2.5 py-1 rounded-full border border-emerald-500/30">
            <i class="bi bi-calendar-event"></i>
            <span>vs {{ poll.game.opponent }}</span>
            <span class="text-slate-400 font-mono text-[11px]">• {{ formatCaracas(poll.game.game_date) }}</span>
          </div>
          <div v-else class="text-xs text-slate-400 flex items-center gap-1.5">
            <i class="bi bi-trophy text-emerald-400"></i>
            <span>Predicción Oficial</span>
          </div>

          <!-- Reward -->
          <div class="inline-flex items-center gap-1.5 bg-emerald-500/10 text-emerald-300 px-3 py-1 rounded-full border border-emerald-500/20 text-xs font-bold font-mono">
            <span>Premio:</span>
            <PearlAmount :amount="poll.reward_pearls" size="sm" />
          </div>
        </div>

        <p v-if="poll.description" class="text-xs text-slate-300 leading-relaxed">
          {{ poll.description }}
        </p>

        <!-- Deadline Notice -->
        <div class="text-[11px] text-slate-400 flex items-center gap-1.5 pt-1 border-t border-slate-800">
          <i class="bi bi-clock-history text-amber-400"></i>
          <span>Cierre de votación: <strong class="text-slate-200">{{ formatCaracas(poll.closes_at) }}</strong></span>
        </div>
      </div>

      <!-- Single Participation & Incógnita Notice (Only before voting) -->
      <div v-if="!hasVoted && !poll.is_closed" class="p-3 bg-blue-950/40 border border-blue-800/60 rounded-xl text-blue-200 text-xs flex items-start gap-2.5">
        <i class="bi bi-info-circle-fill text-blue-400 text-sm shrink-0 mt-0.5"></i>
        <div class="space-y-1">
          <div class="font-bold text-white">¿Cómo funciona esta predicción?</div>
          <p class="text-blue-200/90 leading-relaxed">
            La respuesta correcta es una <strong>incógnita</strong> hasta que finalice el partido.
            Puedes participar <strong>una sola vez</strong> y solo se confirmará cuando presiones "Enviar Predicción".
            Si sales ahora sin enviar tu voto, la encuesta seguirá estando disponible.
          </p>
        </div>
      </div>

      <!-- Alert Error -->
      <div v-if="errorMessage" class="p-3 bg-red-950/60 border border-red-800/80 rounded-xl text-red-200 text-xs flex items-center gap-2">
        <i class="bi bi-exclamation-circle-fill text-red-400"></i>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Success Feedback (Immediate after voting) -->
      <div v-if="successMessage" class="p-3.5 bg-emerald-950/70 border border-emerald-600/80 rounded-xl text-emerald-200 text-xs flex items-center gap-2.5">
        <i class="bi bi-check-circle-fill text-emerald-400 text-base"></i>
        <div>
          <div class="font-bold text-white">{{ successMessage }}</div>
          <div class="text-emerald-300/80 text-[11px] mt-0.5">
            El resultado se comprobará y premiará al terminar el partido.
          </div>
        </div>
      </div>

      <!-- Post-Vote Status Banners -->
      <div v-if="hasVoted && !poll.is_resolved" class="p-3.5 bg-amber-950/40 border border-amber-800/60 rounded-xl text-amber-200 text-xs flex items-center gap-2.5">
        <i class="bi bi-hourglass-split text-amber-400 text-lg"></i>
        <div>
          <div class="font-bold text-white">Predicción registrada — Esperando resultado del partido</div>
          <p class="text-amber-200/80 text-[11px] mt-0.5">
            La respuesta ganadora se revelará automáticamente una vez que el personal o admin cargue los resultados oficiales.
          </p>
        </div>
      </div>

      <!-- Resolved Status Banners -->
      <div v-else-if="poll.is_resolved" class="space-y-3">
        <!-- Fan Won -->
        <div
          v-if="poll.user_vote?.is_winner"
          class="p-4 bg-emerald-950/80 border-2 border-emerald-500 rounded-xl text-emerald-200 text-xs flex items-center gap-3 shadow-lg shadow-emerald-950/50"
        >
          <div class="w-10 h-10 rounded-full bg-emerald-500/20 text-emerald-300 flex items-center justify-center text-xl shrink-0 border border-emerald-400">
            <i class="bi bi-trophy-fill text-amber-400"></i>
          </div>
          <div>
            <div class="font-bold text-base text-white">¡Felicitaciones! Acertaste tu predicción</div>
            <div class="text-emerald-300 flex items-center gap-1.5 mt-0.5 text-xs">
              <span>Has ganado:</span>
              <strong class="font-mono text-amber-300 text-sm">+{{ poll.user_vote.pearls_awarded }} Perlitas</strong>
              <span>(acreditadas a tu billetera)</span>
            </div>
          </div>
        </div>

        <!-- Fan Lost -->
        <div
          v-else-if="poll.user_vote && !poll.user_vote.is_winner"
          class="p-3.5 bg-slate-900 border border-slate-800 rounded-xl text-slate-300 text-xs flex items-center gap-2.5"
        >
          <i class="bi bi-x-circle text-slate-400 text-lg"></i>
          <div>
            <div class="font-semibold text-white">No acertaste esta predicción</div>
            <div class="text-slate-400 text-[11px] mt-0.5">
              ¡No te preocupes! Habrá nuevas encuestas y trivias en el próximo partido de Guaiqueríes.
            </div>
          </div>
        </div>
      </div>

      <!-- Options List -->
      <div class="space-y-2.5">
        <label
          v-for="opt in poll.options"
          :key="opt.id"
          class="block p-3.5 rounded-xl border transition-all duration-200 relative overflow-hidden"
          :class="[
            !hasVoted && !poll.is_closed
              ? 'cursor-pointer hover:border-emerald-500/70 ' + (selectedOptionId === opt.id ? 'bg-emerald-950/70 border-emerald-500 ring-1 ring-emerald-500/40 shadow-sm' : 'bg-slate-900/80 border-slate-800')
              : (userVotedOptionId === opt.id
                  ? (poll.is_resolved && opt.id === poll.correct_option_id
                      ? 'bg-emerald-950/90 border-emerald-500 ring-2 ring-emerald-400/50'
                      : (poll.is_resolved ? 'bg-red-950/40 border-red-800/80' : 'bg-emerald-950/60 border-emerald-500/80'))
                  : (poll.is_resolved && opt.id === poll.correct_option_id
                      ? 'bg-emerald-950/60 border-emerald-500'
                      : 'bg-slate-950/60 border-slate-800/80 opacity-75'))
          ]"
        >
          <!-- Background vote percentage bar when voted -->
          <div
            v-if="hasVoted && totalVotes > 0"
            class="absolute inset-y-0 left-0 bg-emerald-500/10 pointer-events-none transition-all duration-500"
            :style="{ width: `${getOptionPercentage(opt.votes_count || 0)}%` }"
          ></div>

          <div class="relative z-10 flex items-center justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <!-- Radio (when interactive) -->
              <input
                v-if="!hasVoted && !poll.is_closed"
                type="radio"
                :value="opt.id"
                v-model="selectedOptionId"
                class="accent-emerald-500 w-4 h-4 shrink-0"
              />

              <!-- Player Avatar / Jersey (if option links to player) -->
              <div v-if="opt.player" class="shrink-0">
                <img
                  v-if="opt.player.photo_url"
                  :src="opt.player.photo_url"
                  :alt="opt.player.name"
                  class="w-9 h-9 rounded-full object-cover border-2 border-emerald-500/60 bg-slate-950"
                />
                <div
                  v-else
                  class="w-9 h-9 rounded-full bg-slate-800 text-emerald-400 font-bold text-xs flex items-center justify-center border border-slate-700 font-mono"
                >
                  #{{ opt.player.jersey_number }}
                </div>
              </div>

              <!-- Option Label & Badges -->
              <div class="min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <span
                    class="text-sm font-semibold truncate"
                    :class="userVotedOptionId === opt.id ? 'text-white font-bold' : 'text-slate-200'"
                  >
                    {{ opt.label }}
                  </span>

                  <!-- Badge: User voted this -->
                  <span
                    v-if="userVotedOptionId === opt.id"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500 text-slate-950 tracking-wide uppercase"
                  >
                    Tu Elección
                  </span>

                  <!-- Badge: Correct Option in resolved -->
                  <span
                    v-if="poll.is_resolved && opt.id === poll.correct_option_id"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-400 text-slate-950 flex items-center gap-1 uppercase"
                  >
                    <i class="bi bi-trophy-fill text-[9px]"></i>
                    Ganadora
                  </span>
                </div>

                <div v-if="opt.player" class="text-[11px] text-slate-400">
                  {{ opt.player.position || 'Jugador' }} • #{{ opt.player.jersey_number }}
                </div>
              </div>
            </div>

            <!-- Stats (when voted) -->
            <div v-if="hasVoted" class="text-right shrink-0">
              <div class="text-xs font-mono font-bold text-white">
                {{ getOptionPercentage(opt.votes_count || 0) }}%
              </div>
              <div class="text-[10px] text-slate-400">
                {{ opt.votes_count || 0 }} votos
              </div>
            </div>
          </div>
        </label>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between gap-3 w-full">
        <span class="text-[11px] text-slate-400">
          {{ hasVoted ? 'Predicción enviada' : 'Selecciona una opción para votar' }}
        </span>

        <div class="flex items-center gap-2">
          <BaseButton
            variant="secondary"
            @click="emit('close')"
          >
            {{ hasVoted ? 'Cerrar' : 'Cancelar' }}
          </BaseButton>

          <BaseButton
            v-if="!hasVoted && !poll.is_closed"
            variant="primary"
            :loading="isSubmitting"
            :disabled="!selectedOptionId"
            @click="submitVote"
          >
            <i class="bi bi-send-fill mr-1.5"></i>
            Enviar Predicción
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>
