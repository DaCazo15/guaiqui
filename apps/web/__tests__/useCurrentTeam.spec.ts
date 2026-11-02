/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockUser = ref<{ id: string } | null>({ id: 'fan-test-uuid' })
const mockSelect = vi.fn()
const mockFrom = vi.fn((_table: string): any => ({
  select: mockSelect,
}))

const mockRouterPush = vi.fn()
const mockRpc = vi.fn().mockResolvedValue({ data: null, error: null })

;(globalThis as any).useSupabaseClient = () => ({
  from: mockFrom,
  rpc: mockRpc,
  auth: {
    getSession: vi.fn().mockResolvedValue({ data: { session: null } }),
  },
})
;(globalThis as any).useSupabaseUser = () => mockUser
;(globalThis as any).useRouter = () => ({
  push: mockRouterPush,
})
;(globalThis as any).navigateTo = vi.fn()

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = value.toString()
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key]
    }),
    clear: vi.fn(() => {
      store = {}
    }),
  }
})()

Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  writable: true,
})

import { useCurrentTeam } from '../composables/useCurrentTeam'

describe('useCurrentTeam composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorageMock.clear()
    mockUser.value = { id: 'fan-test-uuid' }
  })

  it('initializes with default values and opens/closes picker', () => {
    const { isPickerOpen, pickerTargetSection, openPicker, closePicker } = useCurrentTeam()

    expect(isPickerOpen.value).toBe(false)
    expect(pickerTargetSection.value).toBe('trivias')

    openPicker('tienda')
    expect(isPickerOpen.value).toBe(true)
    expect(pickerTargetSection.value).toBe('tienda')

    closePicker()
    expect(isPickerOpen.value).toBe(false)
  })

  it('selectTeam updates localStorage, closes picker and pushes route', () => {
    const { selectTeam, isPickerOpen, openPicker } = useCurrentTeam()

    openPicker('trivias')
    expect(isPickerOpen.value).toBe(true)

    selectTeam('marinos', 'trivias')

    expect(localStorageMock.setItem).toHaveBeenCalledWith('guaiqui_active_team_slug', 'marinos')
    expect(isPickerOpen.value).toBe(false)
    expect(mockRouterPush).toHaveBeenCalledWith('/app/e/marinos/trivias')
  })

  it('selectTeam routes to hub when target is hub', () => {
    const { selectTeam } = useCurrentTeam()

    selectTeam('guaiqueries', 'hub')

    expect(localStorageMock.setItem).toHaveBeenCalledWith('guaiqui_active_team_slug', 'guaiqueries')
    expect(mockRouterPush).toHaveBeenCalledWith('/app/e/guaiqueries')
  })

  it('fetchFollowedTeams handles unauthenticated user gracefully', async () => {
    mockUser.value = null
    const { fetchFollowedTeams, followedTeams } = useCurrentTeam()

    await fetchFollowedTeams()
    expect(followedTeams.value).toHaveLength(0)
  })

  it('fetchFollowedTeams maps get_wallet_summary payload fields correctly', async () => {
    mockUser.value = { id: 'fan-test-uuid' }
    mockRpc.mockResolvedValueOnce({
      data: {
        total_balance: 475,
        teams: [
          {
            team_id: 'a0000000-0000-0000-0000-000000000001',
            name: 'Guaiqueríes de Margarita',
            slug: 'guaiqueries',
            short_name: 'La Tribu',
            logo_url: '/logo.png',
            primary_color: '#005A36',
            secondary_color: '#E31B23',
            status: 'active',
            balance: 475,
            held_pearls: 0,
            is_following: true,
          },
        ],
      },
      error: null,
    })

    const { fetchFollowedTeams, followedTeams } = useCurrentTeam()
    const result = await fetchFollowedTeams()

    expect(result).toHaveLength(1)
    expect(result[0].name).toBe('Guaiqueríes de Margarita')
    expect(result[0].slug).toBe('guaiqueries')
    expect(result[0].short_name).toBe('La Tribu')
    expect(result[0].logo_url).toBe('/logo.png')
    expect(result[0].balance).toBe(475)
    expect(result[0].is_following).toBe(true)
    expect(followedTeams.value).toHaveLength(1)
  })

  it('loadTeamBySlug loads team details and persists slug', async () => {
    const mockTeamData = {
      id: 'team-trotamundos',
      name: 'Trotamundos de Carabobo',
      slug: 'trotamundos',
      short_name: 'Expreso Azul',
      logo_url: '/trotamundos.png',
      status: 'active',
    }

    const makeChainable = (table: string) => {
      const obj: any = {}
      obj.select = vi.fn(() => obj)
      obj.eq = vi.fn(() => obj)
      obj.maybeSingle = vi.fn().mockImplementation(() => {
        if (table === 'teams') {
          return Promise.resolve({ data: mockTeamData, error: null })
        }
        return Promise.resolve({ data: null, error: null })
      })
      return obj
    }

    mockFrom.mockImplementation((table: string) => makeChainable(table))

    const { loadTeamBySlug, activeTeam } = useCurrentTeam()
    const result = await loadTeamBySlug('trotamundos')

    expect(result?.slug).toBe('trotamundos')
    expect(activeTeam.value?.name).toBe('Trotamundos de Carabobo')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('guaiqui_active_team_slug', 'trotamundos')
  })

  it('handles localStorage throwing security or quota exceptions gracefully', () => {
    const faultyStorage = {
      getItem: vi.fn(() => {
        throw new Error('Access denied to localStorage')
      }),
      setItem: vi.fn(() => {
        throw new Error('Quota exceeded')
      }),
      removeItem: vi.fn(),
      clear: vi.fn(),
    }
    Object.defineProperty(globalThis, 'localStorage', {
      value: faultyStorage,
      writable: true,
    })

    const { selectTeam } = useCurrentTeam()

    // Should not throw
    expect(() => selectTeam('equipo-1', 'trivias')).not.toThrow()
    expect(mockRouterPush).toHaveBeenCalledWith('/app/e/equipo-1/trivias')
  })
})
