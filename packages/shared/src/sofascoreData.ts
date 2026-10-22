/**
 * Datos y tipos oficiales de Sofascore para Guaiqueríes de Margarita
 * Sofascore Team ID: 248672
 * URL: https://www.sofascore.com/es/basketball/team/guaiqueries-de-margarita/248672
 */

export interface SofascorePlayer {
  id?: string
  name: string
  jersey_number: number
  position: string
  height?: string
  age?: number
  birth_date?: string
  nationality: string
  is_active: boolean
  is_star: boolean
  bio?: string
}

export interface SofascoreGame {
  id?: string
  opponent: string
  location: string
  game_date: string
  is_home: boolean
  status: 'scheduled' | 'live' | 'finished' | 'cancelled'
  our_score: number
  opponent_score: number
  tournament?: string
  round?: string
}

export interface SofascoreTeamInfo {
  sofascore_id: number
  name: string
  sport: string
  gender: string
  arena: {
    name: string
    capacity: number
    city: string
    state: string
    country: string
  }
  tournament: string
  logo_url: string
  average_age: string
}

export const SOFASCORE_TEAM_INFO: SofascoreTeamInfo = {
  sofascore_id: 248672,
  name: 'Guaiqueríes de Margarita',
  sport: 'Baloncesto',
  gender: 'Masculino',
  arena: {
    name: 'Gimnasio Ciudad de La Asunción',
    capacity: 8500,
    city: 'La Asunción',
    state: 'Nueva Esparta',
    country: 'Venezuela'
  },
  tournament: 'SuperLiga Profesional de Baloncesto (SPB)',
  logo_url: 'https://img.sofascore.com/api/v1/team/248672/image',
  average_age: '31.3 años'
}

/**
 * Plantilla oficial de Guaiqueríes de Margarita (vacía por defecto, gestionada exclusivamente desde Supabase / Admin)
 */
export const SOFASCORE_OFFICIAL_ROSTER: SofascorePlayer[] = []

/**
 * Calendario y partidos oficiales SPB (vacío por defecto, gestionado exclusivamente desde Supabase / Admin)
 */
export const SOFASCORE_OFFICIAL_GAMES: SofascoreGame[] = []
