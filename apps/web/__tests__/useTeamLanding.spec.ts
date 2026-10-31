/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'

const mockRpc = vi.fn()

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc
})

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
    })
  }
})()

Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  writable: true
})

import { useTeamLanding } from '../composables/useTeamLanding'

describe('useTeamLanding', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorageMock.clear()
  })

  it('retorna error cuando no se pasa un identificador', async () => {
    const { fetchTeamLanding, error } = useTeamLanding()
    const res = await fetchTeamLanding('')
    expect(res).toBeNull()
    expect(error.value).toBe('Identificador no proporcionado')
  })

  it('maneja caso de equipo no encontrado', async () => {
    mockRpc.mockResolvedValueOnce({
      data: { found: false, error: 'Equipo no encontrado o inactivo.' },
      error: null
    })

    const { fetchTeamLanding, team, error } = useTeamLanding()
    const res = await fetchTeamLanding('inexistente')

    expect(res).toBeNull()
    expect(team.value).toBeNull()
    expect(error.value).toBe('Equipo no encontrado o inactivo.')
  })

  it('carga exitosamente la landing y guarda equipo activo en localStorage', async () => {
    const mockTeamPayload = {
      found: true,
      team: {
        id: 'team-uuid-1',
        name: 'Guaiqueríes de Margarita',
        slug: 'guaiqueries',
        subdomain: 'guaiqueries',
        primary_color: '#005A36',
        secondary_color: '#E31B23',
        status: 'active'
      },
      announcement: { id: 'ann-1', message: '¡Partido hoy a las 7pm!' },
      hero_slides: [],
      roster_preview: [
        { id: 'p-1', first_name: 'José', last_name: 'Ascanio', jersey_number: 14, position: 'Alero' }
      ],
      trivias_preview: [],
      products_preview: [],
      milestones: [],
      faqs: []
    }

    mockRpc.mockResolvedValueOnce({
      data: mockTeamPayload,
      error: null
    })

    const { fetchTeamLanding, team, rosterPreview, announcement } = useTeamLanding()
    const res = await fetchTeamLanding('guaiqueries')

    expect(mockRpc).toHaveBeenCalledWith('get_team_landing_data', { p_identifier: 'guaiqueries' })
    expect(res?.found).toBe(true)
    expect(team.value?.name).toBe('Guaiqueríes de Margarita')
    expect(rosterPreview.value.length).toBe(1)
    expect(announcement.value?.message).toBe('¡Partido hoy a las 7pm!')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('guaiqui_active_team_slug', 'guaiqueries')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('guaiqui_active_team_id', 'team-uuid-1')
  })
})
