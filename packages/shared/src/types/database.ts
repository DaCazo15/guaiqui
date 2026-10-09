export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type UserStatus = 'active' | 'suspended'
export type StaffRole = 'staff' | 'admin'
export type LedgerType = 'trivia_reward' | 'redemption' | 'refund' | 'admin_adjustment' | 'bonus' | 'streak_bonus'
export type LedgerStatus = 'confirmed' | 'held' | 'revoked'
export type TriviaStatus = 'draft' | 'published' | 'archived'
export type ProductCategory = 'physical' | 'experience' | 'raffle'
export type RedemptionStatus = 'pending' | 'approved' | 'scheduled' | 'delivered' | 'completed' | 'cancelled' | 'rejected' | 'issue' | 'expired'
export type ScanResult = 'success' | 'invalid' | 'already_delivered' | 'expired'
export type GameStatus = 'scheduled' | 'live' | 'finished' | 'cancelled'
export type RiskSeverity = 'low' | 'medium' | 'high'

export interface Profile {
  id: string
  display_name: string
  avatar_url?: string | null
  municipality?: string | null
  birth_date?: string | null
  gender?: string | null
  favorite_player_id?: string | null
  shirt_size?: string | null
  referral_source?: string | null
  notification_prefs?: Json
  status: UserStatus
  created_at: string
}

export interface StaffMember {
  user_id: string
  role: StaffRole
  active: boolean
  created_at: string
}

export interface Wallet {
  fan_id: string
  balance_cache: number
  updated_at: string
}

export interface LedgerEntry {
  id: string
  fan_id: string
  amount: number
  type: LedgerType
  status: LedgerStatus
  source_type: string
  source_id: string
  note?: string | null
  created_by?: string | null
  created_at: string
}

export interface Trivia {
  id: string
  title: string
  description?: string | null
  status: TriviaStatus
  starts_at: string
  ends_at: string
  time_limit_seconds: number
  reward_rules: Json
  max_attempts: number
  created_at: string
}

export interface TriviaQuestion {
  id: string
  trivia_id: string
  question_text: string
  points: number
  order_index: number
  created_at: string
}

export interface TriviaOption {
  id: string
  question_id: string
  option_text: string
  is_correct?: boolean
}

export interface TriviaAttempt {
  id: string
  fan_id: string
  trivia_id: string
  started_at: string
  expires_at: string
  submitted_at?: string | null
  answers?: Json | null
  score: number
  pearls_awarded: number
  suspicious: boolean
  seed: number
  idempotency_key: string
}

export interface Product {
  id: string
  name: string
  description?: string | null
  category: ProductCategory
  cost_pearls: number
  stock: number
  variants?: Json | null
  active: boolean
  valid_from: string
  valid_until?: string | null
  images: string[]
  created_at: string
}

export interface Redemption {
  id: string
  fan_id: string
  product_id: string
  variant?: string | null
  cost_pearls: number
  status: RedemptionStatus
  code_hash: string
  approved_by?: string | null
  approved_at?: string | null
  delivered_by?: string | null
  delivered_at?: string | null
  expires_at?: string | null
  idempotency_key: string
  created_at: string
}

export interface RedemptionHistory {
  id: string
  redemption_id: string
  previous_status?: RedemptionStatus | null
  new_status: RedemptionStatus
  changed_by?: string | null
  note?: string | null
  created_at: string
}

export interface ScanEvent {
  id: string
  staff_id: string
  code_hash: string
  result: ScanResult
  device?: string | null
  created_at: string
}

export interface Player {
  id: string
  name: string
  jersey_number: number
  position: string
  height?: string | null
  age?: number | null
  nationality: string
  bio?: string | null
  is_active: boolean
  is_star: boolean
  created_at: string
}

export interface Game {
  id: string
  opponent: string
  location: string
  game_date: string
  is_home: boolean
  status: GameStatus
  our_score: number
  opponent_score: number
  created_at: string
}

export interface Segment {
  id: string
  name: string
  filters: Json
  created_at: string
}

export interface EconomySettings {
  id: string
  daily_pearl_cap: number
  weekly_pearl_cap: number
  streak_bonus_config: Json
  created_at: string
}

export interface RiskFlag {
  id: string
  fan_id: string
  reason: string
  severity: RiskSeverity
  resolved: boolean
  created_at: string
}

export interface AuditLog {
  id: string
  actor_id?: string | null
  action: string
  entity: string
  entity_id?: string | null
  before?: Json | null
  after?: Json | null
  created_at: string
}

export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile }
      staff_members: { Row: StaffMember }
      wallets: { Row: Wallet }
      ledger_entries: { Row: LedgerEntry }
      trivias: { Row: Trivia }
      trivia_questions: { Row: TriviaQuestion }
      trivia_options: { Row: TriviaOption }
      trivia_attempts: { Row: TriviaAttempt }
      products: { Row: Product }
      redemptions: { Row: Redemption }
      redemption_history: { Row: RedemptionHistory }
      scan_events: { Row: ScanEvent }
      players: { Row: Player }
      games: { Row: Game }
      segments: { Row: Segment }
      economy_settings: { Row: EconomySettings }
      risk_flags: { Row: RiskFlag }
      audit_log: { Row: AuditLog }
    }
  }
}
