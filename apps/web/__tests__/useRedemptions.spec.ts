/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })
const mockRpc = vi.fn()
const mockSelect = vi.fn()

const mockSupabase = {
  from: vi.fn((table: string) => {
    if (table === 'redemptions') {
      return {
        select: vi.fn(() => ({
          order: vi.fn().mockResolvedValue({
            data: [
              {
                id: 'red-1',
                fan_id: 'test-fan-uuid',
                product_id: 'prod-1',
                variant: 'M',
                cost_pearls: 100,
                status: 'pending',
                code_hash: 'hash1',
                created_at: '2026-10-10T12:00:00Z',
                products: { name: 'Camiseta Oficial', category: 'Indumentaria', images: [] },
              },
            ],
            error: null,
          }),
          eq: vi.fn((field: string, val: string) => ({
            single: vi.fn().mockResolvedValue({
              data: {
                id: val,
                fan_id: 'test-fan-uuid',
                product_id: 'prod-1',
                variant: 'M',
                cost_pearls: 100,
                status: 'approved',
                code_hash: 'hash1',
                created_at: '2026-10-10T12:00:00Z',
                products: { name: 'Camiseta Oficial', category: 'Indumentaria', images: [] },
              },
              error: null,
            }),
          })),
        })),
      }
    }
    if (table === 'redemption_history') {
      return {
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            order: vi.fn().mockResolvedValue({
              data: [
                {
                  id: 'hist-1',
                  redemption_id: 'red-1',
                  previous_status: 'pending',
                  new_status: 'approved',
                  changed_by: 'staff-1',
                  note: 'Aprobado',
                  created_at: '2026-10-10T13:00:00Z',
                },
              ],
              error: null,
            }),
          })),
        })),
      }
    }
    return {
      select: mockSelect,
    }
  }),
  rpc: mockRpc,
}

;(globalThis as any).useSupabaseClient = () => mockSupabase
;(globalThis as any).useSupabaseUser = () => mockUser

import { useRedemptions } from '../composables/useRedemptions'

describe('useRedemptions composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('fetchMyRedemptions populates list from database', async () => {
    const { redemptions, fetchMyRedemptions, loading } = useRedemptions()
    await fetchMyRedemptions()

    expect(redemptions.value).toHaveLength(1)
    expect(redemptions.value[0].id).toBe('red-1')
    expect(redemptions.value[0].products?.name).toBe('Camiseta Oficial')
    expect(loading.value).toBe(false)
  })

  it('fetchRedemptionDetails loads item, history, and triggers QR for approved status', async () => {
    mockRpc.mockResolvedValueOnce({
      data: {
        redemption_id: 'red-1',
        code: 'QR-SECRET-CODE',
        status: 'approved',
        variant: 'M',
        cost_pearls: 100,
        expires_at: null,
      },
      error: null,
    })

    const { currentRedemption, redemptionHistory, qrData, fetchRedemptionDetails } = useRedemptions()
    const result = await fetchRedemptionDetails('red-1')

    expect(result?.id).toBe('red-1')
    expect(currentRedemption.value?.status).toBe('approved')
    expect(redemptionHistory.value).toHaveLength(1)
    expect(mockRpc).toHaveBeenCalledWith('get_redemption_qr', { p_redemption_id: 'red-1' })
    expect(qrData.value?.code).toBe('QR-SECRET-CODE')
  })

  it('redeemProduct handles INSUFFICIENT_PERLITAS friendly error', async () => {
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'P0001: INSUFFICIENT_PERLITAS' },
    })

    const { redeemProduct, error } = useRedemptions()
    const res = await redeemProduct('prod-1', 'M', 'idem-key-1')

    expect(res.success).toBe(false)
    expect(res.error).toBe('No tienes suficientes perlitas para realizar este canje.')
    expect(error.value).toBe('No tienes suficientes perlitas para realizar este canje.')
  })

  it('redeemProduct handles OUT_OF_STOCK friendly error', async () => {
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'OUT_OF_STOCK' },
    })

    const { redeemProduct, error } = useRedemptions()
    const res = await redeemProduct('prod-1', 'M', 'idem-key-2')

    expect(res.success).toBe(false)
    expect(res.error).toBe('Este producto se encuentra temporalmente agotado.')
    expect(error.value).toBe('Este producto se encuentra temporalmente agotado.')
  })

  it('cancelRedemption calls cancel_redemption RPC and reloads details', async () => {
    mockRpc
      .mockResolvedValueOnce({ data: { success: true }, error: null }) // cancel_redemption
      .mockResolvedValueOnce({ data: null, error: null }) // get_redemption_qr on reload

    const { cancelRedemption } = useRedemptions()
    const res = await cancelRedemption('red-1', 'Ya no lo deseo')

    expect(mockRpc).toHaveBeenCalledWith('cancel_redemption', {
      p_redemption_id: 'red-1',
      p_reason: 'Ya no lo deseo',
    })
    expect(res.success).toBe(true)
  })
})
