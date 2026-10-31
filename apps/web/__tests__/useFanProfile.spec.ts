/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { useFanProfile } from '../composables/useFanProfile'

describe('useFanProfile composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with default values', () => {
    const { profile, stats, level, badges, teamsFollowed, loading, error } = useFanProfile()
    expect(profile.value).toBeNull()
    expect(stats.value.total_pearls).toBe(0)
    expect(level.value.tier_name).toBe('Fan Novato')
    expect(badges.value).toEqual([])
    expect(teamsFollowed.value).toEqual([])
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('fetchProfileEnriched loads enriched fan data correctly', async () => {
    const mockProfileData = {
      found: true,
      profile: {
        id: 'test-fan-uuid',
        display_name: 'Fanatico Insular',
        avatar_url: null,
      },
      stats: {
        total_pearls: 650,
        trivias_count: 5,
        redemptions_count: 1,
        streak_days: 8,
      },
      level: {
        tier_name: 'Fan Devoto',
        tier_icon: 'bi-shield-fill-check',
        current_xp: 650,
        next_threshold: 2000,
        progress_percent: 10.0,
      },
      badges: [
        {
          id: 'b-1',
          slug: 'fan_fiel',
          name: 'Corazón de la Tribu',
          description: 'Sigue a su equipo oficial',
          icon_name: 'bi-shield-fill-check',
          category: 'fidelidad',
          tier: 'bronce',
          criteria_summary: 'Sigue al menos a un equipo oficial',
          is_unlocked: true,
          awarded_at: '2026-10-25T10:00:00Z',
        },
        {
          id: 'b-2',
          slug: 'experto_trivia',
          name: 'Sabio del Tabloncillo',
          description: 'Acumuló más de 50 perlitas en trivias',
          icon_name: 'bi-mortarboard-fill',
          category: 'trivias',
          tier: 'oro',
          criteria_summary: 'Gana más de 50 perlitas en trivias',
          is_unlocked: false,
          awarded_at: null,
        },
      ],
      teams: [
        {
          team_id: 'team-1',
          name: 'Guaiqueríes de Margarita',
          slug: 'guaiqueries',
          balance_cache: 400,
          followed_at: '2026-10-20T10:00:00Z',
        },
      ],
    }

    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { profile, stats, level, badges, teamsFollowed, unlockedBadgesCount, fetchProfileEnriched, error } = useFanProfile()
    await fetchProfileEnriched()

    expect(mockRpc).toHaveBeenCalledWith('get_fan_profile_enriched', { p_fan_id: 'test-fan-uuid' })
    expect(profile.value?.display_name).toBe('Fanatico Insular')
    expect(stats.value.total_pearls).toBe(650)
    expect(level.value.tier_name).toBe('Fan Devoto')
    expect(badges.value).toHaveLength(2)
    expect(unlockedBadgesCount.value).toBe(1)
    expect(teamsFollowed.value).toHaveLength(1)
    expect(error.value).toBeNull()
  })

  it('handles profile not found error', async () => {
    mockRpc.mockResolvedValueOnce({
      data: { found: false, error: 'Perfil no encontrado' },
      error: null,
    })

    const { fetchProfileEnriched, error, profile } = useFanProfile()
    const res = await fetchProfileEnriched()

    expect(res).toBeNull()
    expect(profile.value).toBeNull()
    expect(error.value).toBe('Perfil no disponible')
  })
})
