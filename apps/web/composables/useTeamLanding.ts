import { ref, computed } from 'vue'
import { useRoute, useRouter, useSupabaseClient, useSupabaseUser } from '#imports'
import type { TeamLandingResponse } from '@guaiqui/shared'

export function useTeamLanding() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const route = useRoute()
  const router = useRouter()

  const landingData = ref<TeamLandingResponse | null>(null)
  const loading = ref(false)
  const actionLoading = ref(false)
  const error = ref<string | null>(null)

  const isNotFound = computed(() => landingData.value?.status === 'not_found')
  const isInactive = computed(() => landingData.value?.status === 'inactive')
  const isActive = computed(() => landingData.value?.status === 'active')

  const fetchTeamLanding = async (slug: string) => {
    loading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await (supabase.rpc as any)('get_team_landing', {
        p_slug: slug.trim().toLowerCase()
      })

      if (rpcError) throw rpcError
      landingData.value = (data as TeamLandingResponse) || null
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : String(err)
      landingData.value = { status: 'not_found', message: error.value }
    } finally {
      loading.value = false
    }
  }

  const toggleFollow = async () => {
    if (!landingData.value?.team) return

    const team = landingData.value.team
    const currentStatus = landingData.value.is_following ?? false

    // Si no hay sesión, redirigir a login preservando la URL de regreso
    if (!user.value) {
      const currentPath = route.fullPath || `/e/${team.slug}`
      router.push({
        path: '/login',
        query: {
          redirect: currentPath,
          action: 'follow',
          team_id: team.id
        }
      })
      return { redirected: true }
    }

    actionLoading.value = true
    error.value = null

    // Actualización optimista
    const nextStatus = !currentStatus
    const prevCount = landingData.value.follower_count ?? 0
    landingData.value.is_following = nextStatus
    landingData.value.follower_count = nextStatus ? prevCount + 1 : Math.max(prevCount - 1, 0)

    try {
      const rpcName = nextStatus ? 'follow_team' : 'unfollow_team'
      const { error: rpcError } = await (supabase.rpc as any)(rpcName, {
        p_team_id: team.id
      })

      if (rpcError) throw rpcError
      return { redirected: false, following: nextStatus }
    } catch (err: unknown) {
      // Revertir optimismo
      landingData.value.is_following = currentStatus
      landingData.value.follower_count = prevCount
      error.value = err instanceof Error ? err.message : String(err)
      throw err
    } finally {
      actionLoading.value = false
    }
  }

  return {
    landingData,
    loading,
    actionLoading,
    error,
    isNotFound,
    isInactive,
    isActive,
    fetchTeamLanding,
    toggleFollow
  }
}
