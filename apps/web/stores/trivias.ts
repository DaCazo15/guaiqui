import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Database } from '@guaiqui/shared'

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
  const supabase = useSupabaseClient<Database>()

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
      homeSummary.value = data as HomeSummaryData
      return data
    } catch (err: any) {
      errorMessage.value = err.message || 'Error al cargar resumen'
      return null
    } finally {
      isLoading.value = false
    }
  }

  async function fetchLeaderboard(period: 'monthly' | 'weekly' = 'monthly') {
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
      activeTrivias.value = data || []
      return data
    } catch (err: any) {
      errorMessage.value = err.message
      throw err
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

      const attemptId = (attemptRes as any).attempt_id

      // 2. Fetch questions securely via RPC (without is_correct)
      const { data: questionsRes, error: qErr } = await supabase.rpc('get_attempt_questions', {
        p_attempt_id: attemptId,
      })
      if (qErr) throw qErr

      currentAttempt.value = questionsRes as AttemptData
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

  function translateTriviaError(msg: string): string {
    if (!msg) return 'Ocurrió un error inesperado al procesar la trivia.'
    if (msg.includes('TRIVIA_ALREADY_PLAYED') || msg.includes('Maximum participation attempts reached')) {
      return 'Ya has participado en esta trivia previamente.'
    }
    if (msg.includes('ATTEMPT_EXPIRED') || msg.includes('time window is closed')) {
      return 'El tiempo para esta trivia ha expirado.'
    }
    if (msg.includes('verificado')) {
      return 'Debes tener tu correo electrónico verificado para participar.'
    }
    if (msg.includes('inactiva, suspendida')) {
      return 'Tu cuenta no está activa para participar en trivias.'
    }
    return msg
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
    startTrivia,
    submitTrivia,
  }
})
