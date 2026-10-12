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
 * Plantilla oficial de Guaiqueríes de Margarita sincronizada desde Sofascore
 */
export const SOFASCORE_OFFICIAL_ROSTER: SofascorePlayer[] = [
  {
    name: 'Pedro Chourio',
    jersey_number: 7,
    position: 'Escolta / Alero (SG/SF)',
    height: '1.86 m',
    age: 34,
    birth_date: '1990-03-13',
    nationality: 'Venezuela',
    is_active: true,
    is_star: true,
    bio: 'Capitán y referente perimetral de Guaiqueríes y la selección nacional de Venezuela.'
  },
  {
    name: 'Heissler Guillent',
    jersey_number: 10,
    position: 'Base (PG)',
    height: '1.86 m',
    age: 37,
    birth_date: '1986-12-17',
    nationality: 'Venezuela',
    is_active: true,
    is_star: true,
    bio: 'El Sastre. Director de orquesta legendario del baloncesto venezolano y conductor de la tribu.'
  },
  {
    name: 'Windi Graterol',
    jersey_number: 14,
    position: 'Pívot (C)',
    height: '2.05 m',
    age: 38,
    birth_date: '1986-09-10',
    nationality: 'Venezuela',
    is_active: true,
    is_star: true,
    bio: 'Muralla defensiva en la pintura y campeón insular de la SPB.'
  },
  {
    name: 'Juan Guerrero',
    jersey_number: 2,
    position: 'Ala-Pívot (PF)',
    height: '2.05 m',
    age: 31,
    birth_date: '1993-07-08',
    nationality: 'República Dominicana',
    is_active: true,
    is_star: true,
    bio: 'Potencia ofensiva y reboteadora en la pintura para Guaiqueríes.'
  },
  {
    name: 'Tavario Miller',
    jersey_number: 0,
    position: 'Pívot (C)',
    height: '2.03 m',
    age: 30,
    birth_date: '1994-02-26',
    nationality: 'Bahamas',
    is_active: true,
    is_star: true,
    bio: 'Pívot atlético con gran capacidad de bloqueo y finalización sobre el aro.'
  },
  {
    name: 'Nahziah Carter',
    jersey_number: 1,
    position: 'Alero (SF)',
    height: '1.98 m',
    age: 25,
    birth_date: '1999-08-24',
    nationality: 'Estados Unidos',
    is_active: true,
    is_star: false,
    bio: 'Alero estadounidense de gran agilidad y capacidad de tiro perimetral.'
  },
  {
    name: 'Francisco Centeno',
    jersey_number: 12,
    position: 'Ala-Pívot (PF)',
    height: '2.03 m',
    age: 39,
    birth_date: '1985-05-26',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Veterano guerrero del tabloncillo margariteño con amplia trayectoria en la liga.'
  },
  {
    name: 'Tulio Cobos',
    jersey_number: 6,
    position: 'Ala-Pívot (PF)',
    height: '1.98 m',
    age: 38,
    birth_date: '1986-10-11',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Fuerza física y experiencia en los tableros.'
  },
  {
    name: 'Gary McGhee',
    jersey_number: 11,
    position: 'Pívot (C)',
    height: '2.11 m',
    age: 36,
    birth_date: '1988-10-28',
    nationality: 'Estados Unidos',
    is_active: true,
    is_star: false,
    bio: 'Centro dominante con experiencia internacional en ligas de Europa y América.'
  },
  {
    name: 'José Sojo',
    jersey_number: 5,
    position: 'Base (PG)',
    height: '1.82 m',
    age: 28,
    birth_date: '1996-01-30',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Velocidad, visión de cancha y conducción táctica de la segunda unidad.'
  },
  {
    name: 'Kender Urbina',
    jersey_number: 3,
    position: 'Base (PG)',
    height: '1.80 m',
    age: 20,
    birth_date: '2004-12-11',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Joven talento con tremenda explosividad y descaro ofensivo.'
  },
  {
    name: 'Gendry Correa',
    jersey_number: 8,
    position: 'Escolta (SG)',
    height: '1.91 m',
    age: 28,
    birth_date: '1996-01-09',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Especialista perimetral y gran defensor perimetral de la tribu.'
  },
  {
    name: 'Jose Bracho',
    jersey_number: 9,
    position: 'Base / Escolta (PG/SG)',
    height: '1.90 m',
    age: 26,
    birth_date: '1998-11-19',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Versatilidad ofensiva y control de ritmo en la cancha.'
  },
  {
    name: 'Hector Diaz',
    jersey_number: 13,
    position: 'Alero (SF)',
    height: '1.92 m',
    age: 32,
    birth_date: '1992-11-23',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Alero sólido con buen tiro de media y larga distancia.'
  },
  {
    name: 'Eliezer Montano',
    jersey_number: 23,
    position: 'Pívot (C)',
    height: '2.06 m',
    age: 33,
    birth_date: '1991-10-21',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Envergadura y protección del aro en el poste bajo.'
  },
  {
    name: 'Ezequiel Garcia',
    jersey_number: 15,
    position: 'Alero (SF)',
    height: '1.95 m',
    age: 19,
    birth_date: '2005-07-01',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Promesa insular de desarrollo de la cantera de Guaiqueríes.'
  },
  {
    name: 'Jhon Brito',
    jersey_number: 4,
    position: 'Base (PG)',
    height: '1.85 m',
    age: 23,
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Base rápido y dinámico con gran presión de balón.'
  },
  {
    name: 'Valentine Garcia',
    jersey_number: 17,
    position: 'Alero (SF)',
    height: '1.93 m',
    age: 22,
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Intensidad física y versatilidad en los aleros.'
  },
  {
    name: 'Luis Valera',
    jersey_number: 24,
    position: 'Ala-Pívot (PF)',
    height: '2.02 m',
    age: 36,
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Experiencia y tiro exterior desde la posición de ala-pívot.'
  },
  {
    name: 'Jerime Anderson',
    jersey_number: 16,
    position: 'Base (PG)',
    height: '1.88 m',
    age: 35,
    nationality: 'Estados Unidos',
    is_active: true,
    is_star: false,
    bio: 'Base armador internacional con gran capacidad de creación de juego.'
  },
  {
    name: 'Miguel Ruiz',
    jersey_number: 25,
    position: 'Ala-Pívot / Pívot (PF/C)',
    height: '2.02 m',
    age: 34,
    nationality: 'Venezuela',
    is_active: true,
    is_star: true,
    bio: 'El rey del rebote. Guerrero incansable bajo los aros y miembro de la Selección Nacional.'
  },
  {
    name: 'Ali Mata',
    jersey_number: 33,
    position: 'Pívot (C)',
    height: '2.05 m',
    age: 27,
    birth_date: '1997-12-27',
    nationality: 'Venezuela',
    is_active: true,
    is_star: false,
    bio: 'Pívot de relevo con presencia física en el tablero.'
  }
]

/**
 * Calendario y partidos oficiales SPB sincronizados de Sofascore
 */
export const SOFASCORE_OFFICIAL_GAMES: SofascoreGame[] = [
  // Partidos Recientes / Final SPB
  {
    opponent: 'Marinos de Anzoátegui',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: '2026-09-18T19:30:00Z',
    is_home: true,
    status: 'finished',
    our_score: 81,
    opponent_score: 78,
    tournament: 'Final SPB — Juego 4',
    round: 'Final'
  },
  {
    opponent: 'Marinos de Anzoátegui',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: '2026-09-16T19:30:00Z',
    is_home: true,
    status: 'finished',
    our_score: 75,
    opponent_score: 72,
    tournament: 'Final SPB — Juego 3',
    round: 'Final'
  },
  {
    opponent: 'Marinos de Anzoátegui',
    location: 'Gimnasio Luis Ramos, Puerto La Cruz',
    game_date: '2026-09-13T19:00:00Z',
    is_home: false,
    status: 'finished',
    our_score: 79,
    opponent_score: 84,
    tournament: 'Final SPB — Juego 2',
    round: 'Final'
  },
  {
    opponent: 'Marinos de Anzoátegui',
    location: 'Gimnasio Luis Ramos, Puerto La Cruz',
    game_date: '2026-09-11T19:00:00Z',
    is_home: false,
    status: 'finished',
    our_score: 74,
    opponent_score: 69,
    tournament: 'Final SPB — Juego 1',
    round: 'Final'
  },
  {
    opponent: 'Cocodrilos de Caracas',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: '2026-09-05T19:30:00Z',
    is_home: true,
    status: 'finished',
    our_score: 87,
    opponent_score: 82,
    tournament: 'Semifinal SPB — Juego 5',
    round: 'Semifinal'
  },
  // Próximos Partidos
  {
    opponent: 'Marinos de Anzoátegui',
    location: 'Gimnasio Luis Ramos, Puerto La Cruz',
    game_date: '2026-10-15T19:30:00Z',
    is_home: false,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0,
    tournament: 'Final SPB — Juego 5',
    round: 'Final'
  },
  {
    opponent: 'Gladiadores de Anzoátegui',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: '2026-10-22T19:30:00Z',
    is_home: true,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0,
    tournament: 'SuperLiga Profesional de Baloncesto',
    round: 'Jornada Regular'
  },
  {
    opponent: 'Trotamundos de Carabobo',
    location: 'Forum de Valencia, Valencia',
    game_date: '2026-10-28T19:00:00Z',
    is_home: false,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0,
    tournament: 'SuperLiga Profesional de Baloncesto',
    round: 'Jornada Regular'
  },
  {
    opponent: 'Cocodrilos de Caracas',
    location: 'Gimnasio Ciudad de La Asunción',
    game_date: '2026-11-04T19:30:00Z',
    is_home: true,
    status: 'scheduled',
    our_score: 0,
    opponent_score: 0,
    tournament: 'SuperLiga Profesional de Baloncesto',
    round: 'Jornada Regular'
  }
]
