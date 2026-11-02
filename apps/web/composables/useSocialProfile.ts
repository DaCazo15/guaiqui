import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import type {
  PublicUserProfile,
  FollowRequestItem,
  BlockedUserItem,
  UserFollowUserItem,
  UserSearchResultItem,
} from '@guaiqui/shared'

function formatSocialError(err: any, fallback: string): string {
  if (!err) return fallback
  const msg = err.message || (typeof err === 'string' ? err : '')
  if (/schema cache/i.test(msg) || /function .* does not exist/i.test(msg) || /permission denied/i.test(msg)) {
    return 'El servicio se está sincronizando o requiere iniciar sesión. Por favor, recarga la página.'
  }
  if (/JWT expired/i.test(msg) || /not authenticated/i.test(msg) || /No autenticado/i.test(msg)) {
    return 'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.'
  }
  if (/Failed to fetch/i.test(msg) || /NetworkError/i.test(msg)) {
    return 'Error de conexión. Revisa tu conexión a internet.'
  }
  return msg || fallback
}

export const useSocialProfile = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const currentProfile = ref<PublicUserProfile | null>(null)
  const loadingProfile = ref(false)
  const searchResults = ref<UserSearchResultItem[]>([])
  const searching = ref(false)
  const followRequests = ref<FollowRequestItem[]>([])
  const loadingRequests = ref(false)
  const blockedUsers = ref<BlockedUserItem[]>([])
  const loadingBlocked = ref(false)
  const followersList = ref<UserFollowUserItem[]>([])
  const followingList = ref<UserFollowUserItem[]>([])
  const loadingList = ref(false)
  const actionLoadingId = ref<string | null>(null)
  const error = ref<string | null>(null)
  const successMessage = ref<string | null>(null)

  const clearMessages = () => {
    error.value = null
    successMessage.value = null
  }

  const fetchPublicProfile = async (userId: string): Promise<PublicUserProfile | null> => {
    if (!userId) return null
    loadingProfile.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('get_public_profile', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      currentProfile.value = data as PublicUserProfile
      return currentProfile.value
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cargar perfil')
      currentProfile.value = null
      return null
    } finally {
      loadingProfile.value = false
    }
  }

  const sendFollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoadingId.value = userId
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('send_follow_request', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      const res = data as any
      const resultingStatus = (res?.status === 'accepted' ? 'accepted' : 'pending') as FollowRelationStatus

      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = resultingStatus
        if (resultingStatus === 'accepted') {
          currentProfile.value.is_full_profile = true
          currentProfile.value.followers_count = (currentProfile.value.followers_count || 0) + 1
        }
      }

      const item = searchResults.value.find((u) => u.id === userId)
      if (item) {
        item.relation_status = resultingStatus
      }

      if (resultingStatus === 'pending') {
        successMessage.value = 'Solicitud de seguimiento enviada con éxito.'
      }
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al enviar solicitud de seguimiento')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const respondRequest = async (followerId: string, accept: boolean): Promise<boolean> => {
    if (!user.value || !followerId) return false
    actionLoadingId.value = followerId
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('respond_follow_request', {
        p_follower_id: followerId,
        p_accept: accept,
      })
      if (rpcError) throw rpcError
      // Remove from pending follow requests locally
      followRequests.value = followRequests.value.filter((req) => req.follower_id !== followerId)
      if (currentProfile.value && currentProfile.value.id === followerId) {
        currentProfile.value.relation_status = accept ? 'accepted' : 'none'
        if (accept) {
          currentProfile.value.followers_count += 1
        }
      }
      successMessage.value = accept ? 'Solicitud aceptada.' : 'Solicitud rechazada.'
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al responder solicitud')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const cancelFollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoadingId.value = userId
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('cancel_follow_request', {
        p_user_id: userId,
      })
      if (rpcError) {
        // Fallback defensivo: si no había pendiente porque ya estaba aceptada la relación, desenlazar via unfollow_user
        const { error: unfollowErr } = await supabase.rpc('unfollow_user', {
          p_user_id: userId,
        })
        if (unfollowErr) throw rpcError
      }
      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = 'none'
      }
      const item = searchResults.value.find((u) => u.id === userId)
      if (item) {
        item.relation_status = 'none'
      }
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cancelar solicitud')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const unfollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoadingId.value = userId
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('unfollow_user', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = 'none'
        currentProfile.value.is_full_profile = false
        currentProfile.value.followers_count = Math.max(0, currentProfile.value.followers_count - 1)
        currentProfile.value.ranking = null
        currentProfile.value.redemptions_count = null
        currentProfile.value.last_reward = null
        currentProfile.value.total_pearls = null
      }
      const item = searchResults.value.find((u) => u.id === userId)
      if (item) {
        item.relation_status = 'none'
      }
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al dejar de seguir al usuario')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const block = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoadingId.value = userId
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('block_user', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = 'none'
        currentProfile.value.is_full_profile = false
      }
      successMessage.value = 'Usuario bloqueado correctamente.'
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al bloquear usuario')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const unblock = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoadingId.value = userId
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('unblock_user', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      blockedUsers.value = blockedUsers.value.filter((u) => u.id !== userId)
      successMessage.value = 'Usuario desbloqueado.'
      return true
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al desbloquear usuario')
      return false
    } finally {
      actionLoadingId.value = null
    }
  }

  const search = async (query: string, limit = 20, offset = 0) => {
    if (!user.value) {
      searchResults.value = []
      return
    }
    const cleanQ = query.trim()
    if (cleanQ.length < 2) {
      searchResults.value = []
      return
    }

    searching.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('search_users', {
        p_query: cleanQ,
        p_limit: limit,
        p_offset: offset,
      })
      if (rpcError) throw rpcError
      searchResults.value = Array.isArray(data) ? (data as unknown as UserSearchResultItem[]) : []
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error en la búsqueda de fanáticos')
      searchResults.value = []
    } finally {
      searching.value = false
    }
  }

  const fetchFollowRequests = async () => {
    if (!user.value) {
      followRequests.value = []
      return
    }
    loadingRequests.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('get_my_follow_requests')
      if (rpcError) throw rpcError
      followRequests.value = Array.isArray(data) ? (data as unknown as FollowRequestItem[]) : []
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cargar solicitudes de seguimiento')
    } finally {
      loadingRequests.value = false
    }
  }

  const fetchBlockedUsers = async () => {
    if (!user.value) {
      blockedUsers.value = []
      return
    }
    loadingBlocked.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('get_blocked_users')
      if (rpcError) throw rpcError
      blockedUsers.value = Array.isArray(data) ? (data as unknown as BlockedUserItem[]) : []
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cargar usuarios bloqueados')
    } finally {
      loadingBlocked.value = false
    }
  }

  const fetchFollowers = async (userId: string) => {
    if (!user.value || !userId) return
    loadingList.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('get_user_followers', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      followersList.value = Array.isArray(data) ? (data as unknown as UserFollowUserItem[]) : []
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cargar lista de seguidores')
    } finally {
      loadingList.value = false
    }
  }

  const fetchFollowing = async (userId: string) => {
    if (!user.value || !userId) return
    loadingList.value = true
    clearMessages()
    try {
      const { data, error: rpcError } = await supabase.rpc('get_user_following', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      followingList.value = Array.isArray(data) ? (data as unknown as UserFollowUserItem[]) : []
    } catch (err: any) {
      error.value = formatSocialError(err, 'Error al cargar lista de seguidos')
    } finally {
      loadingList.value = false
    }
  }

  return {
    currentProfile: computed(() => currentProfile.value),
    loadingProfile: computed(() => loadingProfile.value),
    searchResults: computed(() => searchResults.value),
    searching: computed(() => searching.value),
    followRequests: computed(() => followRequests.value),
    loadingRequests: computed(() => loadingRequests.value),
    blockedUsers: computed(() => blockedUsers.value),
    loadingBlocked: computed(() => loadingBlocked.value),
    followersList: computed(() => followersList.value),
    followingList: computed(() => followingList.value),
    loadingList: computed(() => loadingList.value),
    actionLoading: computed(() => !!actionLoadingId.value),
    actionLoadingId: computed(() => actionLoadingId.value),
    error: computed(() => error.value),
    successMessage: computed(() => successMessage.value),
    clearMessages,
    fetchPublicProfile,
    sendFollow,
    respondRequest,
    cancelFollow,
    unfollow,
    block,
    unblock,
    search,
    fetchFollowRequests,
    fetchBlockedUsers,
    fetchFollowers,
    fetchFollowing,
  }
}
