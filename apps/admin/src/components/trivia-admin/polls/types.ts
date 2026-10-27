export interface PlayerItem {
  id: string
  name: string
  jersey_number: number
  photo_url?: string | null
  position?: string | null
}

export interface GameItem {
  id: string
  opponent: string
  game_date: string
  is_home: boolean
  location: string
}

export interface PollOptionItem {
  id?: string
  poll_id?: string
  label: string
  player_id?: string | null
  order_index: number
  votes_count?: number
  player?: PlayerItem | null
}

export interface PollRow {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  reward_pearls: number
  status: 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
  starts_at: string
  closes_at: string
  correct_option_id?: string | null
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
  game?: GameItem | null
  options?: PollOptionItem[]
  total_votes?: number
}

export interface OptionFormItem {
  id?: string
  label: string
  player_id: string
}

export interface PollFormData {
  id: string
  game_id: string
  title: string
  description: string
  reward_pearls: number
  status: 'published' | 'draft'
  starts_at: string
  closes_at: string
  options: OptionFormItem[]
}
