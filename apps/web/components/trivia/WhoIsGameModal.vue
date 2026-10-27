<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { BaseModal, BaseButton, PearlAmount } from '@guaiqui/ui'
import type { ActiveWhoIsChallenge } from '@guaiqui/shared'

interface Player {
  id: string
  name: string
  jersey_number: number
  photo_url?: string | null
  position?: string | null
}

const props = defineProps<{
  isOpen: boolean
  challenge: ActiveWhoIsChallenge | null
  players: Player[]
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'voted', payload: { challengeId: string; result: any }): void
}>()

const supabase = useSupabaseClient()

const selectedPlayerId = ref<string>('')
const isCountingDown = ref<boolean>(false)
const countdown = ref<number>(5)
let countdownTimer: any = null
const isSubmitting = ref<boolean>(false)
const errorMessage = ref<string | null>(null)
const voteResult = ref<{
  is_correct: boolean
  pearls_awarded: number
  correct_player: { id: string; name: string; jersey_number: number; photo_url?: string | null; position?: string | null }
} | null>(null)
const isRevealed = ref<boolean>(false)

// Reset or populate state when modal opens
watch(() => [props.isOpen, props.challenge], () => {
  if (props.isOpen && props.challenge) {
    errorMessage.value = null
    isCountingDown.value = false
    countdown.value = 5
    if (countdownTimer) clearInterval(countdownTimer)

    // Si el usuario ya había votado previamente
    if (props.challenge.has_voted) {
      isRevealed.value = true
      selectedPlayerId.value = props.challenge.selected_player_id || ''
      voteResult.value = {
        is_correct: Boolean(props.challenge.is_correct),
        pearls_awarded: props.challenge.pearls_awarded || 0,
        correct_player: {
          id: props.challenge.player_id || '',
          name: props.challenge.player_name || 'Jugador de la Tribu',
          jersey_number: props.challenge.player_jersey_number ?? 0,
          photo_url: props.challenge.player_photo_url
        }
      }
    } else {
      isRevealed.value = false
      selectedPlayerId.value = ''
      voteResult.value = null
    }
  }
}, { immediate: true })

onBeforeUnmount(() => {
  if (countdownTimer) clearInterval(countdownTimer)
})

const currentMysteryImage = computed(() => {
  if (isRevealed.value && voteResult.value?.correct_player?.photo_url) {
    return voteResult.value.correct_player.photo_url
  }
  if (props.challenge?.custom_image_url) {
    return props.challenge.custom_image_url
  }
  if (props.challenge?.player_photo_url) {
    return props.challenge.player_photo_url
  }
  return '/logo.png'
})

const effectiveDorsal = computed(() => {
  if (isRevealed.value && voteResult.value?.correct_player?.jersey_number !== undefined) {
    return voteResult.value.correct_player.jersey_number
  }
  return props.challenge?.dorsal_number ?? 0
})

const selectedPlayerObj = computed(() => {
  return props.players.find(p => p.id === selectedPlayerId.value) || null
})

// Inicia el conteo regresivo de 5 segundos y envía el voto al finalizar
const startVoteCountdown = () => {
  if (!selectedPlayerId.value || !props.challenge) return
  if (props.challenge.has_voted) return

  errorMessage.value = null
  isCountingDown.value = true
  countdown.value = 5

  countdownTimer = setInterval(async () => {
    countdown.value--
    if (countdown.value <= 0) {
      clearInterval(countdownTimer)
      countdownTimer = null
      await executeVoteSubmission()
    }
  }, 1000)
}

const executeVoteSubmission = async () => {
  if (!props.challenge || !selectedPlayerId.value) return
  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await (supabase.rpc as any)('submit_guess_player_vote', {
      p_challenge_id: props.challenge.id,
      p_selected_player_id: selectedPlayerId.value
    })

    if (error) throw error

    voteResult.value = data as any
    isRevealed.value = true
    isCountingDown.value = false

    emit('voted', {
      challengeId: props.challenge.id,
      result: data
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al enviar tu respuesta.'
    isCountingDown.value = false
  } finally {
    isSubmitting.value = false
  }
}

const handleClose = () => {
  if (isCountingDown.value && !isRevealed.value) {
    // Si cancela durante el conteo, se detiene el timer sin enviar
    if (countdownTimer) clearInterval(countdownTimer)
    isCountingDown.value = false
    countdown.value = 5
  }
  emit('close')
}
</script>

<template>
  <BaseModal
    v-if="isOpen"
    :is-open="isOpen"
    title="Reto: «¿Quién es este jugador?»"
    @close="handleClose"
    size="xl"
  >
    <div class="space-y-6">
      <!-- Fondo Verde Gradiente Oscuro (Requisito Crítico) -->
      <div
        class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-emerald-950 via-slate-950 to-emerald-900 border-2 border-emerald-500/40 p-6 sm:p-8 text-white shadow-2xl text-center"
      >
        <!-- Glow ambiental decorativo -->
        <div class="absolute -top-16 left-1/2 -translate-x-1/2 w-80 h-40 bg-emerald-500/20 blur-3xl pointer-events-none"></div>

        <!-- Encabezado del Reto -->
        <div class="relative z-10 flex flex-wrap items-center justify-between gap-3 pb-4 mb-4 border-b border-emerald-500/20">
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
            <span class="text-xs font-mono font-bold uppercase tracking-widest text-emerald-300">
              {{ challenge?.challenge_type === 'silhouette' ? 'Adivina por Silueta' : 'Adivina por Dorsal' }}
            </span>
          </div>
          <span class="text-xs font-mono font-bold text-amber-300 bg-emerald-900/60 px-3 py-1 rounded-full border border-emerald-500/40 flex items-center gap-1.5 shadow-sm">
            <i class="bi bi-gem"></i> +{{ challenge?.reward_pearls }} perlitas
          </span>
        </div>

        <h3 class="relative z-10 font-display font-black text-2xl sm:text-3xl uppercase tracking-tight text-white mb-2">
          {{ challenge?.title || '¿Quién es este jugador de la Tribu?' }}
        </h3>

        <p v-if="challenge?.clue" class="relative z-10 text-xs sm:text-sm text-emerald-200/90 italic mb-6 max-w-lg mx-auto">
          <i class="bi bi-lightbulb-fill text-amber-300 mr-1"></i>
          Pista: "{{ challenge?.clue }}"
        </p>

        <!-- Cuadro Central del Misterio -->
        <div class="relative z-10 my-4">
          <!-- Silueta o Dorsal dentro del cuadro -->
          <div class="relative w-48 h-48 sm:w-56 sm:h-56 mx-auto rounded-3xl bg-slate-950/80 border-2 border-emerald-400/40 p-3 shadow-2xl flex items-center justify-center overflow-hidden">
            <!-- Overlay Conteo Regresivo de 5 segundos -->
            <div
              v-if="isCountingDown"
              class="absolute inset-0 z-30 bg-slate-950/90 backdrop-blur-sm flex flex-col items-center justify-center animate-fade-in"
            >
              <span class="text-xs font-mono uppercase tracking-widest text-emerald-400 font-bold mb-1">
                Revelando en
              </span>
              <span class="font-display font-black text-6xl sm:text-7xl text-amber-400 animate-ping">
                {{ countdown }}
              </span>
              <span class="text-[11px] text-slate-300 mt-2">
                ¿Acertarás?
              </span>
            </div>

            <!-- MODO DORSAL -->
            <template v-if="challenge?.challenge_type === 'dorsal'">
              <div
                class="flex flex-col items-center justify-center text-center transition-all duration-500"
                :class="isRevealed ? 'scale-105' : ''"
              >
                <div class="w-16 h-16 rounded-full bg-emerald-500/20 border-2 border-emerald-400/50 flex items-center justify-center text-emerald-400 mb-2 shadow-lg">
                  <i class="bi bi-shield-shaded text-3xl"></i>
                </div>
                <span class="font-display font-black text-5xl sm:text-6xl text-emerald-400 tracking-wider drop-shadow-md">
                  #{{ effectiveDorsal }}
                </span>
                <span class="text-xs text-emerald-200 font-bold uppercase tracking-widest mt-1">
                  Guaiqueríes
                </span>
              </div>
            </template>

            <!-- MODO SILUETA / IMAGEN -->
            <template v-else>
              <img
                :src="currentMysteryImage"
                :alt="challenge?.title"
                class="w-full h-full object-contain transition-all duration-700"
                :class="isRevealed
                  ? 'filter-none scale-105 drop-shadow-2xl'
                  : 'filter brightness-0 contrast-200 drop-shadow-[0_0_15px_rgba(16,185,129,0.5)]'"
                @error="($event.target as HTMLImageElement).src = '/logo.png'"
              />
            </template>

            <!-- Badge de Revelación -->
            <div
              v-if="isRevealed"
              class="absolute bottom-2 inset-x-2 py-1 px-2 rounded-xl text-[10px] font-black uppercase tracking-wider backdrop-blur-md shadow-lg"
              :class="voteResult?.is_correct ? 'bg-emerald-500 text-slate-950' : 'bg-rose-600 text-white'"
            >
              {{ voteResult?.is_correct ? '¡Acertaste!' : '¡Solución Revelada!' }}
            </div>
          </div>
        </div>

        <!-- Banner de Resultado Descubierto -->
        <div v-if="isRevealed && voteResult" class="relative z-10 mt-6 pt-4 border-t border-emerald-500/20 animate-fade-in">
          <div
            class="p-4 rounded-2xl border max-w-lg mx-auto"
            :class="voteResult.is_correct
              ? 'bg-emerald-900/60 border-emerald-400/50 text-emerald-100'
              : 'bg-rose-950/60 border-rose-800/50 text-rose-100'"
          >
            <div class="flex items-center justify-center gap-2 mb-2 font-display font-black text-xl uppercase tracking-wide">
              <i :class="['bi', voteResult.is_correct ? 'bi-check-circle-fill text-emerald-400' : 'bi-x-circle-fill text-rose-400']"></i>
              <span>{{ voteResult.is_correct ? '¡Felicidades, Acertaste!' : '¡Buen intento!' }}</span>
            </div>
            <p class="text-sm">
              El jugador misterioso es <strong class="text-white">{{ voteResult.correct_player.name }}</strong> (Dorsal #{{ voteResult.correct_player.jersey_number }}).
            </p>
            <div v-if="voteResult.is_correct && voteResult.pearls_awarded > 0" class="mt-2 text-xs font-mono font-bold text-amber-300 flex items-center justify-center gap-1.5">
              <i class="bi bi-gem"></i> ¡Sumaste +{{ voteResult.pearls_awarded }} perlitas a tu billetera!
            </div>
          </div>
        </div>
      </div>

      <!-- Alerta de Error -->
      <div v-if="errorMessage" class="p-3 rounded-xl bg-red-950/60 border border-red-800 text-red-200 text-xs flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- Selector de Votación (Solo si aún no ha votado y no está en cuenta regresiva) -->
      <div v-if="!isRevealed" class="space-y-4">
        <div class="border-b border-guaiqui-border pb-2">
          <h4 class="font-display font-bold text-base text-guaiqui-text uppercase tracking-wide">
            ¿Quién crees que es? Elige a tu candidato:
          </h4>
          <p class="text-xs text-guaiqui-text-muted">
            Vota por un jugador oficial de la plantilla de Guaiqueríes. Al confirmar comenzará el conteo de 5 segundos.
          </p>
        </div>

        <!-- Grid de Jugadores -->
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2.5 max-h-72 overflow-y-auto p-1 pr-2">
          <button
            v-for="p in players"
            :key="p.id"
            type="button"
            :disabled="isCountingDown"
            @click="selectedPlayerId = p.id"
            :class="[
              'p-2.5 rounded-2xl border text-left transition-all duration-200 flex items-center gap-2.5 relative group',
              selectedPlayerId === p.id
                ? 'bg-emerald-900 text-white border-emerald-500 shadow-lg ring-2 ring-emerald-400'
                : 'bg-white hover:bg-slate-50 text-guaiqui-text border-guaiqui-border'
            ]"
          >
            <!-- Avatar del Jugador -->
            <div class="w-10 h-10 rounded-xl bg-slate-100 border border-slate-300 p-0.5 flex items-center justify-center shrink-0 overflow-hidden">
              <img
                v-if="p.photo_url"
                :src="p.photo_url"
                :alt="p.name"
                class="w-full h-full object-contain"
                loading="lazy"
              />
              <i v-else class="bi bi-person-fill text-slate-500 text-lg"></i>
            </div>

            <!-- Info Jugador -->
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-1">
                <span class="font-display font-extrabold text-xs" :class="selectedPlayerId === p.id ? 'text-amber-300' : 'text-guaiqui-primary'">
                  #{{ p.jersey_number }}
                </span>
                <span class="text-[11px] font-bold truncate leading-tight block">
                  {{ p.name }}
                </span>
              </div>
              <span class="text-[10px] text-slate-400 truncate block">
                {{ p.position || 'Jugador' }}
              </span>
            </div>

            <!-- Checkmark selection -->
            <i
              v-if="selectedPlayerId === p.id"
              class="bi bi-check-circle-fill text-amber-300 text-sm absolute top-1.5 right-1.5"
            ></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Footer Modal -->
    <template #footer>
      <div class="flex items-center justify-between w-full">
        <span class="text-xs text-slate-400 hidden sm:inline">
          <template v-if="!isRevealed">
            {{ selectedPlayerObj ? `Seleccionado: #${selectedPlayerObj.jersey_number} ${selectedPlayerObj.name}` : 'Selecciona un jugador' }}
          </template>
          <template v-else>
            Participación registrada exitosamente.
          </template>
        </span>

        <div class="flex items-center gap-3 ml-auto">
          <BaseButton variant="secondary" @click="handleClose">
            {{ isRevealed ? 'Cerrar' : 'Cancelar / Salir' }}
          </BaseButton>

          <BaseButton
            v-if="!isRevealed"
            variant="primary"
            :disabled="!selectedPlayerId || isCountingDown"
            :loading="isSubmitting"
            @click="startVoteCountdown"
          >
            <i class="bi bi-send-check mr-1.5"></i>
            {{ isCountingDown ? `Contando (${countdown}s)...` : 'Confirmar y Votar' }}
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>
