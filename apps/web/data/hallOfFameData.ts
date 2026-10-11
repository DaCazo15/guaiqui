export interface RetiredJersey {
  number: number
  name: string
  nickname: string
  position: string
  years: string
  titlesCount: number
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
    name: 'José Ramos',
    nickname: 'Cheíto',
    position: 'Alero / Escolta',
    years: '1977 - 1986',
    titlesCount: 6,
    highlight: 'Pilar defensivo del hexacampeonato insular',
    description: 'Uno de los guerreros fundacionales de la época dorada en La Asunción. Entregó corazón y garra en cada posesión defensiva.',
    badgeIcon: 'bi-shield-fill-check',
  },
  {
    number: 8,
    name: 'Luis Lairet',
    nickname: 'El Eterno Capitán',
    position: 'Base / Escolta',
    years: '1977 - 1988',
    titlesCount: 6,
    highlight: 'Líder indiscutible y capitán de los 6 títulos consecutivos',
    description: 'El alma y la voz de mando en la cancha durante el legendario hexacampeonato (1977-1982). Ídolo perpetuo de la fanaticada margariteña.',
    badgeIcon: 'bi-star-fill',
  },
  {
    number: 11,
    name: 'Armando Becker',
    nickname: 'El Tanque',
    position: 'Ala-Pívot',
    years: '1980 - 1993',
    titlesCount: 3,
    highlight: 'Dominio físico en la pintura y reboteador implacable',
    description: 'Fuerza descomunal en los tableros. Protagonista de memorables batallas campales en el Gimnasio de La Asunción.',
    badgeIcon: 'bi-lightning-charge-fill',
  },
  {
    number: 12,
    name: 'Ronnie Thompkins',
    nickname: 'La Máquina',
    position: 'Pívot',
    years: '1988 - 1998',
    titlesCount: 1,
    highlight: 'Uno de los extranjeros más dominantes en la historia de la liga',
    description: 'Letal en el uno contra uno y anotador temido en toda Venezuela. Dejó una huella imborrable en el corazón de la Tribu Verde.',
    badgeIcon: 'bi-trophy-fill',
  },
  {
    number: 13,
    name: 'Carl Herrera',
    nickname: 'El Amuleto',
    position: 'Ala-Pívot',
    years: '1999 - 2007',
    titlesCount: 1,
    highlight: 'Primer venezolano campeón en la NBA (Houston Rockets)',
    description: 'Pionero absoluto del baloncesto nacional. Regresó a Venezuela para consagrarse campeón y dejar su jerarquía eterna con Guaiqueríes.',
    badgeIcon: 'bi-award-fill',
  },
  {
    number: 17,
    name: 'Richard Medina',
    nickname: 'El Halcón',
    position: 'Alero',
    years: '1989 - 2003',
    titlesCount: 1,
    highlight: 'Tirador certero y pieza clave del campeonato de 1997',
    description: 'Elegancia y precisión perimetral en los momentos de mayor presión. Más de una década defendiendo la camiseta con orgullo insular.',
    badgeIcon: 'bi-bullseye',
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
