<script setup lang="ts">
import { ref, onUnmounted } from 'vue'
import { BaseCard, BaseButton, BaseModal, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import type { ActiveFlashTrivia } from '@guaiqui/shared'

const props = defineProps<{
  items: ActiveFlashTrivia[]
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'completed', payload: { challengeId: string; result: any }): void
}>()

const supabase = useSupabaseClient()
const selectedChallenge = ref<ActiveFlashTrivia | null>(null)
const isGameModalOpen = ref(false)
const isPlaying = ref(false)
const currentQuestionIndex = ref(0)
const answers = ref<{ question_id: string; selected_option: string }[]>([])
const timeLeft = ref(60)
let timerInterval: any = null
const isSubmitting = ref(false)
const resultData = ref<any | null>(null)
const errorMessage = ref<string | null>(null)

const openChallenge = (item: ActiveFlashTrivia) => {
  selectedChallenge.value = item
  isPlaying.value = false
  currentQuestionIndex.value = 0
  answers.value = []
  timeLeft.value = item.time_limit_seconds || 60
  resultData.value = item.user_attempt || null
  errorMessage.value = null
  isGameModalOpen.value = true
}

const handleCloseModal = () => {
  if (isPlaying.value && !resultData.value) {
    // Si se sale sin enviar su respuesta final, se cancela el timer y NO consume el intento
    clearInterval(timerInterval)
    isPlaying.value = false
    answers.value = []
  }
  isGameModalOpen.value = false
}

watch(isGameModalOpen, (isOpen) => {
  if (!isOpen) {
    clearInterval(timerInterval)
    isPlaying.value = false
  }
})

const startCountdown = () => {
  isPlaying.value = true
  currentQuestionIndex.value = 0
  answers.value = []
  timeLeft.value = selectedChallenge.value?.time_limit_seconds || 60

  clearInterval(timerInterval)
  timerInterval = setInterval(() => {
    if (timeLeft.value > 0) {
      timeLeft.value--
    } else {
      clearInterval(timerInterval)
      if (isGameModalOpen.value && isPlaying.value) {
        finishSession()
      }
    }
  }, 1000)
}

const selectAnswer = (optionKey: string) => {
  if (!selectedChallenge.value || !isPlaying.value) return
  const currentQ = selectedChallenge.value.questions[currentQuestionIndex.value]
  if (!currentQ) return

  answers.value.push({
    question_id: currentQ.id,
    selected_option: optionKey
  })

  if (currentQuestionIndex.value < selectedChallenge.value.questions.length - 1) {
    currentQuestionIndex.value++
  } else {
    finishSession()
  }
}

const finishSession = async () => {
  clearInterval(timerInterval)
  isPlaying.value = false
  if (!selectedChallenge.value || !isGameModalOpen.value) return

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const timeSpent = (selectedChallenge.value.time_limit_seconds || 60) - timeLeft.value
    const { data, error } = await supabase.rpc('submit_flash_trivia_session', {
      p_challenge_id: selectedChallenge.value.id,
      p_answers: answers.value,
      p_time_spent_seconds: timeSpent
    })

    if (error) throw error

    resultData.value = data
    emit('completed', {
      challengeId: selectedChallenge.value.id,
      result: data
    })
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al enviar sesión de juego'
  } finally {
    isSubmitting.value = false
  }
}

onUnmounted(() => {
  clearInterval(timerInterval)
})
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
          <div class="flex items-center justify-between border-b border-slate-100 pb-2.5">
            <div class="flex items-center gap-2">
              <span class="px-2.5 py-1 rounded-lg text-xs font-black bg-emerald-950 text-emerald-400 font-mono">
                {{ item.time_limit_seconds }}s CONTRARRELOJ
              </span>
              <span class="text-xs font-bold text-slate-500">
                {{ item.questions.length }} preguntas
              </span>
            </div>
            <span class="text-xs font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
              +{{ item.pearls_per_correct }} perlitas/acierto
            </span>
          </div>

          <div>
            <h3 class="font-display font-bold text-base text-guaiqui-text leading-snug">
              {{ item.title }}
            </h3>
            <p v-if="item.description" class="text-xs text-guaiqui-text-muted mt-1">
              {{ item.description }}
            </p>
          </div>
        </div>

        <div class="pt-4 mt-3 border-t border-slate-100 flex items-center justify-between">
          <span class="text-[11px] text-slate-400 font-mono">
            Cierra: {{ formatCaracas(item.closes_at) }}
          </span>

          <div v-if="item.user_attempt" class="text-xs">
            <span class="font-bold text-emerald-700 bg-emerald-100 px-2.5 py-1 rounded-full border border-emerald-300 inline-flex items-center gap-1">
              <i class="bi bi-check-circle-fill"></i>
              {{ item.user_attempt.correct_count }}/{{ item.user_attempt.total_answered }} aciertos (+{{ item.user_attempt.pearls_awarded }} perlitas)
            </span>
          </div>

          <BaseButton
            v-else
            variant="primary"
            size="sm"
            @click="openChallenge(item)"
          >
            <i class="bi bi-play-circle-fill me-1"></i> Iniciar Contrarreloj
          </BaseButton>
        </div>
      </BaseCard>
    </div>

    <!-- Empty State -->
    <div v-else class="p-8 text-center bg-white rounded-2xl border border-guaiqui-border space-y-2">
      <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-xl">
        <i class="bi bi-stopwatch"></i>
      </div>
      <h3 class="font-display font-bold text-slate-700 text-base">No hay desafíos contrarreloj activos</h3>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">
        Pronto tendremos una nueva ráfaga de 60 segundos con preguntas sobre la historia de La Tribu.
      </p>
    </div>

    <!-- Play Modal -->
    <BaseModal v-model="isGameModalOpen" :title="selectedChallenge?.title || 'Trivia Flash'" size="lg" @close="handleCloseModal">
      <div v-if="selectedChallenge" class="space-y-4 text-left">
        <!-- Ready Screen -->
        <div v-if="!isPlaying && !resultData" class="text-center py-6 space-y-4">
          <div class="w-16 h-16 mx-auto rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center text-3xl font-black">
            <i class="bi bi-lightning-charge-fill"></i>
          </div>
          <div class="space-y-1">
            <h3 class="font-display font-bold text-xl text-slate-900">¿Listo para el desafío de 60 segundos?</h3>
            <p class="text-xs text-slate-600 max-w-md mx-auto">
              Tienes {{ selectedChallenge.time_limit_seconds }} segundos para contestar la mayor cantidad de preguntas posible. Si sales antes de enviar, el reto no se consume y sigue disponible.
            </p>
          </div>
          <BaseButton variant="primary" size="lg" @click="startCountdown">
            <i class="bi bi-play-fill me-1"></i> ¡Empezar Ahora!
          </BaseButton>
        </div>

        <!-- In-Game Screen -->
        <div v-else-if="isPlaying" class="space-y-4">
          <!-- Timer and Question indicator -->
          <div class="flex items-center justify-between p-3 bg-slate-900 text-white rounded-xl">
            <div class="text-xs font-bold text-slate-400">
              Pregunta {{ currentQuestionIndex + 1 }} de {{ selectedChallenge.questions.length }}
            </div>
            <div class="flex items-center gap-1.5 font-mono text-lg font-black text-amber-400">
              <i class="bi bi-stopwatch"></i>
              <span>{{ timeLeft }}s</span>
            </div>
          </div>

          <!-- Current Question Card -->
          <div v-if="selectedChallenge.questions[currentQuestionIndex]" class="p-4 bg-emerald-50 border border-emerald-200 rounded-2xl space-y-3">
            <h4 class="font-display font-bold text-base text-emerald-950">
              {{ selectedChallenge.questions[currentQuestionIndex].question }}
            </h4>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-1">
              <button
                v-for="opt in [
                  { key: 'A', text: selectedChallenge.questions[currentQuestionIndex].option_a },
                  { key: 'B', text: selectedChallenge.questions[currentQuestionIndex].option_b },
                  { key: 'C', text: selectedChallenge.questions[currentQuestionIndex].option_c },
                  { key: 'D', text: selectedChallenge.questions[currentQuestionIndex].option_d },
                ].filter(o => Boolean(o.text))"
                :key="opt.key"
                type="button"
                @click="selectAnswer(opt.key)"
                class="p-3 bg-white border border-slate-200 hover:border-emerald-600 hover:bg-emerald-100/50 rounded-xl text-left transition flex items-center gap-3 text-xs font-semibold text-slate-800 shadow-sm"
              >
                <span class="w-6 h-6 rounded bg-emerald-600 text-white font-bold flex items-center justify-center text-xs shrink-0">
                  {{ opt.key }}
                </span>
                <span>{{ opt.text }}</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Results Screen -->
        <div v-else-if="resultData" class="text-center py-6 space-y-4">
          <div class="w-16 h-16 mx-auto rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center text-3xl font-black">
            <i class="bi bi-award-fill text-amber-500"></i>
          </div>
          <div class="space-y-1">
            <h3 class="font-display font-bold text-2xl text-slate-900">¡Sesión Contrarreloj Finalizada!</h3>
            <p class="text-sm font-bold text-emerald-700">
              Acertaste {{ resultData.correct_count }} de {{ resultData.total_answered }} preguntas.
            </p>
            <p v-if="resultData.pearls_awarded > 0" class="text-xs text-amber-800 font-bold">
              ¡Has ganado +{{ resultData.pearls_awarded }} perlitas para tu billetera!
            </p>
          </div>
        </div>

        <div v-if="errorMessage" class="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ errorMessage }}</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <BaseButton variant="outline" size="sm" @click="handleCloseModal">
            {{ isPlaying ? 'Salir (no consume intento)' : 'Cerrar' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
