import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface FanBadgeItem {
  id: string
  slug: string
  name: string
  description: string
  icon_name: string
  category: string
  tier: 'bronce' | 'plata' | 'oro' | 'platino'
  criteria_summary: string
  is_unlocked: boolean
  awarded_at?: string | null
}

export interface FanProfileStats {
  total_pearls: number
  trivias_count: number
  redemptions_count: number
  streak_days: number
}

export interface FanProfileLevel {
  tier_name: string
  tier_icon: string
  current_xp: number
  next_threshold: number | null
  progress_percent: number
}

export interface FanFollowedTeam {
  team_id: string
  name: string
  slug: string
  short_name?: string | null
  logo_url?: string | null
  primary_color?: string | null
  followed_at: string
  balance_cache: number
}

export interface EnrichedProfileData {
  found: boolean
  profile?: any
  stats?: FanProfileStats
  level?: FanProfileLevel
  badges?: FanBadgeItem[]
  teams?: FanFollowedTeam[]
}

export const useFanProfile = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const data = ref<EnrichedProfileData | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const profile = computed(() => data.value?.profile ?? null)
  const stats = computed<FanProfileStats>(() => data.value?.stats ?? {
    total_pearls: 0,
    trivias_count: 0,
    redemptions_count: 0,
    streak_days: 0,
  })
  const level = computed<FanProfileLevel>(() => data.value?.level ?? {
    tier_name: 'Fan Novato',
    tier_icon: 'bi-star-fill',
    current_xp: 0,
    next_threshold: 500,
    progress_percent: 0,
  })
  const badges = computed<FanBadgeItem[]>(() => data.value?.badges ?? [])
  const teamsFollowed = computed<FanFollowedTeam[]>(() => data.value?.teams ?? [])

  const unlockedBadgesCount = computed(() => {
    return badges.value.filter(b => b.is_unlocked).length
  })

  const fetchProfileEnriched = async (targetUserId?: string) => {
    const uid = targetUserId || user.value?.id
    if (!uid) return null

    loading.value = true
    error.value = null

    try {
      const { data: res, error: rpcError } = await supabase.rpc('get_fan_profile_enriched', {
        p_fan_id: uid
      })

      if (rpcError) throw rpcError

      const result = res as unknown as EnrichedProfileData
      if (!result || !result.found) {
        error.value = 'Perfil no disponible'
        data.value = null
        return null
      }

      data.value = result
      return result
    } catch (err: any) {
      error.value = err.message || 'Error al cargar perfil enriquecido'
      data.value = null
      return null
    } finally {
      loading.value = false
    }
  }

  return {
    data: computed(() => data.value),
    profile,
    stats,
    level,
    badges,
    teamsFollowed,
    unlockedBadgesCount,
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    fetchProfileEnriched,
  }
}
