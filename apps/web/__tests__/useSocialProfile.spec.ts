/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'

const mockRpc = vi.fn()
const mockUser = ref<{ id: string } | null>({ id: 'test-user-uuid' })

;(globalThis as any).useSupabaseClient = () => ({
  rpc: mockRpc,
})
;(globalThis as any).useSupabaseUser = () => mockUser

import { useSocialProfile } from '../composables/useSocialProfile'

describe('useSocialProfile composable', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 'test-user-uuid' }
  })

  it('initializes with default empty values', () => {
    const {
      currentProfile,
      loadingProfile,
      searchResults,
      followRequests,
      blockedUsers,
      error,
      successMessage,
    } = useSocialProfile()

    expect(currentProfile.value).toBeNull()
    expect(loadingProfile.value).toBe(false)
    expect(searchResults.value).toEqual([])
    expect(followRequests.value).toEqual([])
    expect(blockedUsers.value).toEqual([])
    expect(error.value).toBeNull()
    expect(successMessage.value).toBeNull()
  })

  it('fetchPublicProfile loads profile data through RPC', async () => {
    const mockProfileData = {
      id: 'target-user-1',
      display_name: 'Target Fan',
      avatar_url: null,
      cover_url: null,
      favorite_sport: 'Baloncesto',
      followed_teams: [],
      followers_count: 5,
      following_count: 2,
      relation_status: 'none',
      is_full_profile: false,
      ranking: null,
      redemptions_count: null,
      last_reward: null,
      total_pearls: null,
    }
    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { currentProfile, fetchPublicProfile, error } = useSocialProfile()
    const result = await fetchPublicProfile('target-user-1')

    expect(mockRpc).toHaveBeenCalledWith('get_public_profile', { p_user_id: 'target-user-1' })
    expect(result).toEqual(mockProfileData)
    expect(currentProfile.value?.display_name).toBe('Target Fan')
    expect(error.value).toBeNull()
  })

  it('sendFollow sends request and sets relation_status to pending', async () => {
    const mockProfileData = {
      id: 'target-user-2',
      display_name: 'Bob Fan',
      relation_status: 'none',
      followers_count: 3,
      following_count: 1,
      followed_teams: [],
      is_full_profile: false,
    }
    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { currentProfile, fetchPublicProfile, sendFollow, successMessage } = useSocialProfile()
    await fetchPublicProfile('target-user-2')

    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null })
    const ok = await sendFollow('target-user-2')

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('send_follow_request', { p_user_id: 'target-user-2' })
    expect(currentProfile.value?.relation_status).toBe('pending')
    expect(successMessage.value).toContain('enviada')
  })

  it('respondRequest accepts follow and removes request from list', async () => {
    mockRpc.mockResolvedValueOnce({
      data: [
        {
          follower_id: 'fan-req-1',
          display_name: 'Requester Fan',
          avatar_url: null,
          favorite_sport: 'Béisbol',
          created_at: '2026-10-31T12:00:00Z',
        },
      ],
      error: null,
    })

    const { followRequests, fetchFollowRequests, respondRequest, successMessage } = useSocialProfile()
    await fetchFollowRequests()
    expect(followRequests.value).toHaveLength(1)

    mockRpc.mockResolvedValueOnce({ data: { success: true, status: 'accepted' }, error: null })
    const ok = await respondRequest('fan-req-1', true)

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('respond_follow_request', {
      p_follower_id: 'fan-req-1',
      p_accept: true,
    })
    expect(followRequests.value).toHaveLength(0)
    expect(successMessage.value).toBe('Solicitud aceptada.')
  })

  it('cancelFollow cancels pending request and resets relation_status', async () => {
    const mockProfileData = {
      id: 'target-user-3',
      display_name: 'Charlie Fan',
      relation_status: 'pending',
      followers_count: 1,
      following_count: 0,
      followed_teams: [],
      is_full_profile: false,
    }
    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { currentProfile, fetchPublicProfile, cancelFollow } = useSocialProfile()
    await fetchPublicProfile('target-user-3')

    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null })
    const ok = await cancelFollow('target-user-3')

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('cancel_follow_request', { p_user_id: 'target-user-3' })
    expect(currentProfile.value?.relation_status).toBe('none')
  })

  it('unfollow removes accepted follow and resets full profile visibility', async () => {
    const mockProfileData = {
      id: 'target-user-4',
      display_name: 'David Fan',
      relation_status: 'accepted',
      followers_count: 10,
      following_count: 4,
      followed_teams: [],
      is_full_profile: true,
      ranking: { rank: 1, points: 100 },
      redemptions_count: 2,
      last_reward: null,
      total_pearls: 50,
    }
    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { currentProfile, fetchPublicProfile, unfollow } = useSocialProfile()
    await fetchPublicProfile('target-user-4')

    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null })
    const ok = await unfollow('target-user-4')

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('unfollow_user', { p_user_id: 'target-user-4' })
    expect(currentProfile.value?.relation_status).toBe('none')
    expect(currentProfile.value?.is_full_profile).toBe(false)
    expect(currentProfile.value?.followers_count).toBe(9)
    expect(currentProfile.value?.ranking).toBeNull()
  })

  it('block blocks user and resets relationship', async () => {
    const mockProfileData = {
      id: 'target-user-5',
      display_name: 'Bad User',
      relation_status: 'accepted',
      followers_count: 2,
      following_count: 1,
      followed_teams: [],
      is_full_profile: true,
    }
    mockRpc.mockResolvedValueOnce({ data: mockProfileData, error: null })

    const { currentProfile, fetchPublicProfile, block } = useSocialProfile()
    await fetchPublicProfile('target-user-5')

    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null })
    const ok = await block('target-user-5')

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('block_user', { p_user_id: 'target-user-5' })
    expect(currentProfile.value?.relation_status).toBe('none')
    expect(currentProfile.value?.is_full_profile).toBe(false)
  })

  it('unblock unblocks user and removes from blockedUsers list', async () => {
    mockRpc.mockResolvedValueOnce({
      data: [
        {
          id: 'blocked-1',
          display_name: 'Blocked Person',
          avatar_url: null,
          blocked_at: '2026-10-31T10:00:00Z',
        },
      ],
      error: null,
    })

    const { blockedUsers, fetchBlockedUsers, unblock } = useSocialProfile()
    await fetchBlockedUsers()
    expect(blockedUsers.value).toHaveLength(1)

    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null })
    const ok = await unblock('blocked-1')

    expect(ok).toBe(true)
    expect(mockRpc).toHaveBeenCalledWith('unblock_user', { p_user_id: 'blocked-1' })
    expect(blockedUsers.value).toHaveLength(0)
  })

  it('search ignores queries under 2 chars and calls search_users RPC otherwise', async () => {
    const { searchResults, search } = useSocialProfile()

    await search('a')
    expect(mockRpc).not.toHaveBeenCalled()
    expect(searchResults.value).toEqual([])

    const mockResults = [
      {
        id: 'user-res-1',
        display_name: 'Carlos Perez',
        avatar_url: null,
        favorite_sport: 'Baloncesto',
        relation_status: 'none',
      },
    ]
    mockRpc.mockResolvedValueOnce({ data: mockResults, error: null })

    await search('Carlos')
    expect(mockRpc).toHaveBeenCalledWith('search_users', {
      p_query: 'Carlos',
      p_limit: 20,
      p_offset: 0,
    })
    expect(searchResults.value).toHaveLength(1)
  })
})
