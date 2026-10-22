/**
 * Guaiqueríes de Margarita — Session Cleanup Utility
 *
 * Realiza una limpieza defensiva y completa de la sesión del usuario en el navegador:
 * 1. Cierra sesión local en Supabase Auth (`scope: 'local'`).
 * 2. Desuscribe notificaciones Web Push en Service Worker con salvaguarda de timeout (2s).
 * 3. Purga selectivamente `localStorage` y `sessionStorage` eliminando tokens `sb-*` y `supabase`.
 * 4. Invalida y elimina cookies de autenticación residuales.
 */

export async function clearClientAuthSession(supabase: any): Promise<void> {
  // 1. Cierre de sesión local en Supabase
  try {
    if (supabase?.auth?.signOut) {
      await supabase.auth.signOut({ scope: 'local' }).catch((err: any) => console.warn('SignOut warning:', err))
    }
  } catch (err) {
    console.warn('SignOut error:', err)
  }

  // 2. Desuscripción de Service Worker Web Push con timeout de 2000 ms
  if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
    try {
      const timeoutPromise = new Promise<null>((resolve) => setTimeout(() => resolve(null), 2000))
      const pushCleanup = (async () => {
        const reg = await navigator.serviceWorker.getRegistration()
        if (reg && reg.pushManager) {
          const sub = await reg.pushManager.getSubscription()
          if (sub) {
            if (supabase?.rpc) {
              await Promise.resolve(
                supabase.rpc('unregister_push_subscription', { p_endpoint: sub.endpoint })
              ).catch(() => {})
            }
            await sub.unsubscribe().catch(() => {})
          }
        }
      })()
      await Promise.race([pushCleanup, timeoutPromise])
    } catch (_swErr) {
      // Ignorar errores no críticos en desuscripción push
    }
  }

  // 3. Limpieza de LocalStorage, SessionStorage y Cookies
  try {
    if (typeof window !== 'undefined') {
      const localKeysToRemove: string[] = []
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i)
        if (k && (k.startsWith('sb-') || k.includes('supabase'))) {
          localKeysToRemove.push(k)
        }
      }
      localKeysToRemove.forEach((k) => localStorage.removeItem(k))

      const sessionKeysToRemove: string[] = []
      for (let i = 0; i < sessionStorage.length; i++) {
        const k = sessionStorage.key(i)
        if (k && (k.startsWith('sb-') || k.includes('supabase'))) {
          sessionKeysToRemove.push(k)
        }
      }
      sessionKeysToRemove.forEach((k) => sessionStorage.removeItem(k))

      document.cookie.split(';').forEach((c) => {
        const eqPos = c.indexOf('=')
        const name = eqPos > -1 ? c.substring(0, eqPos).trim() : c.trim()
        if (
          name.startsWith('sb-') ||
          name.includes('supabase') ||
          name.includes('token') ||
          name.includes('auth')
        ) {
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${window.location.hostname};`
        }
      })
    }
  } catch (_clearErr) {
    // Ignorar errores de acceso a almacenamiento restringido
  }
}
