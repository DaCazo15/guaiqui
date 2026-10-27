import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface QuestionOption {
  option_id: string
  option_text: string
}

export interface Question {
  question_id: string
  question_text: string
  points: number
  options: QuestionOption[]
}

export interface AttemptData {
  attempt_id: string
  trivia_id: string
  expires_at: string
  seed: number
  questions: Question[]
}

export interface LeaderboardItem {
  rank: number
  user_id: string
  display_name: string
  avatar_url: string | null
  pearls_earned: number
  is_current_user: boolean
}

export interface HomeSummaryData {
  balance: number
  active_trivia: {
    id: string
    title: string
    description: string
    time_limit_seconds: number
    starts_at: string
    ends_at: string
    max_attempts: number
    played: boolean
  } | null
  streak: {
    streak_days: number
    bonus_awarded: number
    already_awarded_today: boolean
  } | null
  next_game: {
    id: string
    opponent: string
    location: string
    game_date: string
    is_home: boolean
    status: string
  } | null
  my_rank: number | null
}

export const useTriviaStore = defineStore('trivias', () => {
  const supabase = useSupabaseClient()

  const homeSummary = ref<HomeSummaryData | null>(null)
  const leaderboard = ref<LeaderboardItem[]>([])
  const activeTrivias = ref<any[]>([])
  const currentAttempt = ref<AttemptData | null>(null)
  const currentResult = ref<any | null>(null)
  const isLoading = ref(false)
  const errorMessage = ref<string | null>(null)

  async function fetchHomeSummary() {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.rpc('home_summary')
      if (error) throw error
      homeSummary.value = data as unknown as HomeSummaryData
      return data
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al cargar resumen'
      return null
    } finally {
      isLoading.value = false
    }
  }

  async function fetchLeaderboard(period: 'all_time' | 'monthly' | 'weekly' = 'all_time') {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.rpc('get_leaderboard', { p_period: period })
      if (error) throw error
      leaderboard.value = (data as any)?.leaderboard || []
      return leaderboard.value
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al cargar el ranking'
      return []
    } finally {
      isLoading.value = false
    }
  }

  async function fetchTrivias() {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase
        .from('trivias')
        .select('*')
        .order('starts_at', { ascending: false })

      if (error) throw error

      // Consultar intentos del usuario para identificar trivias ganadas
      const { data: userAttempts } = await supabase
        .from('trivia_attempts')
        .select('trivia_id, score, pearls_awarded, submitted_at')

      const wonMap = new Set<string>()
      if (userAttempts && Array.isArray(userAttempts)) {
        userAttempts.forEach((att: any) => {
          if (att.submitted_at && att.pearls_awarded > 0) {
            wonMap.add(att.trivia_id)
          }
        })
      }

      const formatted = (data || []).map((t: any) => ({
        ...t,
        is_won: wonMap.has(t.id),
      }))

      activeTrivias.value = formatted
      return formatted
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
    } finally {
      isLoading.value = false
    }
  }

  async function fetchTriviaById(id: string) {
    if (!id) return null
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase
        .from('trivias')
        .select('*')
        .eq('id', id)
        .single()

      if (error) throw error

      // Consultar intentos del usuario para verificar si ya fue ganada
      const { data: userAttempts } = await supabase
        .from('trivia_attempts')
        .select('trivia_id, score, pearls_awarded, submitted_at')
        .eq('trivia_id', id)

      const isWon = Array.isArray(userAttempts) && userAttempts.some(
        (att: any) => att.submitted_at && att.pearls_awarded > 0
      )

      const formatted = {
        ...data,
        is_won: isWon,
      }

      const idx = activeTrivias.value.findIndex((t: any) => t.id === id)
      if (idx !== -1) {
        activeTrivias.value[idx] = formatted
      } else {
        activeTrivias.value.push(formatted)
      }

      return formatted
    } catch (err: any) {
      errorMessage.value = err.message
      return activeTrivias.value.find((t: any) => t.id === id) || null
    } finally {
      isLoading.value = false
    }
  }

  async function startTrivia(triviaId: string, idempotencyKey: string) {
    isLoading.value = true
    errorMessage.value = null
    try {
      // 1. Start or resume attempt via RPC
      const { data: attemptRes, error: startErr } = await supabase.rpc('start_trivia_attempt', {
        p_trivia_id: triviaId,
        p_idempotency_key: idempotencyKey,
      })
      if (startErr) throw startErr

      const res = attemptRes as any
      if (!res?.questions || !Array.isArray(res.questions) || res.questions.length === 0) {
        throw new Error('No se encontraron preguntas disponibles para esta trivia.')
      }

      currentAttempt.value = {
        attempt_id: res.attempt_id,
        trivia_id: triviaId,
        expires_at: res.expires_at,
        seed: res.seed,
        questions: res.questions,
      }
      return currentAttempt.value
    } catch (err: any) {
      errorMessage.value = translateTriviaError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  async function submitTrivia(attemptId: string, answers: Record<string, string>, idempotencyKey: string) {
    isLoading.value = true
    errorMessage.value = null
    try {
      const { data, error } = await supabase.rpc('submit_trivia_attempt', {
        p_attempt_id: attemptId,
        p_answers: answers,
        p_idempotency_key: idempotencyKey,
      })
      if (error) throw error

      currentResult.value = data
      return data
    } catch (err: any) {
      errorMessage.value = translateTriviaError(err.message)
      throw new Error(errorMessage.value)
    } finally {
      isLoading.value = false
    }
  }

  return {
    homeSummary,
    leaderboard,
    activeTrivias,
    currentAttempt,
    currentResult,
    isLoading,
    errorMessage,
    fetchHomeSummary,
    fetchLeaderboard,
    fetchTrivias,
    fetchTriviaById,
    startTrivia,
    submitTrivia,
    translateTriviaError,
  }
})

export function translateTriviaError(msg: string): string {
  if (process.dev || (import.meta as any).env?.DEV) {
    console.warn('[translateTriviaError raw]:', msg)
  }
  if (!msg) return 'Ocurrió un error inesperado al procesar la trivia.'
  if (msg.includes('TRIVIA_ALREADY_WON')) {
    return 'Ya has ganado esta trivia previamente.'
  }
  if (msg.includes('TRIVIA_ALREADY_PLAYED') || msg.includes('Maximum participation attempts reached')) {
    return 'Ya has participado en esta trivia previamente.'
  }
  if (msg.includes('TRIVIA_NOT_STARTED')) {
    return 'Esta trivia aún no ha comenzado. Estará disponible próximamente.'
  }
  if (msg.includes('ATTEMPT_EXPIRED')) {
    return 'Se agotó tu tiempo para responder.'
  }
  if (msg.includes('TRIVIA_EXPIRED')) {
    return 'Esta trivia ya cerró.'
  }
  if (msg.includes('time window is closed')) {
    return 'La ventana de participación de esta trivia no está activa en este momento.'
  }
  if (msg.includes('CAPTCHA_REQUIRED')) {
    return 'Por favor, completa la verificación de seguridad antes de comenzar.'
  }
  if (msg.includes('verificado') || msg.includes('assert_active_verified_fan')) {
    return 'Debes tener tu correo electrónico verificado para participar.'
  }
  if (msg.includes('inactiva, suspendida')) {
    return 'Tu cuenta no está activa para participar en trivias.'
  }
  return msg
}
