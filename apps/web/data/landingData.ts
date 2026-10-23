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


export const carouselSlides: CarouselSlide[] = [
  {
    id: 'slide-1',
    tag: 'Fan Zone 2026',
    title: 'Bienvenido a la Tribu Guaiquerí',
    subtitle: 'La plataforma oficial de fidelización del equipo nueve veces campeón de Venezuela.',
    ctaText: 'Únete a la Tribu',
    ctaUrl: '/registro',
    bgGradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badgeVariant: 'accent',
  },
  {
    id: 'slide-2',
    tag: 'Trivias Oficiales',
    title: 'Demuestra tu Conocimiento Insular',
    subtitle: 'Responde preguntas sobre la historia del club, estadísticas y partidos para acumular puntos.',
    ctaText: 'Ver Cómo Funciona',
    ctaUrl: '#como-funciona',
    bgGradient: 'from-guaiqui-primary-dark via-emerald-900 to-black',
    badgeVariant: 'primary',
  },
  {
    id: 'slide-3',
    tag: 'Premios y Experiencias',
    title: 'Canjea Premios Reales con tus Puntos',
    subtitle: 'Acumula puntos de fidelidad en tu billetera inmutable y canjéalos por artículos y experiencias.',
    ctaText: 'Conoce Más',
    ctaUrl: '#como-funciona',
    bgGradient: 'from-amber-950 via-emerald-950 to-guaiqui-primary-dark',
    badgeVariant: 'perlita',
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
    title: 'Acumula Puntos',
    description: 'Tus aciertos se convierten automáticamente en puntos en tu billetera digital inmutable.',
    icon: 'pearl',
  },
  {
    step: 4,
    title: 'Canjea Premios Reales',
    description: 'Canjea camisas, entradas, saludos personalizados de jugadores y sorteos exclusivos.',
    icon: 'gift',
  },
]

export const featuredRewards: RewardItem[] = []


export const teamStats = [
  { label: 'Años de Historia', value: '49', note: 'Fundado en 1977 en Nueva Esparta' },
  { label: 'Campeonatos de Liga', value: '9', note: 'Orgullo del baloncesto venezolano' },
  { label: 'Títulos Consecutivos', value: '5', note: 'Pentacampeón histórico (1978-1982)' },
  { label: 'Costo para el Fan', value: '$0', note: '100% fidelización por pasión' },
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
    description: 'Lanzamiento oficial de la app de fidelización con economía inmutable de puntos para los fanáticos.',
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
    title: '¿Qué son los Puntos y cómo los obtengo?',
    content: 'Los puntos son la moneda virtual oficial de fidelización de Guaiqueríes de Margarita. Se obtienen al acertar preguntas en las trivias diarias, registrar tu asistencia al gimnasio y completar desafíos de la tribu.',
  },
  {
    id: 'faq-2',
    title: '¿Cuesta dinero real participar o descargar la app?',
    content: 'No, absolutamente no. La plataforma es 100% gratuita. No se vende boletos ni se compran puntos con dinero real.',
  },
  {
    id: 'faq-3',
    title: '¿Cómo reclamo los premios que canjee con mis puntos?',
    content: 'Al realizar un canje en la app se generará un código QR único en tu billetera digital. Presenta este código QR al staff autorizado en el Gimnasio Ciudad de La Asunción para su escaneo y entrega inmediata.',
  },
  {
    id: 'faq-4',
    title: '¿Qué sucede si se agota el stock de un producto?',
    content: 'El inventario se renueva periódicamente antes de cada serie de partidos locales. Si un producto se agota, puedes guardar tus puntos para la siguiente reposición.',
  },
  {
    id: 'faq-5',
    title: '¿Puedo perder mis puntos con el tiempo?',
    content: 'No. Tus puntos nunca expiran ni se eliminan. El libro contable digital del club es inmutable y seguro.',
  },
  {
    id: 'faq-6',
    title: '¿Puedo transferir puntos a otro usuario o amigo?',
    content: 'Por razones de seguridad y equidad en el ranking, los puntos son personales e intransferibles asociados a tu cuenta de fanático.',
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
