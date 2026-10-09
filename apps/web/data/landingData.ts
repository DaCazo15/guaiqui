export interface MatchInfo {
  opponent: string
  location: string
  date: string
  time: string
  isHome: boolean
  league: string
}

export interface CarouselSlide {
  id: string
  tag: string
  title: string
  subtitle: string
  ctaText: string
  ctaUrl: string
  bgGradient: string
  badgeVariant: 'primary' | 'accent' | 'perlita' | 'info'
}

export interface HowItWorksStep {
  step: number
  title: string
  description: string
  icon: string
}

export interface RewardItem {
  id: string
  name: string
  category: string
  perlitasCost: number
  stock: number
  badge: string
  imageBg: string
  icon?: string
}

export interface PlayerItem {
  id: string
  number: number
  name: string
  position: string
  height: string
  age: number
  nationality: string
  isStar?: boolean
}

export interface Milestone {
  year: string
  title: string
  description: string
}

export interface StaffMember {
  id: string
  name: string
  role: string
  category: 'directiva' | 'tecnico' | 'logistica'
}

export interface FaqItem {
  id: string
  title: string
  content: string
}

export const nextMatchData: MatchInfo = {
  opponent: 'Marinos de Anzoátegui',
  location: 'Gimnasio Ciudad de La Asunción, Nueva Esparta',
  date: 'Hoy, 07 de Octubre',
  time: '7:00 PM',
  isHome: true,
  league: 'Superliga Profesional de Baloncesto (SPB)',
}

export const carouselSlides: CarouselSlide[] = [
  {
    id: 'slide-1',
    tag: 'Próximo Partido',
    title: 'Clásico Oriental: Guaiqueríes vs. Marinos',
    subtitle: 'Responde la trivia del partido a las 6:45 PM y gana hasta 300 perlitas.',
    ctaText: 'Ver Detalles del Partido',
    ctaUrl: '#proximo-partido',
    bgGradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badgeVariant: 'accent',
  },
  {
    id: 'slide-2',
    tag: 'Premio Destacado',
    title: 'Camiseta Oficial Edición 80 Aniversario',
    subtitle: 'La verde de la tribu ya está disponible en la tienda de canje por 4.500 perlitas.',
    ctaText: 'Ir a la Tienda de Canje',
    ctaUrl: '#premios',
    bgGradient: 'from-amber-950 via-emerald-950 to-guaiqui-primary-dark',
    badgeVariant: 'perlita',
  },
  {
    id: 'slide-3',
    tag: 'Trivia Diaria',
    title: 'Desafío Histórico: ¿Quién anotó 42 puntos en 1991?',
    subtitle: 'Demuestra cuánto sabes de la tribu insular. 5 preguntas rápidas te esperan.',
    ctaText: 'Jugar Trivia Ahora',
    ctaUrl: '#como-funciona',
    bgGradient: 'from-guaiqui-primary-dark via-emerald-900 to-black',
    badgeVariant: 'primary',
  },
  {
    id: 'slide-4',
    tag: 'Comunidad Fanáticos',
    title: 'Entrenamiento Abierto a la Fanaticada',
    subtitle: 'Canjea un pase VIP para conocer al equipo este viernes en La Asunción.',
    ctaText: 'Canjear Pase VIP',
    ctaUrl: '#premios',
    bgGradient: 'from-teal-950 via-guaiqui-primary to-emerald-900',
    badgeVariant: 'info',
  },
]

export const howItWorksSteps: HowItWorksStep[] = [
  {
    step: 1,
    title: 'Regístrate Gratis',
    description: 'Crea tu cuenta de fanático con tu correo o número de cédula en menos de 1 minuto.',
    icon: 'user-plus',
  },
  {
    step: 2,
    title: 'Juega Trivias',
    description: 'Responde trivias diarias sobre la historia del club y predicciones de los partidos.',
    icon: 'trivia',
  },
  {
    step: 3,
    title: 'Acumula Perlitas',
    description: 'Tus aciertos se convierten automáticamente en perlitas en tu billetera digital inmutable.',
    icon: 'pearl',
  },
  {
    step: 4,
    title: 'Canjea Premios Reales',
    description: 'Canjea camisas, entradas, saludos personalizados de jugadores y sorteos exclusivos.',
    icon: 'gift',
  },
]

export const featuredRewards: RewardItem[] = [
  {
    id: 'prod-1',
    name: 'Camiseta Oficial Guaiqueríes 2026',
    category: 'Indumentaria',
    perlitasCost: 4500,
    stock: 15,
    badge: 'Popular',
    imageBg: 'from-emerald-700 via-green-800 to-emerald-950',
    icon: 'bi-bag-check-fill',
  },
  {
    id: 'prod-2',
    name: 'Bandana Verde Guaiquerí Original',
    category: 'Accesorios',
    perlitasCost: 1200,
    stock: 40,
    badge: 'Nuevo',
    imageBg: 'from-green-700 via-emerald-800 to-green-950',
    icon: 'bi-patch-check-fill',
  },
  {
    id: 'prod-3',
    name: 'Saludo en Video Personalizado de Jugador',
    category: 'Experiencia',
    perlitasCost: 2800,
    stock: 8,
    badge: 'Exclusivo',
    imageBg: 'from-amber-600 via-amber-700 to-amber-950',
    icon: 'bi-camera-video-fill',
  },
  {
    id: 'prod-4',
    name: 'Entrada Preferencial Abono 1 Partido',
    category: 'Entradas',
    perlitasCost: 3500,
    stock: 20,
    badge: 'Limitado',
    imageBg: 'from-rose-800 via-red-900 to-rose-950',
    icon: 'bi-ticket-perforated-fill',
  },
  {
    id: 'prod-5',
    name: 'Balón Oficial Autografiado por la Plantilla',
    category: 'Coleccionable',
    perlitasCost: 8500,
    stock: 3,
    badge: 'Colección',
    imageBg: 'from-teal-800 via-emerald-900 to-slate-900',
    icon: 'bi-dribbble',
  },
  {
    id: 'prod-6',
    name: 'Gorra Oficial de la Tribu Insular',
    category: 'Accesorios',
    perlitasCost: 1800,
    stock: 25,
    badge: 'Popular',
    imageBg: 'from-green-800 via-emerald-900 to-emerald-950',
    icon: 'bi-award-fill',
  },
]

export const teamStats = [
  { label: 'Años de Historia', value: '80+', note: 'Fundado en 1977 en Nueva Esparta' },
  { label: 'Campeonatos de Liga', value: '9', note: 'Orgullo del baloncesto venezolano' },
  { label: 'Fanáticos Registrados', value: '100K+', note: 'La tribu más fiel del país' },
  { label: 'Costo Real', value: '0$', note: 'Gratis. Todo es por fidelidad' },
]

export const keyRoster: PlayerItem[] = [
  { id: 'p-1', number: 10, name: 'Heissler Guillent', position: 'Base (PG)', height: '1.86 m', age: 37, nationality: 'Venezuela', isStar: true },
  { id: 'p-2', number: 14, name: 'Windi Graterol', position: 'Pívot (C)', height: '2.05 m', age: 38, nationality: 'Venezuela', isStar: true },
  { id: 'p-3', number: 7, name: 'Pedro Chourio', position: 'Escolta (SG)', height: '1.86 m', age: 34, nationality: 'Venezuela' },
  { id: 'p-4', number: 21, name: 'Edgar Martínez', position: 'Alero (SF)', height: '1.93 m', age: 27, nationality: 'Venezuela' },
  { id: 'p-5', number: 33, name: 'Alphonso Anderson', position: 'Ala-Pívot (PF)', height: '2.01 m', age: 26, nationality: 'EE.UU.' },
  { id: 'p-6', number: 3, name: 'Gary Browne', position: 'Base / Escolta', height: '1.85 m', age: 31, nationality: 'Puerto Rico' },
]

export const historyMilestones: Milestone[] = [
  {
    year: '1977',
    title: 'Fundación del Club',
    description: 'Nace Guaiqueríes de Margarita en La Asunción, representando la identidad de Nueva Esparta en la Liga Especial.',
  },
  {
    year: '1978 - 1982',
    title: 'La Era del Pentacampeonato',
    description: 'Hito histórico sin precedentes al conquistar 5 títulos consecutivos de liga con una racha mítica.',
  },
  {
    year: '1997',
    title: 'Séptima Corona Nacional',
    description: 'Victoria inolvidable en la final ante Cocodrilos de Caracas con el gimnasio lleno a reventar.',
  },
  {
    year: '2021',
    title: 'Campeones de la Superliga',
    description: 'Retorno a la gloria nacional alzando la copa en el torneo nacional de baloncesto profesional.',
  },
  {
    year: '2026',
    title: 'Plataforma Digital Fan Zone',
    description: 'Lanzamiento oficial de la app de fidelización con economía inmutable de perlitas para los fanáticos.',
  },
]

export const staffMembers: StaffMember[] = [
  { id: 's-1', name: 'Yvan García', role: 'Director Técnico (Head Coach)', category: 'tecnico' },
  { id: 's-2', name: 'Alexander Vargas', role: 'Asistente Técnico Principal', category: 'tecnico' },
  { id: 's-3', name: 'Dr. Roberto Marcano', role: 'Médico del Equipo', category: 'tecnico' },
  { id: 's-4', name: 'Monomacuto', role: 'Mascota Oficial de la Tribu', category: 'logistica' },
  { id: 's-5', name: 'Junta Directiva Guaiqueríes', role: 'Dirección General del Club', category: 'directiva' },
]

export const faqList: FaqItem[] = [
  {
    id: 'faq-1',
    title: '¿Qué son las Perlitas y cómo las obtengo?',
    content: 'Las perlitas son la moneda virtual oficial de fidelización de Guaiqueríes de Margarita. Se obtienen al acertar preguntas en las trivias diarias, registrar tu asistencia al gimnasio y completar desafíos de la tribu.',
  },
  {
    id: 'faq-2',
    title: '¿Cuesta dinero real participar o descargar la app?',
    content: 'No, absolutamente no. La plataforma es 100% gratuita. No se vende boletos ni se compran perlitas con dinero real.',
  },
  {
    id: 'faq-3',
    title: '¿Cómo reclamo los premios que canjee con mis perlitas?',
    content: 'Al realizar un canje en la app se generará un código QR único en tu billetera digital. Presenta este código QR al staff autorizado en el Gimnasio Ciudad de La Asunción para su escaneo y entrega inmediata.',
  },
  {
    id: 'faq-4',
    title: '¿Qué sucede si se agota el stock de un producto?',
    content: 'El inventario se renueva periódicamente antes de cada serie de partidos locales. Si un producto se agota, puedes guardar tus perlitas para la siguiente reposición.',
  },
  {
    id: 'faq-5',
    title: '¿Puedo perder mis perlitas con el tiempo?',
    content: 'No. Tus perlitas nunca expiran ni se eliminan. El libro contable digital del club es inmutable y seguro.',
  },
  {
    id: 'faq-6',
    title: '¿Puedo transferir perlitas a otro usuario o amigo?',
    content: 'Por razones de seguridad y equidad en el ranking, las perlitas son personales e intransferibles asociadas a tu cuenta de fanático.',
  },
  {
    id: 'faq-7',
    title: '¿A qué hora se publican las trivias del partido?',
    content: 'Las trivias de partido abren 1 hora antes del salto entre dos y cierran al inicio del encuentro. También hay trivias diarias activas durante la semana.',
  },
  {
    id: 'faq-8',
    title: '¿Cómo me contacto con soporte si tengo algún inconveniente?',
    content: 'Puedes escribirnos directamente a fan@guaiqueriesdemargarita.com o acudir al módulo de atención al fanático en el gimnasio durante los días de juego.',
  },
]
