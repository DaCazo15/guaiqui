/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { usePendingGrants } from '../composables/usePendingGrants'

describe('usePendingGrants composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with empty grants and calculates zero pending pearls', () => {
    const { grants, totalPendingPearls, loading, claiming, error } = usePendingGrants()
    expect(grants.value).toEqual([])
    expect(totalPendingPearls.value).toBe(0)
    expect(loading.value).toBe(false)
    expect(claiming.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('fetchPendingGrants loads pending grants and computes totalPendingPearls', async () => {
    const mockGrants = [
      {
        id: 'grant-1',
        source: 'ads_block',
        amount: 10,
        status: 'pending',
        expires_at: null,
        created_at: '2026-10-30T10:00:00Z',
        days_remaining: null,
      },
      {
        id: 'grant-2',
        source: 'referral_signup',
        amount: 5,
        status: 'pending',
        expires_at: '2027-01-30T10:00:00Z',
        created_at: '2026-10-30T10:00:00Z',
        days_remaining: 90,
      },
    ]
    mockRpc.mockResolvedValueOnce({ data: mockGrants, error: null })

    const { grants, totalPendingPearls, fetchPendingGrants, error } = usePendingGrants()
    await fetchPendingGrants()

    expect(mockRpc).toHaveBeenCalledWith('get_pending_pearl_grants')
    expect(grants.value).toHaveLength(2)
    expect(totalPendingPearls.value).toBe(15)
    expect(error.value).toBeNull()
  })

  it('claimGrant calls RPC and removes grant from active list on success', async () => {
    const mockGrants = [
      {
        id: 'grant-1',
        source: 'ads_block',
        amount: 10,
        status: 'pending',
        expires_at: null,
        created_at: '2026-10-30T10:00:00Z',
        days_remaining: null,
      },
    ]
    mockRpc.mockResolvedValueOnce({ data: mockGrants, error: null })

    const { grants, fetchPendingGrants, claimGrant } = usePendingGrants()
    await fetchPendingGrants()
    expect(grants.value).toHaveLength(1)

    mockRpc.mockResolvedValueOnce({
      data: { success: true, grant_id: 'grant-1', team_id: 'team-alpha', amount: 10 },
      error: null,
    })

    const result = await claimGrant('grant-1', 'team-alpha')
    expect(result).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('claim_pending_grant', {
      p_grant_id: 'grant-1',
      p_team_id: 'team-alpha',
    })
    expect(grants.value).toHaveLength(0)
  })

  it('claimGrant sets error when RPC fails', async () => {
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'Debes seguir al equipo para asignarle las perlitas.' },
    })

    const { claimGrant, error } = usePendingGrants()
    const result = await claimGrant('grant-1', 'team-unfollowed')

    expect(result).toBe(false)
    expect(error.value).toBe('Debes seguir al equipo para asignarle las perlitas.')
  })
})
