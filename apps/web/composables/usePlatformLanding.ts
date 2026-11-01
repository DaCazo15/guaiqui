import { ref } from 'vue'
import { useSupabaseClient } from '#imports'
import type { PlatformLandingResponse, PlatformLandingTeamItem } from '@guaiqui/shared'

export function usePlatformLanding() {
  const supabase = useSupabaseClient()

  const platformData = ref<PlatformLandingResponse | null>(null)
  const searchResults = ref<PlatformLandingTeamItem[]>([])
  const loading = ref(false)
  const searchLoading = ref(false)
  const error = ref<string | null>(null)

  const fetchPlatformLanding = async () => {
    loading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await (supabase.rpc as any)('get_platform_landing')
      if (rpcError) throw rpcError
      platformData.value = data as PlatformLandingResponse
      searchResults.value = platformData.value?.teams || []
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : String(err)
    } finally {
      loading.value = false
    }
  }

  const searchTeams = async (query: string) => {
    const cleanQuery = query.trim()
    if (!cleanQuery) {
      searchResults.value = platformData.value?.teams || []
      return
    }

    searchLoading.value = true
    try {
      const { data, error: rpcError } = await (supabase.rpc as any)('search_teams', {
        p_query: cleanQuery,
        p_limit: 20,
        p_offset: 0
      })

      if (rpcError) throw rpcError
      searchResults.value = (data as PlatformLandingTeamItem[]) || []
    } catch (err: unknown) {
      console.error('Error searching teams:', err)
      // Fallback local sobre los equipos ya cargados
      const q = cleanQuery.toLowerCase()
      searchResults.value = (platformData.value?.teams || []).filter(
        t => t.name.toLowerCase().includes(q) || t.slug.toLowerCase().includes(q)
      )
    } finally {
      searchLoading.value = false
    }
  }

  return {
    platformData,
    searchResults,
    loading,
    searchLoading,
    error,
    fetchPlatformLanding,
    searchTeams
  }
}
