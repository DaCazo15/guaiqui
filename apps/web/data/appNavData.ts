export interface AppNavItem {
  name: string
  routeName: string
  path: string
  icon: string
  badge?: string
}

export const APP_SIDEBAR_NAV_ITEMS: AppNavItem[] = [
  { name: 'Inicio', routeName: 'app', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Perfil', routeName: 'app-perfil', path: '/app/perfil', icon: 'bi-person-fill' },
  { name: 'Notificaciones', routeName: 'app-notificaciones', path: '/app/notificaciones', icon: 'bi-bell-fill' },
  { name: 'Equipos', routeName: 'app-equipos', path: '/app/equipos', icon: 'bi-shield-shaded' },
  { name: 'Buscador FanActivo', routeName: 'app-usuarios', path: '/app/usuarios', icon: 'bi-search' },
  { name: 'Billetera', routeName: 'app-billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Referidos', routeName: 'app-referidos', path: '/app/referidos', icon: 'bi-people' },
  { name: 'Trivias', routeName: 'app-trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Ranking', routeName: 'app-ranking', path: '/app/ranking', icon: 'bi-trophy-fill' },
  { name: 'Tienda', routeName: 'app-tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Canjes', routeName: 'app-canjes', path: '/app/canjes', icon: 'bi-gift-fill' },
  { name: 'Anuncios', routeName: 'app-anuncios', path: '/app/anuncios', icon: 'bi-play-btn-fill' },
  { name: 'Ajustes', routeName: 'app-ajustes', path: '/app/ajustes', icon: 'bi-gear-fill' },
]

export const APP_BOTTOM_NAV_ITEMS: AppNavItem[] = [
  { name: 'Inicio', routeName: 'app', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', routeName: 'app-trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Billetera', routeName: 'app-billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', routeName: 'app-tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Perfil', routeName: 'app-perfil', path: '/app/perfil', icon: 'bi-person-fill' },
]
