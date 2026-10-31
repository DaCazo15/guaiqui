import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface PendingGrantItem {
  id: string
  source: 'ads_block' | 'referral_signup'
  amount: number
  status: 'pending' | 'claimed' | 'expired'
  expires_at: string | null
  created_at: string
  days_remaining: number | null
}

export const usePendingGrants = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const grants = ref<PendingGrantItem[]>([])
  const loading = ref(false)
  const claiming = ref(false)
  const error = ref<string | null>(null)
  const successMessage = ref<string | null>(null)

  const totalPendingPearls = computed(() => {
    return grants.value.reduce((acc, g) => acc + (g.amount || 0), 0)
  })

  const fetchPendingGrants = async () => {
    if (!user.value) {
      grants.value = []
      return
    }

    loading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await supabase.rpc('get_pending_pearl_grants')
      if (rpcError) throw rpcError
      grants.value = Array.isArray(data) ? (data as unknown as PendingGrantItem[]) : []
    } catch (err: any) {
      error.value = err.message || 'Error al cargar perlitas pendientes'
    } finally {
      loading.value = false
    }
  }

  const claimGrant = async (grantId: string, teamId: string) => {
    if (!user.value || !grantId || !teamId) return false

    claiming.value = true
    error.value = null
    successMessage.value = null

    try {
      const { data, error: rpcError } = await supabase.rpc('claim_pending_grant', {
        p_grant_id: grantId,
        p_team_id: teamId,
      })
      if (rpcError) throw rpcError

      // Remove claimed grant locally for immediate reactive feedback
      grants.value = grants.value.filter((g) => g.id !== grantId)
      successMessage.value = '¡Perlitas asignadas exitosamente a tu equipo!'
      return true
    } catch (err: any) {
      error.value = err.message || 'Error al asignar perlitas al equipo'
      return false
    } finally {
      claiming.value = false
    }
  }

  return {
    grants: computed(() => grants.value),
    totalPendingPearls,
    loading: computed(() => loading.value),
    claiming: computed(() => claiming.value),
    error: computed(() => error.value),
    successMessage: computed(() => successMessage.value),
    fetchPendingGrants,
    claimGrant,
  }
}
