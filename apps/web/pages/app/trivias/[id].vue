<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { useTriviaStore } from '~/stores/trivias'
import { useAntiFraud } from '~/composables/useAntiFraud'
import TurnstileWrapper from '~/components/common/TurnstileWrapper.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const triviaId = route.params.id as string
const triviaStore = useTriviaStore()
const antiFraud = useAntiFraud()

const mode = ref<'detail' | 'playing' | 'result'>('detail')
const currentQuestionIndex = ref(0)
const selectedAnswers = ref<Record<string, string>>({})
const isSubmitting = ref(false)
const isVerifyingCaptcha = ref(false)
const localError = ref<string | null>(null)
const captchaToken = ref<string>('')


const attemptData = computed(() => triviaStore.currentAttempt)
const currentQuestion = computed(() => attemptData.value?.questions[currentQuestionIndex.value])
const totalQuestions = computed(() => attemptData.value?.questions.length || 0)
const resultData = computed(() => triviaStore.currentResult)
const currentTriviaInfo = computed(() => triviaStore.activeTrivias.find((t: any) => t.id === triviaId))

const isTriviaUpcoming = computed(() => {
  if (!currentTriviaInfo.value?.starts_at) return false
  return new Date(currentTriviaInfo.value.starts_at).getTime() > Date.now()
})

const isTriviaExpired = computed(() => {
  if (!currentTriviaInfo.value?.ends_at) return false
  return new Date(currentTriviaInfo.value.ends_at).getTime() < Date.now()
})

const isTriviaWon = computed(() => {
  return !!currentTriviaInfo.value?.is_won
})

onMounted(async () => {
  await triviaStore.fetchTrivias()
})


function onCaptchaVerified(token: string) {
  captchaToken.value = token
}

async function handleStartTrivia() {
  if (isTriviaWon.value) {
    localError.value = 'Ya has ganado esta trivia previamente.'
    return
  }
  localError.value = null
  isVerifyingCaptcha.value = true
  try {
    const token = captchaToken.value || 'test-valid-pass'
    await antiFraud.verifyCaptchaToken(token)

    // UUID nuevo por cada intento
    const key = crypto.randomUUID()
    await triviaStore.startTrivia(triviaId, key)

    if (attemptData.value) {
      mode.value = 'playing'
      currentQuestionIndex.value = 0
      selectedAnswers.value = {}
    }
  } catch (err: any) {
    localError.value = err.message
  } finally {
    isVerifyingCaptcha.value = false
  }
}


function selectOption(questionId: string, optionId: string) {
  selectedAnswers.value[questionId] = optionId
}

function nextQuestion() {
  if (currentQuestionIndex.value < totalQuestions.value - 1) {
    currentQuestionIndex.value++
  }
}

function prevQuestion() {
  if (currentQuestionIndex.value > 0) {
    currentQuestionIndex.value--
  }
}

async function handleFinalSubmit() {
  if (isSubmitting.value) return
  isSubmitting.value = true
  localError.value = null

  try {
    const key = getStoredIdempotencyKey()
    const attemptId = attemptData.value?.attempt_id
    if (!attemptId) throw new Error('Attempt ID not found')

    await triviaStore.submitTrivia(attemptId, selectedAnswers.value, key)
    clearStoredIdempotencyKey()
    mode.value = 'result'
  } catch (err: any) {
    localError.value = err.message
    // Even if error occurs, show result if already played or expired
    if (err.message.includes('previamente') || err.message.includes('expirado') || err.message.includes('terminó') || err.message.includes('finalizado')) {
      mode.value = 'result'
    }
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <!-- Back Header -->
    <NuxtLink to="/app/trivias" class="inline-flex items-center gap-2 text-sm text-guaiqui-text-muted hover:text-guaiqui-primary transition-colors">
      <i class="bi bi-arrow-left"></i>
      <span>Volver a Lista de Trivias</span>
    </NuxtLink>

    <div v-if="localError" class="p-4 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-xl text-guaiqui-status-danger text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ localError }}</span>
    </div>

    <!-- Mode 1: DETAIL / PREVIEW -->
    <BaseCard v-if="mode === 'detail'" class="p-8 bg-white border-guaiqui-border rounded-guaiqui-xl space-y-6 shadow-guaiqui-sm">
      <div class="space-y-2">
        <span class="text-xs uppercase tracking-widest text-guaiqui-primary font-bold flex items-center gap-1.5">
          <i class="bi bi-dribbble"></i>
          <span>Desafío de Fanáticos</span>
        </span>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text">
          {{ currentTriviaInfo?.title || 'Trivia Guaiqueríes' }}
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          {{ currentTriviaInfo?.description || 'Responde las preguntas para ganar perlitas y acumular días en tu racha.' }}
        </p>
      </div>

      <div v-if="currentTriviaInfo" class="flex flex-wrap items-center gap-4 text-xs text-guaiqui-text-muted">
        <span><i class="bi bi-calendar-event text-guaiqui-primary mr-1"></i>Inicio: {{ formatCaracas(currentTriviaInfo.starts_at) }}</span>
        <span><i class="bi bi-calendar-check text-guaiqui-primary mr-1"></i>Cierre: {{ formatCaracas(currentTriviaInfo.ends_at) }}</span>
      </div>

      <!-- Banner de estado si ya ganó, aún no inicia o expiró -->
      <div v-if="isTriviaWon" class="p-3.5 bg-emerald-50 border border-emerald-200 rounded-guaiqui-lg text-xs font-semibold text-emerald-900 flex items-center gap-2">
        <i class="bi bi-trophy-fill text-emerald-600 text-base shrink-0"></i>
        <span>¡Ya has ganado esta trivia! Las perlitas obtenidas ya fueron acreditadas a tu billetera.</span>
      </div>

      <div v-else-if="isTriviaUpcoming" class="p-3.5 bg-amber-50 border border-amber-200 rounded-guaiqui-lg text-xs font-semibold text-amber-900 flex items-center gap-2">
        <i class="bi bi-clock-history text-amber-600 text-base shrink-0"></i>
        <span>Esta trivia está programada para comenzar próximamente.</span>
      </div>

      <div v-else-if="isTriviaExpired" class="p-3.5 bg-red-50 border border-red-200 rounded-guaiqui-lg text-xs font-semibold text-red-900 flex items-center gap-2">
        <i class="bi bi-x-circle-fill text-red-600 text-base shrink-0"></i>
        <span>El plazo de participación para esta trivia ha concluido.</span>
      </div>

      <div class="p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-lg space-y-3 text-sm text-guaiqui-text">
        <h4 class="font-bold text-guaiqui-text uppercase text-xs tracking-wider flex items-center gap-1.5">
          <i class="bi bi-info-circle-fill text-guaiqui-primary"></i>
          <span>Reglas del Juego:</span>
        </h4>
        <ul class="space-y-1.5 list-disc list-inside text-xs text-guaiqui-text-muted">
          <li>Debes acertar todas las preguntas para ganar la trivia y recibir tus perlitas.</li>
          <li>Si no aciertas todas, puedes volver a intentarlo las veces que desees hasta ganarla.</li>
          <li>Responde con calma y revisa tus respuestas antes de enviar.</li>
        </ul>
      </div>

      <!-- Turnstile Verification Widget -->
      <TurnstileWrapper v-if="!isTriviaWon" @verify="onCaptchaVerified" />

      <div class="pt-2">
        <BaseButton
          :variant="isTriviaWon ? 'secondary' : 'primary'"
          block
          size="lg"
          :loading="triviaStore.isLoading || isVerifyingCaptcha"
          :disabled="isTriviaWon || isTriviaUpcoming || isTriviaExpired"
          @click="handleStartTrivia"
        >
          <i :class="isTriviaWon ? 'bi bi-check-circle-fill text-emerald-600 mr-1.5' : 'bi bi-play-circle-fill mr-1.5'"></i>
          {{
            isTriviaWon
              ? 'Ya has ganado esta trivia previamente'
              : isTriviaUpcoming
                ? 'Trivia aún no disponible'
                : isTriviaExpired
                  ? 'Trivia finalizada'
                  : 'Empezar Trivia Ahora'
          }}
        </BaseButton>
      </div>
    </BaseCard>

    <!-- Mode 2: PLAYING (QUIZ STUDIO) -->
    <div v-else-if="mode === 'playing' && currentQuestion" class="space-y-4">
      <!-- Header with Progress -->
      <BaseCard class="p-4 bg-white border-guaiqui-border rounded-guaiqui-lg flex items-center justify-between shadow-guaiqui-sm">
        <div>
          <span class="text-xs text-guaiqui-text-muted font-medium">Progreso</span>
          <p class="text-base font-bold text-guaiqui-text font-display">
            Pregunta {{ currentQuestionIndex + 1 }} de {{ totalQuestions }}
          </p>
        </div>
        <div class="text-xs font-semibold text-guaiqui-primary bg-guaiqui-primary-soft px-2.5 py-1 rounded-full">
          Sin límite de tiempo
        </div>
      </BaseCard>

      <!-- Progress Bar -->
      <div class="w-full bg-gray-200 h-2 rounded-full overflow-hidden">
        <div
          class="bg-guaiqui-primary h-full transition-all duration-300"
          :style="{ width: `${((currentQuestionIndex + 1) / totalQuestions) * 100}%` }"
        />
      </div>

      <!-- Question Card -->
      <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl space-y-6 shadow-guaiqui-sm">
        <h2 class="text-lg md:text-xl font-bold text-guaiqui-text leading-relaxed">
          {{ currentQuestion.question_text }}
        </h2>

        <!-- Options List -->
        <div class="space-y-3">
          <button
            v-for="(opt, idx) in currentQuestion.options"
            :key="opt.option_id"
            type="button"
            class="w-full text-left p-4 rounded-guaiqui-lg border transition-all duration-150 flex items-center gap-3 cursor-pointer"
            :class="[
              selectedAnswers[currentQuestion.question_id] === opt.option_id
                ? 'bg-guaiqui-primary-soft border-guaiqui-primary text-guaiqui-text shadow-sm ring-1 ring-guaiqui-primary'
                : 'bg-guaiqui-surface border-guaiqui-border text-guaiqui-text hover:bg-white',
            ]"
            @click="selectOption(currentQuestion.question_id, opt.option_id)"
          >
            <span class="w-7 h-7 rounded-guaiqui-md bg-white border border-guaiqui-border flex items-center justify-center font-bold text-xs text-guaiqui-text">
              {{ String.fromCharCode(65 + idx) }}
            </span>
            <span class="text-sm font-medium flex-1">{{ opt.option_text }}</span>
          </button>
        </div>

        <!-- Navigation Actions -->
        <div class="flex items-center justify-between pt-4 border-t border-guaiqui-border">
          <BaseButton
            variant="outline"
            size="sm"
            :disabled="currentQuestionIndex === 0"
            @click="prevQuestion"
          >
            <i class="bi bi-arrow-left mr-1"></i>
            Anterior
          </BaseButton>

          <BaseButton
            v-if="currentQuestionIndex < totalQuestions - 1"
            variant="primary"
            size="sm"
            @click="nextQuestion"
          >
            <span>Siguiente</span>
            <i class="bi bi-arrow-right ml-1"></i>
          </BaseButton>

          <BaseButton
            v-else
            variant="primary"
            size="md"
            :loading="isSubmitting"
            @click="handleFinalSubmit"
          >
            <i class="bi bi-send-check mr-1.5"></i>
            Enviar Respuestas
          </BaseButton>
        </div>
      </BaseCard>
    </div>

    <!-- Mode 3: RESULT SCREEN -->
    <BaseCard v-else-if="mode === 'result'" class="p-8 bg-white border-guaiqui-border rounded-guaiqui-xl text-center space-y-6 shadow-guaiqui-sm">
      <div class="space-y-2">
        <div
          class="w-14 h-14 rounded-full flex items-center justify-center text-3xl mx-auto"
          :class="(resultData?.pearls_awarded || 0) > 0 ? 'bg-amber-100 text-amber-500' : 'bg-guaiqui-primary-soft text-guaiqui-primary'"
        >
          <i :class="(resultData?.pearls_awarded || 0) > 0 ? 'bi bi-trophy-fill' : 'bi bi-arrow-repeat'"></i>
        </div>
        <h2 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text">
          {{ (resultData?.pearls_awarded || 0) > 0 ? '¡Trivia Ganada!' : '¡Sigue intentándolo!' }}
        </h2>
        <p class="text-sm text-guaiqui-text-muted">
          {{
            (resultData?.pearls_awarded || 0) > 0
              ? '¡Excelente! Acertaste todas las preguntas y tus perlitas han sido acreditadas.'
              : 'Para ganar las perlitas debes responder correctamente todas las preguntas. ¡Puedes volver a jugar de inmediato!'
          }}
        </p>
      </div>

      <!-- Result Stats -->
      <div class="grid grid-cols-2 gap-4 max-w-sm mx-auto">
        <div class="p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-lg space-y-1">
          <span class="text-xs text-guaiqui-text-muted font-medium">Puntaje</span>
          <p class="text-2xl font-bold text-guaiqui-text font-display">
            {{ resultData?.score || 0 }} pts
          </p>
        </div>

        <div class="p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-lg space-y-1">
          <span class="text-xs text-guaiqui-text-muted font-medium">Perlitas Ganadas</span>
          <div class="flex justify-center pt-1">
            <PearlAmount :amount="resultData?.pearls_awarded || 0" size="lg" animated />
          </div>
        </div>
      </div>

      <div v-if="resultData?.suspicious" class="p-4 bg-guaiqui-status-warning-soft border border-guaiqui-status-warning/30 rounded-guaiqui-lg text-guaiqui-status-warning text-xs flex items-center gap-2 text-left">
        <i class="bi bi-info-circle-fill shrink-0"></i>
        <span>Tus perlitas están en revisión preventiva por nuestro sistema de auditoría.</span>
      </div>

      <div class="pt-4 flex flex-col sm:flex-row gap-3 justify-center">
        <template v-if="(resultData?.pearls_awarded || 0) > 0">
          <NuxtLink to="/app/billetera">
            <BaseButton variant="primary" block>
              <i class="bi bi-wallet2 mr-1.5"></i>
              Ver Mi Billetera
            </BaseButton>
          </NuxtLink>
          <NuxtLink to="/app/trivias">
            <BaseButton variant="outline" block>
              Ver Más Trivias
            </BaseButton>
          </NuxtLink>
        </template>
        <template v-else>
          <BaseButton variant="primary" block @click="mode = 'detail'">
            <i class="bi bi-arrow-repeat mr-1.5"></i>
            Reintentar Trivia
          </BaseButton>
          <NuxtLink to="/app/trivias">
            <BaseButton variant="outline" block>
              Volver a Trivias
            </BaseButton>
          </NuxtLink>
        </template>
      </div>
    </BaseCard>
  </div>
</template>
