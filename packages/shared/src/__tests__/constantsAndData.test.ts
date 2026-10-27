import { describe, it, expect } from 'vitest'
import {
  MUNICIPALITIES,
  GENDERS,
  SHIRT_SIZES,
  REFERRAL_SOURCES,
  CURRENT_LEGAL_VERSIONS,
} from '../constants'
import {
  SOFASCORE_TEAM_INFO,
  SOFASCORE_OFFICIAL_ROSTER,
  SOFASCORE_OFFICIAL_GAMES,
} from '../sofascoreData'

describe('constants', () => {
  it('contains valid Nueva Esparta municipalities', () => {
    expect(MUNICIPALITIES).toContain('Mariño')
    expect(MUNICIPALITIES).toContain('Maneiro')
    expect(MUNICIPALITIES).toContain('Arismendi')
    expect(MUNICIPALITIES.length).toBeGreaterThan(10)
  })

  it('contains expected genders and shirt sizes', () => {
    expect(GENDERS).toContain('Masculino')
    expect(GENDERS).toContain('Femenino')
    expect(SHIRT_SIZES).toEqual(['S', 'M', 'L', 'XL', '2XL', '3XL'])
    expect(REFERRAL_SOURCES).toContain('Redes sociales')
  })

  it('defines valid legal versions', () => {
    expect(CURRENT_LEGAL_VERSIONS.terms).toBe('1.0')
    expect(CURRENT_LEGAL_VERSIONS.privacy).toBe('1.0')
    expect(CURRENT_LEGAL_VERSIONS.pearls_rules).toBe('1.0')
  })
})

describe('sofascoreData', () => {
  it('contains official team info for Guaiqueríes de Margarita', () => {
    expect(SOFASCORE_TEAM_INFO.name).toBe('Guaiqueríes de Margarita')
    expect(SOFASCORE_TEAM_INFO.sofascore_id).toBe(248672)
    expect(SOFASCORE_TEAM_INFO.arena.name).toBe('Gimnasio Ciudad de La Asunción')
    expect(SOFASCORE_TEAM_INFO.arena.city).toBe('La Asunción')
    expect(SOFASCORE_TEAM_INFO.arena.state).toBe('Nueva Esparta')
    expect(SOFASCORE_TEAM_INFO.arena.country).toBe('Venezuela')
  })

  it('ensures zero hardcoded roster and games (managed from Supabase/admin)', () => {
    // According to AGENTS.md rule 9, no hardcoded fake roster or games
    expect(SOFASCORE_OFFICIAL_ROSTER).toEqual([])
    expect(SOFASCORE_OFFICIAL_GAMES).toEqual([])
  })
})
