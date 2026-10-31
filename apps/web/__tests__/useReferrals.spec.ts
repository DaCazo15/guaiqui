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

  it('initializes with default zeroed summary, empty referrals and no referrer', () => {
    const { summary, referredBy, loading, error, copied } = useReferrals()
    expect(summary.value).toEqual({
      code: '',
      total_referred: 0,
      qualified_count: 0,
      points_earned: 0,
      referrals: [],
      referred_by: { has_referrer: false },
    })
    expect(referredBy.value.has_referrer).toBe(false)
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
    expect(copied.value).toBe(false)
  })

  it('fetchReferralSummary loads referral summary and referred_by from RPC correctly', async () => {
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
      referred_by: {
        has_referrer: true,
        referrer_id: 'ref-owner-uuid',
        referrer_name: 'Juan Referidor',
        referrer_avatar: null,
        referred_at: '2026-10-25T12:00:00Z',
      },
    }
    mockRpc.mockResolvedValueOnce({ data: mockData, error: null })

    const { summary, referredBy, referralLink, fetchReferralSummary, error } = useReferrals()
    await fetchReferralSummary()

    expect(mockRpc).toHaveBeenCalledWith('get_my_referral_summary')
    expect(summary.value.code).toBe('GUAIQUI1')
    expect(summary.value.total_referred).toBe(3)
    expect(summary.value.qualified_count).toBe(1)
    expect(summary.value.points_earned).toBe(10)
    expect(summary.value.referrals).toHaveLength(1)
    expect(referredBy.value.has_referrer).toBe(true)
    expect(referredBy.value.referrer_name).toBe('Juan Referidor')
    expect(referralLink.value).toContain('ref=GUAIQUI1')
    expect(error.value).toBeNull()
  })

  it('claimReferralCode links referrer code successfully', async () => {
    mockRpc
      .mockResolvedValueOnce({
        data: { success: true, referrer_name: 'Amigo Pro', message: '¡Código vinculado con éxito!' },
        error: null,
      })
      .mockResolvedValueOnce({
        data: {
          code: 'MYCODE88',
          total_referred: 0,
          qualified_count: 0,
          points_earned: 0,
          referrals: [],
          referred_by: { has_referrer: true, referrer_name: 'Amigo Pro' },
        },
        error: null,
      })

    const { claimReferralCode, referredBy, claimSuccess } = useReferrals()
    const result = await claimReferralCode('AMIGO123')

    expect(result.success).toBe(true)
    expect(claimSuccess.value).toBe('¡Código vinculado con éxito!')
    expect(referredBy.value.has_referrer).toBe(true)
    expect(referredBy.value.referrer_name).toBe('Amigo Pro')
  })

  it('claimReferralCode validates empty input and handles errors', async () => {
    const { claimReferralCode, claimError } = useReferrals()

    const resEmpty = await claimReferralCode('')
    expect(resEmpty.success).toBe(false)
    expect(claimError.value).toBe('Ingresa un código de referido válido')

    mockRpc.mockRejectedValueOnce(new Error('No puedes utilizar tu propio código'))
    const resSelf = await claimReferralCode('MYOWN99')
    expect(resSelf.success).toBe(false)
    expect(claimError.value).toBe('No puedes utilizar tu propio código de referido')
  })
})
