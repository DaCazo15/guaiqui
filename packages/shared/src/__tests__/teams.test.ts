import { describe, it, expect } from 'vitest'
import {
  DEFAULT_TEAM_SLUG,
  DEFAULT_TEAM_ID,
  isValidTeamSlug,
  type Team,
  type TeamPublic,
  type TeamStatus,
} from '../index'

describe('Multi-tenant Team Validations and Constants', () => {
  it('defines default official team constants for Guaiqueríes de Margarita', () => {
    expect(DEFAULT_TEAM_SLUG).toBe('guaiqueries')
    expect(DEFAULT_TEAM_ID).toBe('a0000000-0000-0000-0000-000000000001')
  })

  it('validates proper team slugs matching Postgres CHECK constraint', () => {
    expect(isValidTeamSlug('guaiqueries')).toBe(true)
    expect(isValidTeamSlug('la-tribu-1977')).toBe(true)
    expect(isValidTeamSlug('team2')).toBe(true)
    expect(isValidTeamSlug('ab')).toBe(true)
  })

  it('rejects invalid team slugs violating format or length', () => {
    // Too short (< 2)
    expect(isValidTeamSlug('a')).toBe(false)
    expect(isValidTeamSlug('')).toBe(false)

    // Too long (> 50)
    expect(isValidTeamSlug('a'.repeat(51))).toBe(false)

    // Uppercase
    expect(isValidTeamSlug('Guaiqueries')).toBe(false)
    expect(isValidTeamSlug('GUAIQUI')).toBe(false)

    // Spaces
    expect(isValidTeamSlug('guaiqueries bbc')).toBe(false)

    // Special characters
    expect(isValidTeamSlug('guaiqueries_bbc')).toBe(false)
    expect(isValidTeamSlug('team@margarita')).toBe(false)
    expect(isValidTeamSlug('la.tribu')).toBe(false)
  })

  it('verifies Team and TeamPublic TypeScript type compatibility', () => {
    const status: TeamStatus = 'active'
    const fullTeam: Team = {
      id: DEFAULT_TEAM_ID,
      name: 'Guaiqueríes de Margarita',
      slug: DEFAULT_TEAM_SLUG,
      short_name: 'La Tribu',
      logo_url: 'https://example.com/logo.png',
      primary_color: '#005A36',
      secondary_color: '#E31B23',
      status,
      joined_at: '1977-03-01T00:00:00Z',
      paid_until: '2099-12-31T23:59:59Z',
      created_at: '2026-10-28T00:00:00Z',
      updated_at: '2026-10-28T00:00:00Z',
    }

    const publicTeam: TeamPublic = {
      id: fullTeam.id,
      name: fullTeam.name,
      slug: fullTeam.slug,
      short_name: fullTeam.short_name,
      logo_url: fullTeam.logo_url,
      primary_color: fullTeam.primary_color,
      secondary_color: fullTeam.secondary_color,
      status: fullTeam.status,
      joined_at: fullTeam.joined_at,
    }

    expect(publicTeam.slug).toBe('guaiqueries')
    expect(publicTeam.status).toBe('active')
    // paid_until should NOT be in TeamPublic
    expect('paid_until' in publicTeam).toBe(false)
  })
})
