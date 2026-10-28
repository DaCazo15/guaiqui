// Service Worker para PWA Guaiqueríes de Margarita — Fan Zone

self.addEventListener('push', (event) => {
  if (!event.data) return

  let payload = {
    title: 'Guaiqueríes de Margarita',
    body: 'Tienes una nueva notificación.',
    data: { url: '/app/notificaciones' },
  }

  try {
    const json = event.data.json()
    payload.title = json.title || payload.title
    payload.body = json.body || payload.body
    payload.data = json.data || payload.data
  } catch (_e) {
    payload.body = event.data.text() || payload.body
  }

  const options = {
    body: payload.body,
    icon: '/pwa-192x192.png',
    badge: '/pwa-192x192.png',
    data: payload.data,
    vibrate: [100, 50, 100],
  }

  event.waitUntil(self.registration.showNotification(payload.title, options))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const targetUrl = event.notification.data?.url || '/app/notificaciones'
  const fullTargetUrl = new URL(targetUrl, self.location.origin).href

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // 1. Buscar una ventana cuya URL ya coincida con targetUrl y enfocarla
      for (const client of clientList) {
        if (client.url === fullTargetUrl && 'focus' in client) {
          return client.focus()
        }
      }

      // 2. Si no existe, abrir una nueva ventana
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl)
      }

      // 3. Fallback: navegar la primera ventana abierta del origen y enfocarla
      for (const client of clientList) {
        if (client.url && 'navigate' in client && 'focus' in client) {
          client.navigate(targetUrl)
          return client.focus()
        }
      }
    })
  )
})
