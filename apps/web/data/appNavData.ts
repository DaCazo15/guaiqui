export interface AppNavItem {
  name: string
  routeName: string
  path: string
  icon: string
  badge?: string
}

export const APP_SIDEBAR_NAV_ITEMS: AppNavItem[] = [
  { name: 'Inicio', routeName: 'app', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Equipos', routeName: 'app-equipos', path: '/app/equipos', icon: 'bi-shield-shaded' },
  { name: 'Mi Perfil', routeName: 'app-perfil', path: '/app/perfil', icon: 'bi-person-fill' },
  { name: 'Billetera', routeName: 'app-billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Perlitas Pendientes', routeName: 'app-perlitas-pendientes', path: '/app/perlitas-pendientes', icon: 'bi-hourglass-split' },
  { name: 'Referidos', routeName: 'app-referidos', path: '/app/referidos', icon: 'bi-people' },
  { name: 'Trivias', routeName: 'app-trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Ranking', routeName: 'app-ranking', path: '/app/ranking', icon: 'bi-trophy-fill' },
  { name: 'Tienda', routeName: 'app-tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Mis Canjes', routeName: 'app-canjes', path: '/app/canjes', icon: 'bi-gift-fill' },
  { name: 'Ver Anuncios', routeName: 'app-anuncios', path: '/app/anuncios', icon: 'bi-play-btn-fill' },
  { name: 'Partidos', routeName: 'app-partidos', path: '/app/partidos', icon: 'bi-calendar-event-fill' },
  { name: 'Plantilla', routeName: 'app-plantilla', path: '/app/plantilla', icon: 'bi-people-fill' },
  { name: 'Salón de la Fama', routeName: 'app-salon-de-la-fama', path: '/app/salon-de-la-fama', icon: 'bi-award-fill' },
  { name: 'Ajustes', routeName: 'app-ajustes', path: '/app/ajustes', icon: 'bi-gear-fill' },
]

export const APP_BOTTOM_NAV_ITEMS: AppNavItem[] = [
  { name: 'Inicio', routeName: 'app', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', routeName: 'app-trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Billetera', routeName: 'app-billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', routeName: 'app-tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Perfil', routeName: 'app-perfil', path: '/app/perfil', icon: 'bi-person-fill' },
]
