/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })

// Mock Nuxt globals
;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { useWallet } from '../composables/useWallet'

describe('useWallet composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with default zeroed summary and empty ledger', () => {
    const { summary, ledgerEntries, loading, error } = useWallet()
    expect(summary.value).toEqual({
      balance: 0,
      earned_month: 0,
      spent_month: 0,
      held_pearls: 0,
    })
    expect(ledgerEntries.value).toEqual([])
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('fetchSummary loads wallet summary correctly from RPC', async () => {
    const expectedSummary = {
      balance: 150,
      earned_month: 200,
      spent_month: 50,
      held_pearls: 10,
    }
    mockRpc.mockResolvedValueOnce({ data: expectedSummary, error: null })

    const { summary, fetchSummary, error } = useWallet()
    await fetchSummary()

    expect(mockRpc).toHaveBeenCalledWith('wallet_summary')
    expect(summary.value).toEqual(expectedSummary)
    expect(error.value).toBeNull()
  })

  it('fetchSummary handles RPC error and sets error message', async () => {
    mockRpc.mockResolvedValueOnce({ data: null, error: { message: 'Database connection error' } })

    const { fetchSummary, error } = useWallet()
    await fetchSummary()

    expect(error.value).toBe('Database connection error')
  })

  it('fetchSummary does nothing if user is not authenticated', async () => {
    mockUser.value = null
    const { fetchSummary } = useWallet()
    await fetchSummary()

    expect(mockRpc).not.toHaveBeenCalled()
  })

  it('fetchLedger retrieves entries and updates state with pagination', async () => {
    const mockItems = Array.from({ length: 15 }, (_, i) => ({
      id: `item-${i}`,
      amount: 10,
      type: 'earned',
      status: 'confirmed',
      note: null,
      source_type: 'trivia',
      source_id: `t-${i}`,
      created_at: `2026-10-10T10:00:${i.toString().padStart(2, '0')}Z`,
      description: `Trivia reward ${i}`,
    }))

    mockRpc.mockResolvedValueOnce({ data: mockItems, error: null })

    const { ledgerEntries, fetchLedger, hasMore, loading } = useWallet()
    await fetchLedger('all', false)

    expect(mockRpc).toHaveBeenCalledWith('wallet_ledger', {
      p_type: undefined,
      p_cursor: undefined,
      p_limit: 15,
    })
    expect(ledgerEntries.value).toHaveLength(15)
    expect(hasMore.value).toBe(true)
    expect(loading.value).toBe(false)
  })

  it('fetchLedger sets hasMore to false when returned items are fewer than limit', async () => {
    const mockItems = [
      {
        id: 'item-1',
        amount: 25,
        type: 'earned',
        status: 'confirmed',
        note: null,
        source_type: 'ad',
        source_id: 'ad-1',
        created_at: '2026-10-10T10:00:00Z',
        description: 'Ad reward',
      },
    ]

    mockRpc.mockResolvedValueOnce({ data: mockItems, error: null })

    const { ledgerEntries, fetchLedger, hasMore } = useWallet()
    await fetchLedger('earned', false)

    expect(mockRpc).toHaveBeenCalledWith('wallet_ledger', {
      p_type: 'earned',
      p_cursor: undefined,
      p_limit: 15,
    })
    expect(ledgerEntries.value).toHaveLength(1)
    expect(hasMore.value).toBe(false)
  })

  it('refreshWallet fetches both summary and ledger', async () => {
    mockRpc
      .mockResolvedValueOnce({ data: { balance: 50, earned_month: 50, spent_month: 0, held_pearls: 0 }, error: null })
      .mockResolvedValueOnce({ data: [], error: null })

    const { refreshWallet } = useWallet()
    await refreshWallet()

    expect(mockRpc).toHaveBeenCalledTimes(2)
  })
})
