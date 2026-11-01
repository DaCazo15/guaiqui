import { ref, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import type {
  PublicUserProfile,
  FollowRequestItem,
  BlockedUserItem,
  UserFollowUserItem,
  UserSearchResultItem,
} from '@guaiqui/shared'

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
  const actionLoading = ref(false)
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
      error.value = err.message || 'Error al cargar perfil'
      currentProfile.value = null
      return null
    } finally {
      loadingProfile.value = false
    }
  }

  const sendFollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoading.value = true
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('send_follow_request', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = 'pending'
      }
      successMessage.value = 'Solicitud de seguimiento enviada con éxito.'
      return true
    } catch (err: any) {
      error.value = err.message || 'Error al enviar solicitud de seguimiento'
      return false
    } finally {
      actionLoading.value = false
    }
  }

  const respondRequest = async (followerId: string, accept: boolean): Promise<boolean> => {
    if (!user.value || !followerId) return false
    actionLoading.value = true
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
      error.value = err.message || 'Error al responder solicitud'
      return false
    } finally {
      actionLoading.value = false
    }
  }

  const cancelFollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoading.value = true
    clearMessages()
    try {
      const { error: rpcError } = await supabase.rpc('cancel_follow_request', {
        p_user_id: userId,
      })
      if (rpcError) throw rpcError
      if (currentProfile.value && currentProfile.value.id === userId) {
        currentProfile.value.relation_status = 'none'
      }
      successMessage.value = 'Solicitud cancelada.'
      return true
    } catch (err: any) {
      error.value = err.message || 'Error al cancelar solicitud'
      return false
    } finally {
      actionLoading.value = false
    }
  }

  const unfollow = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoading.value = true
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
      successMessage.value = 'Has dejado de seguir a este usuario.'
      return true
    } catch (err: any) {
      error.value = err.message || 'Error al dejar de seguir al usuario'
      return false
    } finally {
      actionLoading.value = false
    }
  }

  const block = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoading.value = true
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
      error.value = err.message || 'Error al bloquear usuario'
      return false
    } finally {
      actionLoading.value = false
    }
  }

  const unblock = async (userId: string): Promise<boolean> => {
    if (!user.value || !userId) return false
    actionLoading.value = true
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
      error.value = err.message || 'Error al desbloquear usuario'
      return false
    } finally {
      actionLoading.value = false
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
      error.value = err.message || 'Error en la búsqueda de usuarios'
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
      error.value = err.message || 'Error al cargar solicitudes de seguimiento'
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
      error.value = err.message || 'Error al cargar usuarios bloqueados'
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
      error.value = err.message || 'Error al cargar lista de seguidores'
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
      error.value = err.message || 'Error al cargar lista de seguidos'
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
    actionLoading: computed(() => actionLoading.value),
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
