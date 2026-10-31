/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-fan-uuid' })

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { useFriendships } from '../composables/useFriendships'

describe('useFriendships composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-fan-uuid' }
  })

  it('initializes with empty lists and default states', () => {
    const { friends, incomingRequests, outgoingRequests, totalFriends, pendingIncomingCount, loading } =
      useFriendships()
    expect(friends.value).toEqual([])
    expect(incomingRequests.value).toEqual([])
    expect(outgoingRequests.value).toEqual([])
    expect(totalFriends.value).toBe(0)
    expect(pendingIncomingCount.value).toBe(0)
    expect(loading.value).toBe(false)
  })

  it('fetchFriendships populates friends and requests from RPC', async () => {
    const mockData = {
      friends: [
        {
          friendship_id: 'f-1',
          friend_id: 'friend-uuid-1',
          display_name: 'Amigo Test',
          avatar_url: null,
          since: '2026-10-30T10:00:00Z',
          total_pearls: 350,
          tier_name: 'Novato',
          badges_count: 2,
        },
      ],
      incoming_requests: [
        {
          friendship_id: 'f-2',
          sender_id: 'sender-uuid',
          display_name: 'Solicitante 1',
          avatar_url: null,
          created_at: '2026-10-31T09:00:00Z',
          tier_name: 'Devoto',
        },
      ],
      outgoing_requests: [],
      total_friends: 1,
    }
    mockRpc.mockResolvedValueOnce({ data: mockData, error: null })

    const { friends, incomingRequests, totalFriends, pendingIncomingCount, fetchFriendships } =
      useFriendships()

    await fetchFriendships()

    expect(mockRpc).toHaveBeenCalledWith('get_my_friends_and_requests')
    expect(friends.value.length).toBe(1)
    expect(friends.value[0].display_name).toBe('Amigo Test')
    expect(totalFriends.value).toBe(1)
    expect(incomingRequests.value.length).toBe(1)
    expect(pendingIncomingCount.value).toBe(1)
  })

  it('sendFriendRequest invokes send_friend_request RPC and refreshes list', async () => {
    mockRpc
      .mockResolvedValueOnce({
        data: { success: true, status: 'pending', message: 'Solicitud enviada' },
        error: null,
      })
      .mockResolvedValueOnce({
        data: { friends: [], incoming_requests: [], outgoing_requests: [], total_friends: 0 },
        error: null,
      })

    const { sendFriendRequest, sending, error, success } = useFriendships()

    const result = await sendFriendRequest('FRIEND01')

    expect(result.success).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('send_friend_request', { p_target: 'FRIEND01' })
    expect(success.value).toBe('Solicitud enviada')
    expect(error.value).toBeNull()
    expect(sending.value).toBe(false)
  })

  it('acceptRequest and declineRequest invoke respond_friend_request RPC', async () => {
    mockRpc
      .mockResolvedValueOnce({ data: { success: true, status: 'accepted' }, error: null })
      .mockResolvedValueOnce({
        data: { friends: [], incoming_requests: [], outgoing_requests: [], total_friends: 0 },
        error: null,
      })
      .mockResolvedValueOnce({ data: { success: true, status: 'declined' }, error: null })
      .mockResolvedValueOnce({
        data: { friends: [], incoming_requests: [], outgoing_requests: [], total_friends: 0 },
        error: null,
      })

    const { acceptRequest, declineRequest } = useFriendships()

    const accepted = await acceptRequest('f-req-1')
    expect(accepted).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('respond_friend_request', {
      p_friendship_id: 'f-req-1',
      p_action: 'accepted',
    })

    const declined = await declineRequest('f-req-2')
    expect(declined).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('respond_friend_request', {
      p_friendship_id: 'f-req-2',
      p_action: 'declined',
    })
  })

  it('removeFriend invokes remove_friend RPC', async () => {
    mockRpc
      .mockResolvedValueOnce({ data: { success: true }, error: null })
      .mockResolvedValueOnce({
        data: { friends: [], incoming_requests: [], outgoing_requests: [], total_friends: 0 },
        error: null,
      })

    const { removeFriend } = useFriendships()

    const removed = await removeFriend('f-active-1')
    expect(removed).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('remove_friend', { p_friendship_id: 'f-active-1' })
  })
})
