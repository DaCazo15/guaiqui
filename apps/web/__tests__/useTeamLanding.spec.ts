/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })
const mockPush = vi.fn()
const mockRoute = { fullPath: '/e/guaiqueries', params: { slug: 'guaiqueries' } }

vi.mock('#imports', () => ({
  useSupabaseClient: () => ({
    rpc: mockRpc,
  }),
  useSupabaseUser: () => mockUser,
  useRoute: () => mockRoute,
  useRouter: () => ({
    push: mockPush,
  }),
}))

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser
;(globalThis as any).useRoute = () => mockRoute
;(globalThis as any).useRouter = () => ({
  push: mockPush,
})

import { useTeamLanding } from '../composables/useTeamLanding'

describe('useTeamLanding composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with default values', () => {
    const { landingData, loading, actionLoading, error, isNotFound, isInactive, isActive } = useTeamLanding()

    expect(landingData.value).toBeNull()
    expect(loading.value).toBe(false)
    expect(actionLoading.value).toBe(false)
    expect(error.value).toBeNull()
    expect(isNotFound.value).toBe(false)
    expect(isInactive.value).toBe(false)
    expect(isActive.value).toBe(false)
  })

  it('fetches active team landing and populates reactive state', async () => {
    const activePayload = {
      status: 'active' as const,
      team: {
        id: 't-1',
        name: 'Guaiqueríes de Margarita',
        slug: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active' as const
      },
      follower_count: 1420,
      is_following: true,
      content: {
        hero_title: 'Fan Zone Oficial Guaiqueríes',
        hero_subtitle: 'Tribu insular oficial',
        hero_image_url: null,
        sections: [],
        updated_at: '2026-11-01T00:00:00Z'
      },
      active_trivias: [],
      top_ranking: [],
      featured_products: []
    }

    mockRpc.mockResolvedValueOnce({ data: activePayload, error: null })

    const { landingData, isActive, isNotFound, isInactive, fetchTeamLanding } = useTeamLanding()
    await fetchTeamLanding('guaiqueries')

    expect(mockRpc).toHaveBeenCalledWith('get_team_landing', { p_slug: 'guaiqueries' })
    expect(landingData.value).toEqual(activePayload)
    expect(isActive.value).toBe(true)
    expect(isNotFound.value).toBe(false)
    expect(isInactive.value).toBe(false)
  })

  it('handles inactive team status correctly', async () => {
    const inactivePayload = {
      status: 'inactive' as const,
      team: {
        id: 't-2',
        name: 'Equipo Inactivo',
        slug: 'equipo-inactivo',
        status: 'inactive' as const
      }
    }

    mockRpc.mockResolvedValueOnce({ data: inactivePayload, error: null })

    const { landingData, isActive, isInactive, isNotFound, fetchTeamLanding } = useTeamLanding()
    await fetchTeamLanding('equipo-inactivo')

    expect(landingData.value?.status).toBe('inactive')
    expect(isInactive.value).toBe(true)
    expect(isActive.value).toBe(false)
    expect(isNotFound.value).toBe(false)
  })

  it('handles non-existent team as 404 not_found', async () => {
    const notFoundPayload = {
      status: 'not_found' as const,
      message: 'Equipo no encontrado'
    }

    mockRpc.mockResolvedValueOnce({ data: notFoundPayload, error: null })

    const { landingData, isNotFound, isActive, isInactive, fetchTeamLanding } = useTeamLanding()
    await fetchTeamLanding('slug-fantasma')

    expect(landingData.value?.status).toBe('not_found')
    expect(isNotFound.value).toBe(true)
    expect(isActive.value).toBe(false)
    expect(isInactive.value).toBe(false)
  })

  it('handles RPC error and falls back to not_found', async () => {
    mockRpc.mockResolvedValueOnce({ data: null, error: new Error('Error de conexión con la base de datos') })

    const { landingData, isNotFound, error, fetchTeamLanding } = useTeamLanding()
    await fetchTeamLanding('guaiqueries')

    expect(isNotFound.value).toBe(true)
    expect(error.value).toBe('Error de conexión con la base de datos')
    expect(landingData.value?.status).toBe('not_found')
  })

  it('redirects unauthenticated user to /login with return query and action on toggleFollow', async () => {
    mockUser.value = null // Guest

    const { landingData, toggleFollow } = useTeamLanding()
    landingData.value = {
      status: 'active',
      team: {
        id: 't-1',
        name: 'Guaiqueríes',
        slug: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active'
      },
      follower_count: 10,
      is_following: false
    }

    const result = await toggleFollow()

    expect(result).toEqual({ redirected: true })
    expect(mockPush).toHaveBeenCalledWith({
      path: '/login',
      query: {
        redirect: '/e/guaiqueries',
        action: 'follow',
        team_id: 't-1'
      }
    })
    expect(mockRpc).not.toHaveBeenCalled()
  })

  it('allows authenticated user to follow a team with optimistic update', async () => {
    mockUser.value = { id: 'test-fan-uuid' }
    mockRpc.mockResolvedValueOnce({ data: null, error: null })

    const { landingData, toggleFollow } = useTeamLanding()
    landingData.value = {
      status: 'active',
      team: {
        id: 't-1',
        name: 'Guaiqueríes',
        slug: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active'
      },
      follower_count: 50,
      is_following: false
    }

    const result = await toggleFollow()

    expect(mockRpc).toHaveBeenCalledWith('follow_team', { p_team_id: 't-1' })
    expect(result).toEqual({ redirected: false, following: true })
    expect(landingData.value.is_following).toBe(true)
    expect(landingData.value.follower_count).toBe(51)
  })

  it('allows authenticated user to unfollow a team with optimistic update', async () => {
    mockUser.value = { id: 'test-fan-uuid' }
    mockRpc.mockResolvedValueOnce({ data: null, error: null })

    const { landingData, toggleFollow } = useTeamLanding()
    landingData.value = {
      status: 'active',
      team: {
        id: 't-1',
        name: 'Guaiqueríes',
        slug: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active'
      },
      follower_count: 50,
      is_following: true
    }

    const result = await toggleFollow()

    expect(mockRpc).toHaveBeenCalledWith('unfollow_team', { p_team_id: 't-1' })
    expect(result).toEqual({ redirected: false, following: false })
    expect(landingData.value.is_following).toBe(false)
    expect(landingData.value.follower_count).toBe(49)
  })

  it('reverts optimistic updates when RPC fails', async () => {
    mockUser.value = { id: 'test-fan-uuid' }
    mockRpc.mockResolvedValueOnce({ data: null, error: new Error('Fallo de red') })

    const { landingData, toggleFollow, error } = useTeamLanding()
    landingData.value = {
      status: 'active',
      team: {
        id: 't-1',
        name: 'Guaiqueríes',
        slug: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active'
      },
      follower_count: 100,
      is_following: false
    }

    await expect(toggleFollow()).rejects.toThrow('Fallo de red')

    expect(landingData.value.is_following).toBe(false)
    expect(landingData.value.follower_count).toBe(100)
    expect(error.value).toBe('Fallo de red')
  })
})
