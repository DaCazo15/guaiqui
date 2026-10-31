export type FriendshipStatus = 'pending' | 'accepted' | 'declined' | 'blocked'

export interface FriendItem {
  friendship_id: string
  friend_id: string
  display_name: string
  avatar_url: string | null
  since: string
  total_pearls: number
  tier_name: string
  badges_count: number
  favorite_player?: string | null
}

export interface IncomingFriendRequest {
  friendship_id: string
  sender_id: string
  display_name: string
  avatar_url: string | null
  created_at: string
  tier_name: string
}

export interface OutgoingFriendRequest {
  friendship_id: string
  target_id: string
  display_name: string
  avatar_url: string | null
  created_at: string
}

export interface FriendsSummary {
  friends: FriendItem[]
  incoming_requests: IncomingFriendRequest[]
  outgoing_requests: OutgoingFriendRequest[]
  total_friends: number
}
