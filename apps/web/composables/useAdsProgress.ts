import { ref, computed } from 'vue'
import { useSupabaseClient } from '#imports'

export interface AdsProgressData {
  ads_enabled: boolean
  completed_today: number
  daily_limit: number
  block_size: number
  block_progress: number
  next_block_number: number
  pearls_earned_today: number
  can_watch: boolean
  cant_reason: string | null
  ad_min_seconds: number
}

export function useAdsProgress() {
  const supabase = useSupabaseClient()
  const progress = ref<AdsProgressData | null>(null)
  const activeVideosCount = ref(0)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const isAdsEnabled = computed(() => activeVideosCount.value > 0)
  const canWatch = computed(() => activeVideosCount.value > 0 && (progress.value?.can_watch ?? true))
  const remainingToday = computed(() => {
    if (!progress.value) return 0
    return Math.max(0, progress.value.daily_limit - progress.value.completed_today)
  })

  async function fetchProgress() {
    loading.value = true
    error.value = null
    try {
      const [countResult, rpcResult] = await Promise.all([
        supabase
          .from('sponsor_videos')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', true),
        supabase.rpc('get_daily_video_progress'),
      ])

      if (countResult.count !== null && countResult.count !== undefined) {
        activeVideosCount.value = countResult.count
      }

      if (!rpcResult.error && rpcResult.data) {
        const raw = rpcResult.data as Record<string, any>
        const completed = Number(raw.completed_today) || 0
        const maxDaily = Number(raw.max_daily) || 50
        const pointsToday = Number(raw.points_earned_today) || 0

        progress.value = {
          ads_enabled: (countResult.count ?? 0) > 0,
          completed_today: completed,
          daily_limit: maxDaily,
          block_size: 10,
          block_progress: Number(raw.block_progress) || (completed % 10),
          next_block_number: Math.floor(completed / 10) + 1,
          pearls_earned_today: pointsToday,
          can_watch: completed < maxDaily,
          cant_reason: completed >= maxDaily ? 'Límite diario alcanzado' : null,
          ad_min_seconds: 15,
        }
      }
    } catch (err: any) {
      error.value = err?.message || 'Error al obtener el estado de anuncios'
    } finally {
      loading.value = false
    }
  }

  const currentTierPoints = computed(() => {
    const completed = progress.value?.completed_today ?? 0
    if (completed < 10) return 5
    if (completed < 20) return 10
    return 15
  })

  return {
    progress,
    activeVideosCount,
    loading,
    error,
    isAdsEnabled,
    canWatch,
    remainingToday,
    currentTierPoints,
    fetchProgress,
  }
}
