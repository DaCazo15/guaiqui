/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { useReferrals } from '../composables/useReferrals'

describe('useReferrals composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with default zeroed summary and empty referrals', () => {
    const { summary, loading, error, copied } = useReferrals()
    expect(summary.value).toEqual({
      code: '',
      total_referred: 0,
      qualified_count: 0,
      points_earned: 0,
      referrals: [],
    })
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
    expect(copied.value).toBe(false)
  })

  it('fetchReferralSummary loads referral summary from RPC correctly', async () => {
    const mockData = {
      code: 'GUAIQUI1',
      total_referred: 3,
      qualified_count: 1,
      points_earned: 10,
      referrals: [
        {
          id: 'ref-1',
          referred_name: 'Carlos Fan',
          avatar_url: null,
          status: 'qualified',
          created_at: '2026-10-29T10:00:00Z',
        },
      ],
    }
    mockRpc.mockResolvedValueOnce({ data: mockData, error: null })

    const { summary, referralLink, fetchReferralSummary, error } = useReferrals()
    await fetchReferralSummary()

    expect(mockRpc).toHaveBeenCalledWith('get_my_referral_summary')
    expect(summary.value.code).toBe('GUAIQUI1')
    expect(summary.value.total_referred).toBe(3)
    expect(summary.value.qualified_count).toBe(1)
    expect(summary.value.points_earned).toBe(10)
    expect(summary.value.referrals).toHaveLength(1)
    expect(referralLink.value).toContain('ref=GUAIQUI1')
    expect(error.value).toBeNull()
  })

  it('fetchReferralSummary handles RPC error', async () => {
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'Database error' },
    })

    const { fetchReferralSummary, error } = useReferrals()
    await fetchReferralSummary()

    expect(error.value).toBe('Database error')
  })
})
