import { ref, computed } from 'vue'
import { useRoute, useRouter, useSupabaseClient, useSupabaseUser } from '#imports'

export interface TeamSummary {
  id: string
  name: string
  slug: string
  short_name?: string | null
  logo_url: string | null
  primary_color?: string | null
  secondary_color?: string | null
  status: 'active' | 'inactive'
  is_following: boolean
  balance: number
  held_balance?: number
}

const STORAGE_KEY = 'guaiqui_active_team_slug'

// Shared state across components
const activeTeam = ref<TeamSummary | null>(null)
const followedTeams = ref<TeamSummary[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const isPickerOpen = ref(false)
const pickerTargetSection = ref<'trivias' | 'tienda' | 'hub'>('trivias')

export const useCurrentTeam = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const route = useRoute()
  const router = useRouter()

  const safeGetStoredSlug = (): string | null => {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        return window.localStorage.getItem(STORAGE_KEY)
      }
    } catch {
      // Ignore security errors in restricted environments / private mode
    }
    return null
  }

  const safeSetStoredSlug = (slug: string) => {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        window.localStorage.setItem(STORAGE_KEY, slug)
      }
    } catch {
      // Ignore
    }
  }

  const fetchFollowedTeams = async () => {
    if (!user.value) return []
    loading.value = true
    error.value = null
    try {
      // Fetch wallet summary which already computes per-team balances and follow status
      const { data, error: rpcError } = await supabase.rpc('get_wallet_summary')
      if (rpcError) throw rpcError

      const summary = data as any
      const teamsList: TeamSummary[] = (summary?.teams || [])
        .filter((t: any) => t.is_following === true)
        .map((t: any) => ({
          id: t.team_id,
          name: t.team_name,
          slug: t.team_slug,
          short_name: t.team_short_name,
          logo_url: t.team_logo_url,
          primary_color: t.team_primary_color,
          secondary_color: t.team_secondary_color,
          status: 'active', // Only active teams can be followed
          is_following: true,
          balance: t.balance || 0,
          held_balance: t.held_balance || 0,
        }))

      followedTeams.value = teamsList
      return teamsList
    } catch (err: any) {
      error.value = err.message || 'Error al cargar equipos seguidos'
      return []
    } finally {
      loading.value = false
    }
  }

  const loadTeamBySlug = async (slug?: string) => {
    loading.value = true
    error.value = null
    try {
      const targetSlug = slug || (route.params.slug as string) || safeGetStoredSlug() || 'guaiqueries'

      // Fetch team public details
      const { data: teamData, error: teamError } = await supabase
        .from('teams')
        .select('id, name, slug, short_name, logo_url, primary_color, secondary_color, status')
        .eq('slug', targetSlug)
        .maybeSingle()

      if (teamError) throw teamError

      let team = teamData
      if (!team) {
        const { data: defaultTeam } = await supabase
          .from('teams')
          .select('id, name, slug, short_name, logo_url, primary_color, secondary_color, status')
          .eq('slug', 'guaiqueries')
          .maybeSingle()
        team = defaultTeam || null
      }
      if (!team) return null

      // Check follow status & balance for this fan
      let isFollowing = false
      let teamBalance = 0
      const teamHeld = 0

      if (user.value) {
        const { data: followData } = await supabase
          .from('team_follows')
          .select('team_id')
          .eq('user_id', user.value.id)
          .eq('team_id', team.id)
          .maybeSingle()
        isFollowing = !!followData

        const { data: walletData } = await supabase
          .from('wallets')
          .select('balance_cache')
          .eq('fan_id', user.value.id)
          .eq('team_id', team.id)
          .maybeSingle()
        teamBalance = walletData?.balance_cache || 0
      }

      const loadedSummary: TeamSummary = {
        id: team.id,
        name: team.name,
        slug: team.slug,
        short_name: team.short_name,
        logo_url: team.logo_url,
        primary_color: team.primary_color,
        secondary_color: team.secondary_color,
        status: team.status as 'active' | 'inactive',
        is_following: isFollowing,
        balance: teamBalance,
        held_balance: teamHeld,
      }

      activeTeam.value = loadedSummary
      safeSetStoredSlug(team.slug)
      return loadedSummary
    } catch (err: any) {
      error.value = err.message || 'Error al cargar información del equipo'
      return null
    } finally {
      loading.value = false
    }
  }

  const openPicker = (targetSection: 'trivias' | 'tienda' | 'hub' = 'trivias') => {
    pickerTargetSection.value = targetSection
    isPickerOpen.value = true
    fetchFollowedTeams()
  }

  const closePicker = () => {
    isPickerOpen.value = false
  }

  const selectTeam = (teamSlug: string, targetSection?: 'trivias' | 'tienda' | 'hub') => {
    safeSetStoredSlug(teamSlug)
    closePicker()
    const section = targetSection || pickerTargetSection.value
    if (section === 'hub') {
      router.push(`/app/e/${teamSlug}`)
    } else {
      router.push(`/app/e/${teamSlug}/${section}`)
    }
  }

  return {
    activeTeam: computed(() => activeTeam.value),
    followedTeams: computed(() => followedTeams.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    isTeamActive: computed(() => activeTeam.value?.status === 'active'),
    isFollowingActiveTeam: computed(() => activeTeam.value?.is_following === true),
    isPickerOpen: computed(() => isPickerOpen.value),
    pickerTargetSection: computed(() => pickerTargetSection.value),
    fetchFollowedTeams,
    loadTeamBySlug,
    openPicker,
    closePicker,
    selectTeam,
  }
}
