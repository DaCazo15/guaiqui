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

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          client.navigate(targetUrl)
          return client.focus()
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl)
      }
    })
  )
})
