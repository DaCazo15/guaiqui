import type { RouterConfig } from '@nuxt/schema'

export default <RouterConfig>{
  scrollBehavior(to, from, savedPosition) {
    // 1. Restaurar posición guardada por el historial del navegador (atrás / adelante)
    if (savedPosition) {
      return savedPosition
    }

    // 2. Si la navegación tiene un hash (#seccion), desplazarse suavemente
    if (to.hash) {
      return {
        el: to.hash,
        behavior: 'smooth',
      }
    }

    // 3. Si la navegación ocurre entre pestañas del mismo equipo (/app/e/:slug/*)
    // mantenemos la posición del scroll actual para evitar que la página salte al tope
    const isSameTeamHub =
      to.path.startsWith('/app/e/') &&
      from.path.startsWith('/app/e/')

    if (isSameTeamHub) {
      const toParts = to.path.split('/')
      const fromParts = from.path.split('/')
      // toParts: ['', 'app', 'e', slug, ...]
      if (toParts[3] && fromParts[3] && toParts[3] === fromParts[3]) {
        return false // Mantener la posición de scroll actual
      }
    }

    // 4. Si la ruta base es la misma y solo cambiaron parámetros de búsqueda (query)
    if (to.path === from.path) {
      return false
    }

    // 5. Para cualquier otra navegación entre páginas distintas, ir al inicio
    return { top: 0 }
  },
}
