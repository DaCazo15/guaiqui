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
  terms_accepted_at?: string | null
  terms_version?: string | null
  privacy_accepted_at?: string | null
  privacy_version?: string | null
  pearls_rules_accepted_at?: string | null
  pearls_rules_version?: string | null
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

export interface SiteAnnouncement {
  id: string
  message: string
  link_url?: string | null
  is_published: boolean
  starts_at: string
  ends_at?: string | null
  created_at: string
}

export interface CarouselSlideRow {
  id: string
  tag?: string | null
  title: string
  subtitle?: string | null
  cta_text?: string | null
  cta_url?: string | null
  image_url?: string | null
  bg_gradient?: string | null
  badge_variant?: string | null
  order_index: number
  is_published: boolean
  starts_at: string
  ends_at?: string | null
  created_at: string
}

export interface HistoryMilestone {
  id: string
  year: string
  title: string
  text: string
  image_url?: string | null
  order_index: number
  is_published: boolean
  created_at: string
}

export interface SiteTeamMember {
  id: string
  name: string
  role: string
  group_category: 'directiva' | 'tecnico' | 'logistica'
  photo_url?: string | null
  order_index: number
  is_published: boolean
  created_at: string
}

export interface FaqItemRow {
  id: string
  question: string
  answer: string
  order_index: number
  is_published: boolean
  created_at: string
}

export interface SiteStat {
  id: string
  label: string
  value: string
  note?: string | null
  is_sponsor: boolean
  logo_url?: string | null
  order_index: number
  is_published: boolean
  created_at: string
}

export interface SocialLink {
  id: string
  platform: string
  label: string
  url: string
  icon?: string | null
  order_index: number
  is_published: boolean
  created_at: string
}

export interface PolicyDocument {
  id: string
  slug: 'terminos' | 'privacidad' | 'perlitas' | 'canjes'
  version: string
  content_markdown: string
  published_at: string
  is_active: boolean
  created_at: string
}

export interface AnalyticsOverview {
  dau: number
  wau: number
  mau: number
  new_registrations: number
  pearls_issued: number
  pearls_spent: number
  redemptions_by_status: Record<string, number>
  avg_fulfillment_hours: number
}

export interface AnalyticsActiveUserPeriod {
  period: string
  active_users: number
  new_registrations: number
}

export interface AnalyticsTopFan {
  fan_id: string
  display_name: string
  avatar_url?: string | null
  trivias_played: number
  pearls_earned: number
}

export interface AnalyticsTriviaSummary {
  popular_trivias: Array<{
    trivia_id: string
    title: string
    attempts_count: number
    avg_score: number
    completion_rate: number
  }>
  hardest_questions: Array<{
    question_id: string
    trivia_title: string
    question_text: string
    total_answers: number
    correct_rate: number
  }>
}

export interface AnalyticsProductSummary {
  top_products: Array<{
    product_id: string
    name: string
    cost_pearls: number
    redemptions_count: number
    total_pearls_spent: number
  }>
  low_stock_alerts: Array<{
    product_id: string
    name: string
    stock: number
    active: boolean
  }>
}

export interface AnalyticsDemographics {
  by_municipality: Array<{ name: string; count: number }>
  by_gender: Array<{ name: string; count: number }>
  by_age_group: Array<{ name: string; count: number }>
}

export interface AnalyticsEconomy {
  total_issued: number
  total_spent: number
  total_in_circulation: number
  total_held: number
  cheapest_product_cost: number
  most_expensive_product_cost: number
  days_needed_for_cheapest: number
  days_needed_for_most_expensive: number
}

export interface AnalyticsFunnelStep {
  step: number
  name: string
  count: number
  conversion_rate: number
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
      site_announcements: { Row: SiteAnnouncement }
      carousel_slides: { Row: CarouselSlideRow }
      history_milestones: { Row: HistoryMilestone }
      site_team_members: { Row: SiteTeamMember }
      faqs: { Row: FaqItemRow }
      site_stats: { Row: SiteStat }
      social_links: { Row: SocialLink }
      policy_documents: { Row: PolicyDocument }
    }
  }
}
