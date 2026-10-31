<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { useTriviaStore, translateTriviaError } from '~/stores/trivias'
import { useAntiFraud } from '~/composables/useAntiFraud'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TurnstileWrapper from '~/components/common/TurnstileWrapper.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const triviaId = route.params.id as string
const teamSlugParam = computed(() => route.params.slug as string)

const triviaStore = useTriviaStore()
const antiFraud = useAntiFraud()
const { activeTeam, loadTeamBySlug } = useCurrentTeam()

const mode = ref<'detail' | 'playing' | 'result'>('detail')
const currentQuestionIndex = ref(0)
const selectedAnswers = ref<Record<string, string>>({})
const isSubmitting = ref(false)
const isVerifyingCaptcha = ref(false)
const localError = ref<string | null>(null)
const captchaToken = ref<string>('')
const attemptKey = ref<string>('')

const attemptData = computed(() => triviaStore.currentAttempt)
const currentQuestion = computed(() => attemptData.value?.questions[currentQuestionIndex.value])
const totalQuestions = computed(() => attemptData.value?.questions.length || 0)
const resultData = computed(() => triviaStore.currentResult)
const currentTriviaInfo = computed(() => {
  const fromList = triviaStore.activeTrivias.find((t: any) => t.id === triviaId)
  return fromList || null
})

const teamInfo = computed(() => {
  return currentTriviaInfo.value?.team || activeTeam.value || null
})

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
  await Promise.all([
    triviaStore.fetchTriviaById(triviaId),
    loadTeamBySlug(teamSlugParam.value),
  ])
  if (activeTeam.value?.id) {
    await triviaStore.fetchTrivias(activeTeam.value.id)
  }
})

function onCaptchaVerified(token: string) {
  captchaToken.value = token
}

async function handleStartTrivia() {
  localError.value = null

  if (isTriviaWon.value) {
    localError.value = 'Ya has ganado esta trivia anteriormente.'
    return
  }

  isVerifyingCaptcha.value = true
  try {
    if (captchaToken.value) {
      await antiFraud.verifyCaptchaToken(captchaToken.value)
    }

    const key = crypto.randomUUID()
    attemptKey.value = key
    await triviaStore.startTrivia(triviaId, key)

    if (attemptData.value) {
      mode.value = 'playing'
      currentQuestionIndex.value = 0
      selectedAnswers.value = {}
    } else {
      localError.value = translateTriviaError(triviaStore.errorMessage || '') || 'No se pudo iniciar la trivia. Intenta nuevamente.'
    }
  } catch (err: any) {
    localError.value = translateTriviaError(err.message || '')
  } finally {
    isVerifyingCaptcha.value = false
  }
}

function handleSelectOption(questionId: string, optionId: string) {
  selectedAnswers.value[questionId] = optionId
}

function handleNextQuestion() {
  if (currentQuestionIndex.value < totalQuestions.value - 1) {
    currentQuestionIndex.value++
  }
}

function handlePrevQuestion() {
  if (currentQuestionIndex.value > 0) {
    currentQuestionIndex.value--
  }
}

async function handleSubmitAttempt() {
  if (!attemptData.value || isSubmitting.value) return

  isSubmitting.value = true
  localError.value = null

  try {
    const attemptId = attemptData.value.attempt_id
    if (!attemptId || !attemptKey.value) {
      throw new Error('Intento no encontrado, vuelve a empezar la trivia.')
    }

    const questions = attemptData.value.questions || []
    for (const q of questions) {
      if (!selectedAnswers.value[q.question_id]) {
        throw new Error('Debes seleccionar una respuesta para todas las preguntas.')
      }
    }

    await triviaStore.submitTrivia(attemptId, selectedAnswers.value, attemptKey.value)
    attemptKey.value = ''
    mode.value = 'result'
    if (activeTeam.value?.slug) {
      await loadTeamBySlug(activeTeam.value.slug)
    }
  } catch (err: any) {
    localError.value = err.message
    if (['previamente', 'expirado', 'terminó', 'finalizado', 'agotó', 'cerró'].some((w) => err.message?.includes(w))) {
      mode.value = 'result'
    }
  } finally {
    isSubmitting.value = false
  }
}

const backUrl = computed(() => {
  const slug = teamInfo.value?.slug || teamSlugParam.value || 'guaiqueries'
  return `/app/e/${slug}/trivias`
})
</script>

<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <!-- Back Header -->
    <NuxtLink :to="backUrl" class="inline-flex items-center gap-2 text-sm text-slate-400 hover:text-emerald-400 transition-colors">
      <i class="bi bi-arrow-left"></i>
      <span>Volver a Trivias de {{ teamInfo?.short_name || teamInfo?.name || 'Equipo' }}</span>
    </NuxtLink>

    <div v-if="localError" class="p-4 bg-rose-950/40 border border-rose-800/60 rounded-2xl text-rose-300 text-sm flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0"></i>
      <span>{{ localError }}</span>
    </div>

    <!-- Mode 1: DETAIL / PREVIEW -->
    <BaseCard v-if="mode === 'detail'" class="p-6 sm:p-8 bg-slate-900 border border-slate-800 rounded-3xl space-y-6 shadow-xl">
      <div class="space-y-2">
        <div class="flex items-center gap-2">
          <div v-if="teamInfo?.logo_url" class="w-6 h-6 rounded-lg bg-slate-950 p-0.5 border border-slate-800 shrink-0">
            <img :src="teamInfo.logo_url" :alt="teamInfo.name" class="w-full h-full object-contain" />
          </div>
          <span class="text-xs uppercase tracking-widest text-emerald-400 font-bold">
            Trivia Oficial — {{ teamInfo?.name || 'Equipo' }}
          </span>
        </div>
        <h1 class="font-display text-2xl md:text-3xl font-black text-white uppercase tracking-wider">
          {{ currentTriviaInfo?.title || 'Cargando trivia...' }}
        </h1>
        <p class="text-sm text-slate-300 leading-relaxed">
          {{ currentTriviaInfo?.description || 'Responde correctamente para ganar perlitas y acumular racha en este equipo.' }}
        </p>
      </div>

      <div v-if="currentTriviaInfo" class="flex flex-wrap items-center gap-4 text-xs text-slate-400">
        <span><i class="bi bi-calendar-event text-emerald-400 mr-1"></i>Inicio: {{ formatCaracas(currentTriviaInfo.starts_at) }}</span>
        <span><i class="bi bi-calendar-check text-emerald-400 mr-1"></i>Cierre: {{ formatCaracas(currentTriviaInfo.ends_at) }}</span>
      </div>

      <!-- State banners -->
      <div v-if="isTriviaWon" class="p-3.5 bg-emerald-950/60 border border-emerald-600/50 rounded-2xl text-xs font-semibold text-emerald-200 flex items-center gap-2">
        <i class="bi bi-trophy-fill text-emerald-400 text-base shrink-0"></i>
        <span>¡Ya has ganado esta trivia! Las perlitas obtenidas ya fueron acreditadas a tu billetera de {{ teamInfo?.short_name || teamInfo?.name }}.</span>
      </div>

      <div v-else-if="isTriviaUpcoming" class="p-3.5 bg-amber-950/60 border border-amber-600/50 rounded-2xl text-xs font-semibold text-amber-200 flex items-center gap-2">
        <i class="bi bi-clock-history text-amber-400 text-base shrink-0"></i>
        <span>Esta trivia está programada para comenzar próximamente.</span>
      </div>

      <div v-else-if="isTriviaExpired" class="p-3.5 bg-rose-950/60 border border-rose-800/50 rounded-2xl text-xs font-semibold text-rose-200 flex items-center gap-2">
        <i class="bi bi-x-circle-fill text-rose-400 text-base shrink-0"></i>
        <span>El plazo de participación para esta trivia ha concluido.</span>
      </div>

      <div class="p-4 bg-slate-950/60 border border-slate-800 rounded-2xl space-y-2 text-xs text-slate-300">
        <h4 class="font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
          <i class="bi bi-info-circle-fill text-emerald-400"></i>
          <span>Reglas del Desafío:</span>
        </h4>
        <ul class="space-y-1 list-disc list-inside text-slate-400">
          <li>Acierta todas las preguntas para ganar la trivia y recibir tus perlitas.</li>
          <li>Las perlitas se sumarán directamente al saldo de este equipo.</li>
          <li>Puedes reintentar las veces que desees hasta ganarla.</li>
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

    <!-- Mode 2: PLAYING -->
    <BaseCard v-else-if="mode === 'playing'" class="p-6 sm:p-8 bg-slate-900 border border-slate-800 rounded-3xl space-y-6 shadow-xl">
      <div class="flex items-center justify-between border-b border-slate-800 pb-3">
        <span class="text-xs font-bold text-emerald-400 uppercase tracking-wider">
          Pregunta {{ currentQuestionIndex + 1 }} de {{ totalQuestions }}
        </span>
        <span class="text-xs font-bold text-slate-400">
          {{ teamInfo?.short_name || teamInfo?.name }}
        </span>
      </div>

      <div v-if="currentQuestion" class="space-y-4">
        <h2 class="text-lg sm:text-xl font-bold text-white leading-snug">
          {{ currentQuestion.question_text }}
        </h2>

        <div class="space-y-2.5 pt-2">
          <button
            v-for="opt in currentQuestion.options"
            :key="opt.option_id"
            type="button"
            @click="handleSelectOption(currentQuestion.question_id, opt.option_id)"
            class="w-full text-left p-4 rounded-2xl border transition-all duration-200 cursor-pointer flex items-center justify-between group"
            :class="[
              selectedAnswers[currentQuestion.question_id] === opt.option_id
                ? 'bg-emerald-950/80 border-emerald-500 text-white font-bold ring-2 ring-emerald-500/30'
                : 'bg-slate-950/60 border-slate-800 hover:border-slate-700 text-slate-300 hover:text-white'
            ]"
          >
            <span class="text-sm">{{ opt.option_text }}</span>
            <i
              class="bi"
              :class="[
                selectedAnswers[currentQuestion.question_id] === opt.option_id
                  ? 'bi-check-circle-fill text-emerald-400'
                  : 'bi-circle text-slate-600 group-hover:text-slate-400'
              ]"
            ></i>
          </button>
        </div>
      </div>

      <!-- Navigation & Submit Controls -->
      <div class="pt-4 border-t border-slate-800 flex items-center justify-between gap-3">
        <BaseButton
          variant="outline"
          size="sm"
          :disabled="currentQuestionIndex === 0"
          @click="handlePrevQuestion"
        >
          <i class="bi bi-chevron-left mr-1"></i>
          Anterior
        </BaseButton>

        <BaseButton
          v-if="currentQuestionIndex < totalQuestions - 1"
          variant="primary"
          size="sm"
          :disabled="!selectedAnswers[currentQuestion?.question_id || '']"
          @click="handleNextQuestion"
        >
          Siguiente
          <i class="bi bi-chevron-right ml-1"></i>
        </BaseButton>

        <BaseButton
          v-else
          variant="primary"
          size="sm"
          :loading="isSubmitting"
          :disabled="Object.keys(selectedAnswers).length < totalQuestions"
          @click="handleSubmitAttempt"
        >
          <i class="bi bi-send-fill mr-1.5"></i>
          Enviar Respuestas
        </BaseButton>
      </div>
    </BaseCard>

    <!-- Mode 3: RESULT -->
    <BaseCard v-else-if="mode === 'result'" class="p-6 sm:p-8 bg-slate-900 border border-slate-800 rounded-3xl text-center space-y-6 shadow-xl">
      <div
        class="w-20 h-20 mx-auto rounded-3xl flex items-center justify-center text-4xl shadow-xl"
        :class="[
          (resultData?.pearls_awarded || 0) > 0
            ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40'
            : 'bg-slate-800 text-slate-400 border border-slate-700'
        ]"
      >
        <i :class="(resultData?.pearls_awarded || 0) > 0 ? 'bi bi-trophy-fill' : 'bi bi-x-circle-fill'"></i>
      </div>

      <div class="space-y-1">
        <h2 class="font-display text-2xl font-black uppercase tracking-wider text-white">
          {{ (resultData?.pearls_awarded || 0) > 0 ? '¡Felicitaciones, Ganaste!' : 'Buen intento' }}
        </h2>
        <p class="text-xs text-slate-400">
          {{
            (resultData?.pearls_awarded || 0) > 0
              ? 'Has acertado las preguntas y sumado perlitas oficiales a tu billetera.'
              : 'No lograste acertar todas las preguntas, pero puedes volver a intentarlo.'
          }}
        </p>
      </div>

      <!-- Result Score & Pearls awarded with Team Logo -->
      <div class="grid grid-cols-2 gap-4 max-w-sm mx-auto">
        <div class="p-4 bg-slate-950 border border-slate-800 rounded-2xl space-y-1">
          <span class="text-xs text-slate-400 font-medium">Puntaje</span>
          <p class="text-2xl font-bold text-white font-display">
            {{ resultData?.score || 0 }} pts
          </p>
        </div>

        <div class="p-4 bg-slate-950 border border-slate-800 rounded-2xl space-y-1">
          <span class="text-xs text-slate-400 font-medium">Perlitas Ganadas</span>
          <div class="flex items-center justify-center gap-1.5 pt-1">
            <PearlAmount :amount="resultData?.pearls_awarded || 0" size="lg" animated />
          </div>
          <!-- Team Logo & Name for Pearls awarded -->
          <div v-if="teamInfo" class="flex items-center justify-center gap-1.5 pt-1">
            <img
              v-if="teamInfo.logo_url"
              :src="teamInfo.logo_url"
              :alt="teamInfo.name"
              class="w-4 h-4 object-contain"
            />
            <span class="text-[10px] font-bold text-emerald-400 truncate max-w-[120px]">
              {{ teamInfo.short_name || teamInfo.name }}
            </span>
          </div>
        </div>
      </div>

      <div class="pt-4 flex flex-col sm:flex-row gap-3 justify-center">
        <template v-if="(resultData?.pearls_awarded || 0) > 0">
          <NuxtLink :to="`/app/e/${teamInfo?.slug || teamSlugParam}/tienda`">
            <BaseButton variant="primary" block>
              <i class="bi bi-bag-heart-fill mr-1.5"></i>
              Canjear en Tienda
            </BaseButton>
          </NuxtLink>
          <NuxtLink :to="backUrl">
            <BaseButton variant="outline" block>
              Ver Más Trivias
            </BaseButton>
          </NuxtLink>
        </template>
        <template v-else>
          <BaseButton variant="primary" block @click="mode = 'detail'; localError = null">
            <i class="bi bi-arrow-repeat mr-1.5"></i>
            Reintentar Trivia
          </BaseButton>
          <NuxtLink :to="backUrl">
            <BaseButton variant="outline" block>
              Volver a Trivias
            </BaseButton>
          </NuxtLink>
        </template>
      </div>
    </BaseCard>
  </div>
</template>
