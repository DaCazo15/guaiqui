export interface RetiredJersey {
  number: number
  name: string
  nickname: string
  position: string
  years: string
  titlesCount: number
  titlesBadge?: string
  highlight: string
  description: string
  badgeIcon: string
}

export interface LegendFigure {
  id: string
  name: string
  nickname: string
  role: 'player' | 'coach' | 'historic'
  category: 'gold_era' | 'modern_era' | 'builder'
  era: string
  position?: string
  titles: string[]
  achievements: string[]
  bio: string
  image_url: string
}

export interface ChampionshipTitle {
  year: number
  tournament: string
  runnerUp: string
  highlight: string
  isHexa: boolean
}

export const retiredJerseys: RetiredJersey[] = [
  {
    number: 5,
    name: 'Luis Lairet',
    nickname: 'Pilar Fundacional',
    position: 'Alero',
    years: '1977 - 1982',
    titlesCount: 6,
    titlesBadge: '6 títulos',
    highlight: 'Pieza vital en los 6 campeonatos consecutivos (1977-1982)',
    description: 'Uno de los pilares fundacionales de la franquicia y pieza vital en la histórica hazaña de los 6 campeonatos consecutivos entre 1977 y 1982.',
    badgeIcon: 'bi-star-fill',
  },
  {
    number: 13,
    name: 'Cruz Lairet',
    nickname: 'Anotador Implacable',
    position: 'Ala-Pívot',
    years: '1977 - 1982',
    titlesCount: 6,
    titlesBadge: '6 títulos',
    highlight: 'Referente histórico del hexacampeonato original de la Tribu',
    description: 'Hermano de Luis, anotador implacable y otro gran referente histórico del hexacampeonato original de la Tribu.',
    badgeIcon: 'bi-fire',
  },
  {
    number: 12,
    name: 'Luis Sosa',
    nickname: 'Muralla Insular',
    position: 'Pívot',
    years: '1977 - 1985',
    titlesCount: 6,
    titlesBadge: '6 títulos',
    highlight: 'Gran centro defensivo de la época dorada de los 70 y 80',
    description: 'El gran centro defensivo de la época dorada de los 70 y 80. Su número también está retirado por Marinos como muestra de su tremenda huella en el país.',
    badgeIcon: 'bi-shield-fill-check',
  },
  {
    number: 8,
    name: 'Álexander Quiroz',
    nickname: 'Chocolate',
    position: 'Base',
    years: '1991 - 2009',
    titlesCount: 1,
    titlesBadge: '2017',
    highlight: '19 temporadas, líder en asistencias y capitán en el título de 1997',
    description: 'Defendió la camiseta verde durante 19 temporadas (1991-2009). Líder en asistencias, velocidad y capitán en el título obtenido en la temporada de 1997. Retirado en 2017.',
    badgeIcon: 'bi-lightning-charge-fill',
  },
  {
    number: 17,
    name: 'Richard Medina',
    nickname: 'Pundonor Verde',
    position: 'Ala-Pívot',
    years: '1990 - 2001',
    titlesCount: 1,
    titlesBadge: '2017',
    highlight: '11 temporadas consecutivas y figura clave para alzar el título de 1997',
    description: 'Jugó 11 temporadas consecutivas en Margarita con un pundonor inolvidable. Fue una de las figuras criollas clave para alzar el campeonato de 1997. Retirado en 2017.',
    badgeIcon: 'bi-bullseye',
  },
  {
    number: 11,
    name: 'Carl Herrera',
    nickname: 'Héroe de Portland',
    position: 'Ala-Pívot',
    years: '2003 - 2004',
    titlesCount: 1,
    titlesBadge: '2017',
    highlight: 'Primer venezolano NBA y homenaje institucional en 2017',
    description: 'El histórico primer venezolano en la NBA y miembro de los "Héroes de Portland". Jugó con la Tribu en las temporadas 2003 y 2004; la directiva retiró su número en 2017 como homenaje institucional a su gigantesca leyenda.',
    badgeIcon: 'bi-award-fill',
  },
]

export const legendaryFigures: LegendFigure[] = [
  {
    id: 'sam-shepherd',
    name: 'Sam Shepherd',
    nickname: 'El Mago de La Asunción',
    role: 'player',
    category: 'gold_era',
    era: '1977 - 1985',
    position: 'Base Armador',
    titles: ['1977', '1978', '1979', '1980', '1981', '1982'],
    achievements: ['Base del Hexacampeonato', 'Líder histórico en asistencias', 'Nacionalizado venezolano'],
    bio: 'El arquitecto ofensivo que hizo soñar a toda Margarita. Su visión de juego y control del ritmo marcaron la época más gloriosa del baloncesto en Venezuela.',
    image_url: '/images/historia/san-shepherd.png',
  },
  {
    id: 'palito-quiroz',
    name: 'Alexander Quiroz',
    nickname: 'Palito',
    role: 'player',
    category: 'modern_era',
    era: '1995 - 2008',
    position: 'Base Armador',
    titles: ['1997', '2007'],
    achievements: ['Bicampeón LPB', 'Capitán de la era moderna', 'Más de 500 juegos con la franquicia'],
    bio: 'Orgullo de Nueva Esparta y referente insular. Guió a la Tribu a reconquistar la gloria en las finales de 1997 y 2007.',
    image_url: '/images/historia/alexander-quiroz.jpg',
  },
  {
    id: 'askia-jones',
    name: 'Askia Jones',
    nickname: 'El Francotirador',
    role: 'player',
    category: 'modern_era',
    era: '1996 - 2001',
    position: 'Escolta',
    titles: ['1997'],
    achievements: ['MVP de la Final 1997', 'Récord de triples en postemporada', 'Ex-jugador NBA (Timberwolves)'],
    bio: 'Anotador prolífico con puntería legendaria. Encestó triples decisivos para sellar la séptima estrella del equipo ante Cocodrilos.',
    image_url: '/images/historia/askia-jones.jpg',
  },
  {
    id: 'paco-diez',
    name: 'Francisco Díez',
    nickname: 'Paco',
    role: 'coach',
    category: 'builder',
    era: '1977 - 1983',
    titles: ['1977', '1978', '1979', '1980', '1981', '1982'],
    achievements: ['Estratega del Hexacampeonato', 'Leyenda del banquillo'],
    bio: 'El maestro táctico detrás de la dinastía más imponente en la historia del deporte venezolano. Forjó el carácter guerrero de la Tribu.',
    image_url: '/images/historia/francisco.jpg',
  },
  {
    id: 'julio-toro',
    name: 'Julio Toro',
    nickname: 'El Sabio de Puerto Rico',
    role: 'coach',
    category: 'builder',
    era: '1997',
    titles: ['1997'],
    achievements: ['Campeón LPB 1997', 'Entrenador mundialista'],
    bio: 'Con su temperamento ganador y mística caribeña, llevó a Guaiqueríes a levantar el trofeo en 1997 terminando una sequía de quince años.',
    image_url: '/images/historia/julio-toro.jpg',
  },
  {
    id: 'heissler-guillent',
    name: 'Heissler Guillent',
    nickname: 'El Sastre',
    role: 'player',
    category: 'modern_era',
    era: '2021 - 2023',
    position: 'Base Armador',
    titles: ['2021 (Copa Superliga)'],
    achievements: ['MVP Copa Superliga 2021', 'Base de la Selección Nacional'],
    bio: 'Comandó la conquista de la Copa Superliga 2021 con actuaciones magistrales en el Gimnasio Ciudad de La Asunción.',
    image_url: '/images/historia/heissler-guillent.jpg',
  },
]

export const championshipsList: ChampionshipTitle[] = [
  { year: 1977, tournament: 'Liga Especial (Li-Es)', runnerUp: 'A bravejos de Yaracuy', highlight: 'Primer campeonato de la franquicia y nacimiento de la Tribu Verde.', isHexa: true },
  { year: 1978, tournament: 'Liga Especial (Li-Es)', runnerUp: 'Panteras del Táchira', highlight: 'Consolidación del dominio insular con barrida en la serie final.', isHexa: true },
  { year: 1979, tournament: 'Liga Especial (Li-Es)', runnerUp: 'Legisladores de Carabobo', highlight: 'Tricampeonato consecutivo con La Asunción convertida en fortín inexpugnable.', isHexa: true },
  { year: 1980, tournament: 'Liga Especial (Li-Es)', runnerUp: 'Retadores de Caracas', highlight: 'Cuarta estrella consecutiva de la mano de Lairet y Cheíto Ramos.', isHexa: true },
  { year: 1981, tournament: 'Liga Especial (Li-Es)', runnerUp: 'Telefonistas de Caracas', highlight: 'El pentacampeonato que asombró a toda Sudamérica.', isHexa: true },
  { year: 1982, tournament: 'Liga Especial (Li-Es)', runnerUp: 'Panteras de Lara', highlight: 'Récord histórico insuperable: ¡6 campeonatos consecutivos seguidos!', isHexa: true },
  { year: 1997, tournament: 'Liga Profesional (LPB)', runnerUp: 'Cocodrilos de Caracas', highlight: 'Regreso a la gloria tras 15 años de la mano de Julio Toro y Askia Jones.', isHexa: false },
  { year: 2007, tournament: 'Liga Profesional (LPB)', runnerUp: 'Cocodrilos de Caracas', highlight: 'Octava corona en una vibrante serie a 7 juegos decidida en El Fortín.', isHexa: false },
  { year: 2021, tournament: 'Copa Superliga de Baloncesto', runnerUp: 'Trotamundos de Carabobo', highlight: 'Novena estrella nacional con Heissler Guillent alzando la copa en casa.', isHexa: false },
]
