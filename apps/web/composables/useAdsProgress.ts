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

  const isAdsEnabled = computed(() => activeVideosCount.value > 0 || (progress.value?.ads_enabled ?? false))
  const canWatch = computed(() => activeVideosCount.value > 0 || (progress.value?.can_watch ?? false))
  const remainingToday = computed(() => {
    if (!progress.value) return 0
    return Math.max(0, progress.value.daily_limit - progress.value.completed_today)
  })

  async function fetchProgress() {
    loading.value = true
    error.value = null
    try {
      const { count } = await supabase
        .from('sponsor_videos')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      if (count !== null) {
        activeVideosCount.value = count
      }

      const { data, error: err } = await supabase.rpc('get_ads_progress')
      if (!err && data) {
        progress.value = data as AdsProgressData
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
