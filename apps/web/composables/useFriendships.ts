import { ref, computed } from 'vue'
import { useSupabaseClient } from '#imports'
import type {
  FriendItem,
  IncomingFriendRequest,
  OutgoingFriendRequest,
  FriendsSummary,
} from '@guaiqui/shared'

export function useFriendships() {
  const supabase = useSupabaseClient()

  const friends = ref<FriendItem[]>([])
  const incomingRequests = ref<IncomingFriendRequest[]>([])
  const outgoingRequests = ref<OutgoingFriendRequest[]>([])
  const loading = ref(false)
  const sending = ref(false)
  const responding = ref(false)
  const error = ref<string | null>(null)
  const success = ref<string | null>(null)

  const totalFriends = computed(() => friends.value.length)
  const pendingIncomingCount = computed(() => incomingRequests.value.length)

  function translateError(err: any): string {
    const msg = err?.message || String(err)
    if (msg.includes('CANNOT_FRIEND_SELF')) return 'No puedes enviarte una solicitud de amistad a ti mismo.'
    if (msg.includes('USER_NOT_FOUND')) return 'No encontramos ningún fanático activo con ese código o nombre.'
    if (msg.includes('ALREADY_FRIENDS')) return 'Ya tienes una amistad confirmada con este usuario.'
    if (msg.includes('REQUEST_ALREADY_SENT')) return 'Ya tienes una solicitud de amistad pendiente con este usuario.'
    if (msg.includes('NOT_AUTHENTICATED')) return 'Debes iniciar sesión para gestionar amigos.'
    if (msg.includes('TARGET_REQUIRED')) return 'Por favor ingresa un código o nombre de usuario válido.'
    if (msg.includes('CANNOT_SEND_REQUEST')) return 'No es posible enviar una solicitud a este usuario en este momento.'
    return 'Ocurrió un error al procesar la solicitud. Intenta nuevamente.'
  }

  async function fetchFriendships() {
    loading.value = true
    error.value = null
    try {
      const { data, error: err } = await supabase.rpc('get_my_friends_and_requests')
      if (err) throw err

      const summary = data as unknown as FriendsSummary
      friends.value = summary?.friends || []
      incomingRequests.value = summary?.incoming_requests || []
      outgoingRequests.value = summary?.outgoing_requests || []
    } catch (err: any) {
      error.value = translateError(err)
    } finally {
      loading.value = false
    }
  }

  async function sendFriendRequest(target: string): Promise<{ success: boolean; message: string }> {
    sending.value = true
    error.value = null
    success.value = null
    try {
      const { data, error: err } = await supabase.rpc('send_friend_request', {
        p_target: target.trim(),
      })
      if (err) throw err

      const res = data as any
      const msg = res?.message || 'Solicitud de amistad enviada exitosamente.'
      success.value = msg
      await fetchFriendships()
      return { success: true, message: msg }
    } catch (err: any) {
      const msg = translateError(err)
      error.value = msg
      return { success: false, message: msg }
    } finally {
      sending.value = false
    }
  }

  async function acceptRequest(friendshipId: string): Promise<boolean> {
    responding.value = true
    error.value = null
    try {
      const { error: err } = await supabase.rpc('respond_friend_request', {
        p_friendship_id: friendshipId,
        p_action: 'accepted',
      })
      if (err) throw err

      await fetchFriendships()
      return true
    } catch (err: any) {
      error.value = translateError(err)
      return false
    } finally {
      responding.value = false
    }
  }

  async function declineRequest(friendshipId: string): Promise<boolean> {
    responding.value = true
    error.value = null
    try {
      const { error: err } = await supabase.rpc('respond_friend_request', {
        p_friendship_id: friendshipId,
        p_action: 'declined',
      })
      if (err) throw err

      await fetchFriendships()
      return true
    } catch (err: any) {
      error.value = translateError(err)
      return false
    } finally {
      responding.value = false
    }
  }

  async function removeFriend(friendshipId: string): Promise<boolean> {
    responding.value = true
    error.value = null
    try {
      const { error: err } = await supabase.rpc('remove_friend', {
        p_friendship_id: friendshipId,
      })
      if (err) throw err

      await fetchFriendships()
      return true
    } catch (err: any) {
      error.value = translateError(err)
      return false
    } finally {
      responding.value = false
    }
  }

  return {
    friends,
    incomingRequests,
    outgoingRequests,
    totalFriends,
    pendingIncomingCount,
    loading,
    sending,
    responding,
    error,
    success,
    fetchFriendships,
    sendFriendRequest,
    acceptRequest,
    declineRequest,
    removeFriend,
  }
}
