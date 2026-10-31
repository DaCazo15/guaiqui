import { ref, computed } from 'vue'
import type { TeamLandingData, TeamLandingProfile } from '@guaiqui/shared'

export function useTeamLanding() {
  const supabase = useSupabaseClient()
  const loading = ref(false)
  const error = ref<string | null>(null)
  const data = ref<TeamLandingData | null>(null)

  const team = computed<TeamLandingProfile | null>(() => data.value?.team ?? null)
  const announcement = computed(() => data.value?.announcement ?? null)
  const heroSlides = computed(() => data.value?.hero_slides ?? [])
  const rosterPreview = computed(() => data.value?.roster_preview ?? [])
  const triviasPreview = computed(() => data.value?.trivias_preview ?? [])
  const productsPreview = computed(() => data.value?.products_preview ?? [])
  const milestones = computed(() => data.value?.milestones ?? [])
  const faqs = computed(() => data.value?.faqs ?? [])

  async function fetchTeamLanding(identifier: string) {
    if (!identifier) {
      error.value = 'Identificador no proporcionado'
      return null
    }

    loading.value = true
    error.value = null

    try {
      const { data: res, error: rpcError } = await supabase.rpc('get_team_landing_data', {
        p_identifier: identifier
      })

      if (rpcError) throw rpcError

      const result = res as unknown as TeamLandingData
      if (!result || !result.found) {
        error.value = result?.error || 'Equipo no encontrado'
        data.value = null
        return null
      }

      data.value = result

      // Si estamos en el navegador, guardar equipo activo para conversiones de registro
      if (typeof window !== 'undefined' && result.team) {
        try {
          localStorage.setItem('guaiqui_active_team_slug', result.team.slug)
          localStorage.setItem('guaiqui_active_team_id', result.team.id)
        } catch {
          // localStorage deshabilitado o no disponible
        }
      }

      return result
    } catch (err: any) {
      console.error('Error fetching team landing data:', err)
      error.value = err.message || 'Error al cargar los datos del equipo'
      data.value = null
      return null
    } finally {
      loading.value = false
    }
  }

  function applyTeamTheme(primary?: string | null, secondary?: string | null) {
    if (typeof document === 'undefined') return
    const root = document.documentElement
    if (primary) {
      root.style.setProperty('--team-primary', primary)
    }
    if (secondary) {
      root.style.setProperty('--team-secondary', secondary)
    }
  }

  return {
    loading,
    error,
    data,
    team,
    announcement,
    heroSlides,
    rosterPreview,
    triviasPreview,
    productsPreview,
    milestones,
    faqs,
    fetchTeamLanding,
    applyTeamTheme
  }
}
