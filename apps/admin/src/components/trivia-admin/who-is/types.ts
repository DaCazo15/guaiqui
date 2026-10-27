export interface PlayerItem {
  id: string
  name: string
  jersey_number: number
  photo_url?: string | null
  position?: string | null
}

export interface WhoIsRow {
  id: string
  player_id: string
  challenge_type: 'silhouette' | 'dorsal'
  title: string
  clue?: string | null
  custom_image_url?: string | null
  dorsal_number?: number | null
  reward_pearls: number
  status: 'draft' | 'published' | 'archived'
  starts_at: string
  ends_at: string
  created_at: string
  player?: PlayerItem | null
}

export interface WhoIsFormData {
  id: string
  player_id: string
  challenge_type: 'silhouette' | 'dorsal'
  title: string
  clue: string
  custom_image_url: string
  dorsal_number: number | null
  reward_pearls: number
  status: 'draft' | 'published' | 'archived'
  starts_at: string
  ends_at: string
}
