import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface ReferralUserItem {
  id: string
  referred_name: string
  avatar_url: string | null
  status: 'registered' | 'qualified'
  created_at: string
}

export interface ReferredByInfo {
  has_referrer: boolean
  referrer_id?: string
  referrer_name?: string
  referrer_avatar?: string | null
  referred_at?: string
}

export interface ReferralSummary {
  code: string
  total_referred: number
  qualified_count: number
  points_earned: number
  referrals: ReferralUserItem[]
  referred_by?: ReferredByInfo
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
    referred_by: { has_referrer: false },
  })
  const loading = ref(false)
  const claiming = ref(false)
  const error = ref<string | null>(null)
  const claimError = ref<string | null>(null)
  const claimSuccess = ref<string | null>(null)
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
          referred_by: d.referred_by || { has_referrer: false },
        }
      }
    } catch (err: any) {
      error.value = err.message || 'Error al cargar resumen de referidos'
    } finally {
      loading.value = false
    }
  }

  const claimReferralCode = async (code: string) => {
    if (!user.value) return { success: false, message: 'Inicia sesión para vincular un código' }
    if (!code || !code.trim()) {
      claimError.value = 'Ingresa un código de referido válido'
      return { success: false, message: claimError.value }
    }

    claiming.value = true
    claimError.value = null
    claimSuccess.value = null

    try {
      const { data, error: rpcError } = await supabase.rpc('claim_referral_code', {
        p_code: code.trim().toUpperCase()
      })

      if (rpcError) throw rpcError

      const res = data as any
      claimSuccess.value = res?.message || '¡Código vinculado con éxito!'

      // Actualizar estado local inmediatamente
      if (res?.referrer_name) {
        summary.value.referred_by = {
          has_referrer: true,
          referrer_id: res.referrer_id,
          referrer_name: res.referrer_name,
          referred_at: new Date().toISOString()
        }
      }

      // Re-consultar para asegurar consistencia
      await fetchReferralSummary()

      return { success: true, message: claimSuccess.value, referrer_name: res?.referrer_name }
    } catch (err: any) {
      let msg = err.message || 'Error al vincular código de referido'
      if (msg.includes('No puedes utilizar tu propio código')) {
        msg = 'No puedes utilizar tu propio código de referido'
      } else if (msg.includes('código de referido no existe')) {
        msg = 'El código ingresado no existe o no es válido'
      } else if (msg.includes('Ya tienes un referente')) {
        msg = 'Ya tienes un referente vinculado a tu cuenta'
      }
      claimError.value = msg
      return { success: false, message: msg }
    } finally {
      claiming.value = false
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
    referredBy: computed(() => summary.value.referred_by || { has_referrer: false }),
    referralLink,
    loading: computed(() => loading.value),
    claiming: computed(() => claiming.value),
    error: computed(() => error.value),
    claimError: computed(() => claimError.value),
    claimSuccess: computed(() => claimSuccess.value),
    copied: computed(() => copied.value),
    fetchReferralSummary,
    claimReferralCode,
    copyLink,
    copyCode,
  }
}
