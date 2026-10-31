import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface ReferralUserItem {
  id: string
  referred_name: string
  avatar_url: string | null
  status: 'registered' | 'qualified'
  created_at: string
}

export interface ReferralSummary {
  code: string
  total_referred: number
  qualified_count: number
  points_earned: number
  referrals: ReferralUserItem[]
}

export const useReferrals = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const summary = ref<ReferralSummary>({
    code: '',
    total_referred: 0,
    qualified_count: 0,
    points_earned: 0,
    referrals: [],
  })
  const loading = ref(false)
  const error = ref<string | null>(null)
  const copied = ref(false)

  const referralLink = computed(() => {
    if (!summary.value.code) return ''
    if (typeof window !== 'undefined') {
      return `${window.location.origin}/registro?ref=${summary.value.code}`
    }
    return `https://guaiqueries.com/registro?ref=${summary.value.code}`
  })

  const fetchReferralSummary = async () => {
    if (!user.value) return

    loading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await supabase.rpc('get_my_referral_summary')
      if (rpcError) throw rpcError
      if (data) {
        const d = data as any
        summary.value = {
          code: d.code || '',
          total_referred: d.total_referred ?? 0,
          qualified_count: d.qualified_count ?? 0,
          points_earned: d.points_earned ?? 0,
          referrals: Array.isArray(d.referrals) ? d.referrals : [],
        }
      }
    } catch (err: any) {
      error.value = err.message || 'Error al cargar resumen de referidos'
    } finally {
      loading.value = false
    }
  }

  const copyLink = async () => {
    if (!referralLink.value) return false
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(referralLink.value)
      } else {
        const input = document.createElement('input')
        input.value = referralLink.value
        document.body.appendChild(input)
        input.select()
        document.execCommand('copy')
        document.body.removeChild(input)
      }
      copied.value = true
      setTimeout(() => {
        copied.value = false
      }, 2500)
      return true
    } catch {
      return false
    }
  }

  const copyCode = async () => {
    if (!summary.value.code) return false
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(summary.value.code)
      } else {
        const input = document.createElement('input')
        input.value = summary.value.code
        document.body.appendChild(input)
        input.select()
        document.execCommand('copy')
        document.body.removeChild(input)
      }
      copied.value = true
      setTimeout(() => {
        copied.value = false
      }, 2500)
      return true
    } catch {
      return false
    }
  }

  return {
    summary: computed(() => summary.value),
    referralLink,
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    copied: computed(() => copied.value),
    fetchReferralSummary,
    copyLink,
    copyCode,
  }
}
