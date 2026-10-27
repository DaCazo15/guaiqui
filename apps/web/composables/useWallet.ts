import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'

export interface WalletSummary {
  balance: number
  earned_month: number
  spent_month: number
  held_pearls: number
}

export interface LedgerItem {
  id: string
  amount: number
  type: string
  status: string
  note: string | null
  source_type: string
  source_id: string
  created_at: string
  description: string
}

export const useWallet = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const summary = ref<WalletSummary>({
    balance: 0,
    earned_month: 0,
    spent_month: 0,
    held_pearls: 0,
  })

  const ledgerEntries = ref<LedgerItem[]>([])
  const loading = ref(false)
  const loadingMore = ref(false)
  const hasMore = ref(true)
  const error = ref<string | null>(null)
  const currentFilter = ref<string>('all')

  const fetchSummary = async () => {
    if (!user.value) return
    try {
      const { data, error: rpcError } = await supabase.rpc('wallet_summary')
      if (rpcError) throw rpcError
      if (data) {
        summary.value = data as unknown as WalletSummary
      }
    } catch (err: any) {
      error.value = err.message || 'Error al cargar resumen de billetera'
    }
  }

  const fetchLedger = async (type: string = 'all', isLoadMore: boolean = false) => {
    if (!user.value) return
    if (isLoadMore) {
      loadingMore.value = true
    } else {
      loading.value = true
      ledgerEntries.value = []
      hasMore.value = true
    }
    error.value = null

    try {
      const cursor = isLoadMore && ledgerEntries.value.length > 0
        ? ledgerEntries.value[ledgerEntries.value.length - 1].created_at
        : undefined

      const { data, error: rpcError } = await supabase.rpc('wallet_ledger', {
        p_type: type === 'all' ? undefined : type,
        p_cursor: cursor,
        p_limit: 15,
      })

      if (rpcError) throw rpcError

      const newEntries = (data as unknown as LedgerItem[]) || []
      if (newEntries.length < 15) {
        hasMore.value = false
      }

      if (isLoadMore) {
        ledgerEntries.value.push(...newEntries)
      } else {
        ledgerEntries.value = newEntries
      }
      currentFilter.value = type
    } catch (err: any) {
      error.value = err.message || 'Error al cargar historial'
    } finally {
      loading.value = false
      loadingMore.value = false
    }
  }

  const refreshWallet = async () => {
    await Promise.all([
      fetchSummary(),
      fetchLedger(currentFilter.value, false),
    ])
  }

  return {
    summary: computed(() => summary.value),
    ledgerEntries: computed(() => ledgerEntries.value),
    loading: computed(() => loading.value),
    loadingMore: computed(() => loadingMore.value),
    hasMore: computed(() => hasMore.value),
    error: computed(() => error.value),
    currentFilter,
    fetchSummary,
    fetchLedger,
    refreshWallet,
  }
}
