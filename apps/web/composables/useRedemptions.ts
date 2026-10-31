import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface Redemption {
  id: string
  team_id?: string
  fan_id: string
  product_id: string
  variant: string | null
  cost_pearls: number
  status: 'pending' | 'approved' | 'scheduled' | 'delivered' | 'completed' | 'cancelled' | 'rejected' | 'issue' | 'expired'
  code_hash: string
  expires_at: string | null
  approved_at: string | null
  delivered_at: string | null
  created_at: string
  team?: {
    id: string
    name: string
    slug: string
    short_name?: string | null
    logo_url: string | null
  }
  products?: {
    name: string
    category: string
    images: string[]
    description?: string
  }
}

export interface RedemptionHistoryItem {
  id: string
  redemption_id: string
  previous_status: string | null
  new_status: string
  changed_by: string | null
  note: string | null
  created_at: string
}

export interface QRCodeData {
  redemption_id: string
  code: string
  status: string
  variant: string | null
  cost_pearls: number
  expires_at: string | null
}

export const useRedemptions = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const redemptions = ref<Redemption[]>([])
  const currentRedemption = ref<Redemption | null>(null)
  const redemptionHistory = ref<RedemptionHistoryItem[]>([])
  const qrData = ref<QRCodeData | null>(null)
  const loading = ref(false)
  const actionLoading = ref(false)
  const error = ref<string | null>(null)

  const fetchMyRedemptions = async () => {
    if (!user.value) return
    loading.value = true
    error.value = null
    try {
      const { data, error: dbError } = await supabase
        .from('redemptions')
        .select(`
          *,
          team:teams (
            id,
            name,
            slug,
            short_name,
            logo_url
          ),
          products (
            name,
            category,
            images,
            description
          )
        `)
        .order('created_at', { ascending: false })

      if (dbError) throw dbError
      redemptions.value = (data as unknown as Redemption[]) || []
    } catch (err: any) {
      error.value = err.message || 'Error al cargar tus canjes'
    } finally {
      loading.value = false
    }
  }

  const fetchRedemptionDetails = async (id: string) => {
    if (!user.value) return null
    loading.value = true
    error.value = null
    qrData.value = null
    try {
      const { data, error: dbError } = await supabase
        .from('redemptions')
        .select(`
          *,
          team:teams (
            id,
            name,
            slug,
            short_name,
            logo_url
          ),
          products (
            name,
            category,
            images,
            description
          )
        `)
        .eq('id', id)
        .single()

      if (dbError) throw dbError
      const item = data as unknown as Redemption
      currentRedemption.value = item

      // Cargar historial de estados
      const { data: historyData, error: historyError } = await supabase
        .from('redemption_history')
        .select('*')
        .eq('redemption_id', id)
        .order('created_at', { ascending: true })

      if (!historyError && historyData) {
        redemptionHistory.value = historyData as RedemptionHistoryItem[]
      }

      // Si está approved o scheduled, intentar cargar QR
      if (item && ['approved', 'scheduled'].includes(item.status)) {
        await fetchRedemptionQR(id)
      }

      return item
    } catch (err: any) {
      error.value = err.message || 'Error al cargar los detalles del canje'
      return null
    } finally {
      loading.value = false
    }
  }

  const fetchRedemptionQR = async (id: string) => {
    try {
      const { data, error: rpcError } = await supabase.rpc('get_redemption_qr', {
        p_redemption_id: id,
      })
      if (rpcError) throw rpcError
      qrData.value = data as unknown as QRCodeData
      return data as unknown as QRCodeData
    } catch (err: any) {
      qrData.value = null
      return null
    }
  }

  const redeemProduct = async (
    productId: string,
    variant: string | null,
    idempotencyKey: string
  ) => {
    actionLoading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await supabase.rpc('redeem_product', {
        p_product_id: productId,
        p_variant: variant || 'Única',
        p_idempotency_key: idempotencyKey,
      })

      if (rpcError) throw rpcError
      return { success: true, data }
    } catch (err: any) {
      let friendlyError = err.message || 'Error al procesar el canje'
      if (friendlyError.includes('INSUFFICIENT_PERLITAS')) {
        friendlyError = 'No tienes suficientes perlitas para realizar este canje.'
      } else if (friendlyError.includes('OUT_OF_STOCK')) {
        friendlyError = 'Este producto se encuentra temporalmente agotado.'
      } else if (friendlyError.includes('PRODUCT_EXPIRED')) {
        friendlyError = 'La oferta de este premio ha vencido.'
      } else if (friendlyError.includes('PRODUCT_NOT_FOUND') || friendlyError.includes('PRODUCT_INACTIVE')) {
        friendlyError = 'El producto no está disponible para canje.'
      }
      error.value = friendlyError
      return { success: false, error: friendlyError }
    } finally {
      actionLoading.value = false
    }
  }

  const cancelRedemption = async (redemptionId: string, reason?: string) => {
    actionLoading.value = true
    error.value = null
    try {
      const { data, error: rpcError } = await supabase.rpc('cancel_redemption', {
        p_redemption_id: redemptionId,
        p_reason: reason || 'Cancelado por el usuario desde la app',
      })

      if (rpcError) throw rpcError
      // Refrescar detalle
      await fetchRedemptionDetails(redemptionId)
      return { success: true, data }
    } catch (err: any) {
      const msg = err.message || 'Error al cancelar el canje'
      error.value = msg
      return { success: false, error: msg }
    } finally {
      actionLoading.value = false
    }
  }

  return {
    redemptions: computed(() => redemptions.value),
    currentRedemption: computed(() => currentRedemption.value),
    redemptionHistory: computed(() => redemptionHistory.value),
    qrData: computed(() => qrData.value),
    loading: computed(() => loading.value),
    actionLoading: computed(() => actionLoading.value),
    error: computed(() => error.value),
    fetchMyRedemptions,
    fetchRedemptionDetails,
    fetchRedemptionQR,
    redeemProduct,
    cancelRedemption,
  }
}
