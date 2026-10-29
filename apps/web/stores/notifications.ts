import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export interface NotificationItem {
  id: string
  team_id?: string | null
  user_id: string
  type: string
  title: string
  body: string
  data: Record<string, any>
  dedup_key: string
  read_at: string | null
  created_at: string
  team?: {
    id: string
    name: string
    slug: string
    logo_url: string | null
  } | null
}

export const useNotificationsStore = defineStore('notifications', () => {
  const notifications = ref<NotificationItem[]>([])
  const isLoading = ref(false)
  const pushPermission = ref<NotificationPermission>('default')
  const isSubscribed = ref(false)
  const realtimeChannel = ref<any>(null)

  const unreadCount = computed(() => notifications.value.filter((n) => !n.read_at).length)

  const checkPermissionState = () => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      pushPermission.value = Notification.permission
    }
  }

  const fetchNotifications = async () => {
    const supabase = useSupabaseClient()
    const user = useSupabaseUser()
    if (!user.value || !user.value.id) return

    isLoading.value = true
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select(`
          *,
          team:teams (
            id,
            name,
            slug,
            logo_url
          )
        `)
        .eq('user_id', user.value.id)
        .order('created_at', { ascending: false })

      if (!error && data) {
        notifications.value = data as unknown as NotificationItem[]
      }
    } finally {
      isLoading.value = false
    }
  }

  const subscribeToRealtime = () => {
    const supabase = useSupabaseClient()
    const user = useSupabaseUser()
    if (!user.value || !user.value.id || realtimeChannel.value) return

    realtimeChannel.value = supabase
      .channel('user-notifications')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.value.id}`,
        },
        (payload) => {
          const newNotif = payload.new as NotificationItem
          notifications.value.unshift(newNotif)
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.value.id}`,
        },
        (payload) => {
          const updated = payload.new as NotificationItem
          const idx = notifications.value.findIndex((n) => n.id === updated.id)
          if (idx !== -1) {
            notifications.value[idx] = updated
          }
        }
      )
      .subscribe()
  }

  const unsubscribeRealtime = () => {
    if (realtimeChannel.value) {
      const supabase = useSupabaseClient()
      supabase.removeChannel(realtimeChannel.value)
      realtimeChannel.value = null
    }
  }

  const markAsRead = async (id: string) => {
    const supabase = useSupabaseClient()
    const target = notifications.value.find((n) => n.id === id)
    if (target && !target.read_at) {
      target.read_at = new Date().toISOString()
      await supabase.rpc('mark_notification_read', { p_notification_id: id })
    }
  }

  const markAllAsRead = async () => {
    const supabase = useSupabaseClient()
    notifications.value.forEach((n) => {
      if (!n.read_at) n.read_at = new Date().toISOString()
    })
    await supabase.rpc('mark_all_notifications_read')
  }

  async function getSWRegistrationWithTimeout(timeoutMs = 2000): Promise<ServiceWorkerRegistration | null> {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return null
    try {
      const timeoutPromise = new Promise<null>((resolve) => setTimeout(() => resolve(null), timeoutMs))
      const regPromise = (async () => {
        const reg = await navigator.serviceWorker.getRegistration()
        return reg || null
      })()
      return await Promise.race([regPromise, timeoutPromise])
    } catch (_err) {
      return null
    }
  }

  const requestPushPermission = async () => {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      throw new Error('Las notificaciones no están soportadas en este navegador.')
    }

    const permission = await Notification.requestPermission()
    pushPermission.value = permission

    if (permission !== 'granted') {
      return false
    }

    if (!('serviceWorker' in navigator)) {
      return false
    }

    try {
      const registration = await getSWRegistrationWithTimeout(2000)
      if (!registration || !registration.pushManager) {
        console.warn('Service Worker registration not available for push.')
        return false
      }

      const vapidKey = (import.meta.env.VITE_VAPID_PUBLIC_KEY as string) || ''

      let subscription = await registration.pushManager.getSubscription()
      if (!subscription && vapidKey) {
        const convertedKey = urlBase64ToUint8Array(vapidKey)
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: convertedKey,
        })
      }

      if (subscription) {
        const jsonSub = subscription.toJSON()
        const supabase = useSupabaseClient()
        await supabase.rpc('register_push_subscription', {
          p_endpoint: subscription.endpoint,
          p_p256dh: jsonSub.keys?.p256dh || '',
          p_auth: jsonSub.keys?.auth || '',
          p_user_agent: navigator.userAgent,
        })
        isSubscribed.value = true
      }
      return true
    } catch (err: any) {
      console.warn('Push registration error:', err)
      return false
    }
  }

  const unregisterPush = async () => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return

    try {
      const registration = await getSWRegistrationWithTimeout(2000)
      if (registration && registration.pushManager) {
        const subscription = await registration.pushManager.getSubscription()
        if (subscription) {
          const supabase = useSupabaseClient()
          await Promise.resolve(supabase.rpc('unregister_push_subscription', { p_endpoint: subscription.endpoint })).catch(() => {})
          await subscription.unsubscribe().catch(() => {})
        }
      }
      isSubscribed.value = false
    } catch (err) {
      console.warn('Unregister push error:', err)
    }
  }

  const sendTestNotification = async () => {
    const supabase = useSupabaseClient()
    const user = useSupabaseUser()
    if (!user.value) return

    // Insert direct via RPC or edge function test trigger
    await supabase.rpc('mark_all_notifications_read')
  }

  return {
    notifications,
    unreadCount,
    isLoading,
    pushPermission,
    isSubscribed,
    checkPermissionState,
    fetchNotifications,
    subscribeToRealtime,
    unsubscribeRealtime,
    markAsRead,
    markAllAsRead,
    requestPushPermission,
    unregisterPush,
    sendTestNotification,
  }
})

function urlBase64ToUint8Array(base64String: string) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}
