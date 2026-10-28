export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: any }
  | any[]

export type UserStatus = 'active' | 'suspended' | 'deleted'
export type StaffRole = 'staff' | 'admin'
export type LedgerType = 'trivia_reward' | 'redemption' | 'refund' | 'admin_adjustment' | 'bonus' | 'streak_bonus' | 'birthday_bonus' | 'ad_reward'
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
  cover_url?: string | null
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
  updated_at?: string | null
  deleted_at?: string | null
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
  nationality?: string | null
  bio?: string | null
  is_active: boolean
  is_star: boolean
  instagram_url?: string | null
  photo_url?: string | null
  created_at: string
}

export interface Game {
  id: string
  opponent: string
  opponent_logo_url?: string | null
  location: string
  game_date: string
  is_home: boolean
  status: GameStatus
  our_score?: number | null
  opponent_score?: number | null
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

export interface BirthdaySettings {
  id: number
  enabled: boolean
  title: string
  message: string
  image_url?: string | null
  send_hour: number
  grace_days: number
  bonus_pearls: number
  updated_at: string
}

export interface BirthdayCardResponse {
  eligible: boolean
  display_name?: string
  title?: string
  message?: string
  image_url?: string | null
  bonus_pearls?: number
  has_claimed_bonus?: boolean
}

export interface SponsorVideo {
  id: string
  title: string
  sponsor_name?: string | null
  video_url: string
  drive_file_id: string
  redirect_url?: string | null
  cta_text: string
  min_seconds: number
  reward_points: number
  is_active: boolean
  order_index: number
  created_at: string
  updated_at: string
}

export type CtaType = 'container' | 'phrase'
export type CtaMediaType = 'none' | 'logo' | 'icon' | 'image'
export type CtaPlacement = 'before_footer' | 'after_hero'

export interface LandingCta {
  id: string
  name: string
  type: CtaType
  placement: CtaPlacement
  is_active: boolean
  is_published: boolean
  badge_text?: string | null
  heading?: string | null
  subtitle?: string | null
  button_text?: string | null
  button_url?: string | null
  bg_gradient?: string | null
  bg_color?: string | null
  phrase_text?: string | null
  font_family?: string | null
  font_size?: string | null
  letter_spacing?: string | null
  font_weight?: string | null
  text_color?: string | null
  media_type?: CtaMediaType | null
  media_value?: string | null
  created_at: string
  updated_at: string
}

export interface HeroCarouselSlide {
  id: string
  title: string
  tag?: string | null
  tag_variant?: 'primary' | 'gold' | 'accent' | null
  subtitle?: string | null
  image_url?: string | null
  cta_text?: string | null
  cta_url?: string | null
  cta_secondary_text?: string | null
  cta_secondary_url?: string | null
  highlight_title?: string | null
  highlight_subtitle?: string | null
  highlight_badge?: string | null
  image_layout?: 'background' | 'right' | null
  guarantee_1?: string | null
  guarantee_2?: string | null
  guarantee_3?: string | null
  show_guarantees?: boolean
  text_align?: 'left' | 'center'
  order_index: number
  is_published: boolean
  created_at: string
  updated_at: string
}

export interface LandingSettings {
  id: number
  hero_title: string
  hero_subtitle: string
  hero_badge_text?: string | null
  cta_primary_text: string
  cta_primary_url: string
  cta_secondary_text: string
  cta_secondary_url: string
  hero_guarantee_1?: string | null
  hero_guarantee_2?: string | null
  hero_guarantee_3?: string | null
  dark_mode_enabled: boolean
  theme_color: string
  hero_image_url?: string | null
  hero_carousel_enabled: boolean
  hero_card_color?: string | null
  updated_at?: string | null
}

export type ChallengeType = 'silhouette' | 'dorsal'
export type ChallengeStatus = 'draft' | 'published' | 'archived'

export interface GuessPlayerChallenge {
  id: string
  player_id: string
  challenge_type: ChallengeType
  title: string
  clue?: string | null
  custom_image_url?: string | null
  dorsal_number?: number | null
  reward_pearls: number
  status: ChallengeStatus
  starts_at: string
  ends_at: string
  created_at: string
}

export interface GuessPlayerVote {
  id: string
  challenge_id: string
  fan_id: string
  selected_player_id: string
  is_correct: boolean
  pearls_awarded: number
  created_at: string
}

export interface ActiveWhoIsChallenge {
  id: string
  challenge_type: ChallengeType
  title: string
  clue?: string | null
  custom_image_url?: string | null
  dorsal_number?: number | null
  reward_pearls: number
  status: ChallengeStatus
  starts_at: string
  ends_at: string
  created_at: string
  player_id?: string | null
  player_name?: string | null
  player_photo_url?: string | null
  player_jersey_number?: number | null
  selected_player_id?: string | null
  is_correct?: boolean | null
  pearls_awarded?: number | null
  voted_at?: string | null
  has_voted: boolean
}

export type TriviaPollStatus = 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'

export interface TriviaPoll {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  reward_pearls: number
  status: TriviaPollStatus
  starts_at: string
  closes_at: string
  correct_option_id?: string | null
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
}

export interface TriviaPollOption {
  id: string
  poll_id: string
  label: string
  player_id?: string | null
  order_index: number
  votes_count: number
  created_at: string
}

export interface TriviaPollVote {
  id: string
  poll_id: string
  fan_id: string
  option_id: string
  is_winner?: boolean | null
  pearls_awarded: number
  created_at: string
}

export interface ActiveTriviaPoll {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  reward_pearls: number
  status: TriviaPollStatus
  starts_at: string
  closes_at: string
  is_closed: boolean
  is_resolved: boolean
  resolved_at?: string | null
  created_at: string
  correct_option_id?: string | null
  game?: {
    id: string
    opponent: string
    game_date: string
    is_home: boolean
    location: string
  } | null
  user_vote?: {
    vote_id: string
    option_id: string
    is_winner?: boolean | null
    pearls_awarded: number
    voted_at: string
  } | null
  options: Array<{
    id: string
    label: string
    order_index: number
    votes_count: number
    player_id?: string | null
    player?: {
      id: string
      name: string
      jersey_number: number
      photo_url?: string | null
      position?: string | null
    } | null
  }>
}

// ==========================================
// 1. OVER / UNDER PREDICTIONS
// ==========================================
export type OverUnderStatus = 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'
export type OverUnderChoice = 'over' | 'under' | 'push'

export interface OverUnderPrediction {
  id: string
  game_id?: string | null
  player_id?: string | null
  title: string
  description?: string | null
  stat_type: string
  line_value: number
  reward_pearls: number
  status: OverUnderStatus
  starts_at: string
  closes_at: string
  actual_value?: number | null
  winning_choice?: OverUnderChoice | null
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
}

export interface OverUnderVote {
  id: string
  prediction_id: string
  fan_id: string
  choice: 'over' | 'under'
  is_winner?: boolean | null
  pearls_awarded: number
  created_at: string
}

export interface ActiveOverUnder {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  stat_type: string
  line_value: number
  reward_pearls: number
  status: OverUnderStatus
  starts_at: string
  closes_at: string
  winning_choice?: OverUnderChoice | null
  actual_value?: number | null
  player?: {
    id: string
    name: string
    jersey_number: number
    photo_url?: string | null
    position?: string | null
  } | null
  game?: {
    id: string
    opponent_name: string
    opponent_logo_url?: string | null
    game_date: string
    is_home: boolean
  } | null
  user_vote?: {
    id: string
    choice: 'over' | 'under'
    is_winner?: boolean | null
    pearls_awarded: number
    created_at: string
  } | null
  over_count: number
  under_count: number
}

// ==========================================
// 2. MYSTERY PLAY CHALLENGES («¿QUÉ PASÓ DESPUÉS?»)
// ==========================================
export type MysteryPlayStatus = 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'

export interface MysteryPlayChallenge {
  id: string
  game_id?: string | null
  title: string
  description?: string | null
  video_url?: string | null
  cover_image_url?: string | null
  question: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  correct_option: string
  reveal_video_url?: string | null
  reward_pearls: number
  status: MysteryPlayStatus
  starts_at: string
  closes_at: string
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
}

export interface MysteryPlayVote {
  id: string
  challenge_id: string
  fan_id: string
  selected_option: string
  is_correct: boolean
  pearls_awarded: number
  created_at: string
}

export interface ActiveMysteryPlay {
  id: string
  title: string
  description?: string | null
  video_url?: string | null
  cover_image_url?: string | null
  question: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  reward_pearls: number
  status: MysteryPlayStatus
  starts_at: string
  closes_at: string
  correct_option?: string | null
  reveal_video_url?: string | null
  game?: {
    id: string
    opponent_name: string
    opponent_logo_url?: string | null
    game_date: string
  } | null
  user_vote?: {
    id: string
    selected_option: string
    is_correct: boolean
    pearls_awarded: number
    created_at: string
  } | null
}

// ==========================================
// 3. SCORE PREDICTIONS (MARCADOR EXACTO)
// ==========================================
export type ScorePredictionStatus = 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'

export interface ScorePrediction {
  id: string
  game_id: string
  title: string
  description?: string | null
  exact_reward_pearls: number
  closest_reward_pearls: number
  status: ScorePredictionStatus
  starts_at: string
  closes_at: string
  final_guaiqueries_score?: number | null
  final_rival_score?: number | null
  resolved_at?: string | null
  resolved_by?: string | null
  created_at: string
}

export interface ScorePredictionVote {
  id: string
  prediction_id: string
  fan_id: string
  predicted_guaiqueries_score: number
  predicted_rival_score: number
  is_exact_match?: boolean | null
  is_closest_match?: boolean | null
  pearls_awarded: number
  created_at: string
}

export interface ActiveScorePrediction {
  id: string
  title: string
  description?: string | null
  exact_reward_pearls: number
  closest_reward_pearls: number
  status: ScorePredictionStatus
  starts_at: string
  closes_at: string
  final_guaiqueries_score?: number | null
  final_rival_score?: number | null
  game: {
    id: string
    opponent_name: string
    opponent_logo_url?: string | null
    game_date: string
    is_home: boolean
  }
  user_vote?: {
    id: string
    predicted_guaiqueries_score: number
    predicted_rival_score: number
    is_exact_match?: boolean | null
    is_closest_match?: boolean | null
    pearls_awarded: number
    created_at: string
  } | null
  total_participants: number
}

// ==========================================
// 4. FLASH TRIVIA (CONTRARRELOJ 60s)
// ==========================================
export type FlashTriviaStatus = 'draft' | 'published' | 'closed' | 'archived'

export interface FlashTriviaChallenge {
  id: string
  title: string
  description?: string | null
  time_limit_seconds: number
  pearls_per_correct: number
  status: FlashTriviaStatus
  starts_at: string
  closes_at: string
  created_at: string
}

export interface FlashTriviaQuestion {
  id: string
  challenge_id: string
  question: string
  option_a: string
  option_b: string
  option_c?: string | null
  option_d?: string | null
  correct_option: string
  order_index: number
  created_at: string
}

export interface FlashTriviaAttempt {
  id: string
  challenge_id: string
  fan_id: string
  correct_count: number
  total_answered: number
  time_spent_seconds: number
  pearls_awarded: number
  created_at: string
}

export interface ActiveFlashTrivia {
  id: string
  title: string
  description?: string | null
  time_limit_seconds: number
  pearls_per_correct: number
  status: FlashTriviaStatus
  starts_at: string
  closes_at: string
  user_attempt?: {
    id: string
    correct_count: number
    total_answered: number
    time_spent_seconds: number
    pearls_awarded: number
    created_at: string
  } | null
  questions: Array<{
    id: string
    question: string
    option_a: string
    option_b: string
    option_c?: string | null
    option_d?: string | null
    order_index: number
  }>
}

// ==========================================
// 5. PROGRESSIVE CLUES (PISTAS PROGRESIVAS)
// ==========================================
export type ProgressiveClueStatus = 'draft' | 'published' | 'closed' | 'resolved' | 'cancelled'

export interface ProgressiveClueChallenge {
  id: string
  player_id?: string | null
  target_player_name: string
  title: string
  description?: string | null
  clue_1: string
  clue_2: string
  clue_3: string
  pearls_clue_1: number
  pearls_clue_2: number
  pearls_clue_3: number
  reveal_photo_url?: string | null
  status: ProgressiveClueStatus
  starts_at: string
  closes_at: string
  created_at: string
}

export interface ProgressiveClueVote {
  id: string
  challenge_id: string
  fan_id: string
  selected_player_id?: string | null
  clues_revealed_count: number
  is_correct: boolean
  pearls_awarded: number
  created_at: string
}

export interface ActiveProgressiveClue {
  id: string
  title: string
  description?: string | null
  clue_1: string
  clue_2: string
  clue_3: string
  pearls_clue_1: number
  pearls_clue_2: number
  pearls_clue_3: number
  status: ProgressiveClueStatus
  starts_at: string
  closes_at: string
  target_player_name?: string | null
  reveal_photo_url?: string | null
  target_player?: {
    id: string
    name: string
    jersey_number: number
    photo_url?: string | null
    position?: string | null
  } | null
  user_vote?: {
    id: string
    clues_revealed_count: number
    is_correct: boolean
    pearls_awarded: number
    created_at: string
  } | null
}

// ==========================================
// 6. NOTIFICATION TEMPLATES
// ==========================================
export interface NotificationTemplateVariable {
  key: string
  label: string
}

export interface NotificationTemplate {
  id: string
  title_template: string
  body_template: string
  description: string
  category: 'trivias' | 'economy' | 'system'
  available_variables: NotificationTemplateVariable[]
  is_active: boolean
  updated_at: string
  updated_by?: string | null
}

// ============================================================================
// SUPABASE GENERATED SCHEMA TYPES
// ============================================================================

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      ad_daily_progress: {
        Row: {
          blocks_paid: number
          completed_count: number
          created_at: string
          day: string
          updated_at: string
          user_id: string
        }
        Insert: {
          blocks_paid?: number
          completed_count?: number
          created_at?: string
          day: string
          updated_at?: string
          user_id: string
        }
        Update: {
          blocks_paid?: number
          completed_count?: number
          created_at?: string
          day?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ad_daily_progress_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ad_reconciliation: {
        Row: {
          day: string
          google_rewarded_impressions: number
          imported_at: string
          imported_by: string | null
          notes: string | null
        }
        Insert: {
          day: string
          google_rewarded_impressions?: number
          imported_at?: string
          imported_by?: string | null
          notes?: string | null
        }
        Update: {
          day?: string
          google_rewarded_impressions?: number
          imported_at?: string
          imported_by?: string | null
          notes?: string | null
        }
        Relationships: []
      }
      ad_reward_tiers: {
        Row: {
          block_number: number
          pearls: number
          updated_at: string
        }
        Insert: {
          block_number: number
          pearls: number
          updated_at?: string
        }
        Update: {
          block_number?: number
          pearls?: number
          updated_at?: string
        }
        Relationships: []
      }
      ad_sessions: {
        Row: {
          block_index: number | null
          completed_at: string | null
          created_at: string
          day: string
          id: string
          reason: string | null
          started_at: string
          status: string
          user_id: string
        }
        Insert: {
          block_index?: number | null
          completed_at?: string | null
          created_at?: string
          day: string
          id?: string
          reason?: string | null
          started_at?: string
          status: string
          user_id: string
        }
        Update: {
          block_index?: number | null
          completed_at?: string | null
          created_at?: string
          day?: string
          id?: string
          reason?: string | null
          started_at?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ad_sessions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      app_secrets: {
        Row: {
          created_at: string
          key_name: string
          secret_value: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          key_name: string
          secret_value: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          key_name?: string
          secret_value?: string
          updated_at?: string
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          after: Json | null
          before: Json | null
          created_at: string
          entity: string
          entity_id: string | null
          id: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity: string
          entity_id?: string | null
          id?: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity?: string
          entity_id?: string | null
          id?: string
        }
        Relationships: []
      }
      auth_trigger_errors: {
        Row: {
          created_at: string
          error_message: string
          id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          error_message: string
          id?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          error_message?: string
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      birthday_settings: {
        Row: {
          bonus_pearls: number
          enabled: boolean
          grace_days: number
          id: number
          image_url: string | null
          message: string
          send_hour: number
          title: string
          updated_at: string
        }
        Insert: {
          bonus_pearls?: number
          enabled?: boolean
          grace_days?: number
          id?: number
          image_url?: string | null
          message?: string
          send_hour?: number
          title?: string
          updated_at?: string
        }
        Update: {
          bonus_pearls?: number
          enabled?: boolean
          grace_days?: number
          id?: number
          image_url?: string | null
          message?: string
          send_hour?: number
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      blocked_identities: {
        Row: {
          created_at: string
          email_hmac: string
          id: string
          reason: string
        }
        Insert: {
          created_at?: string
          email_hmac: string
          id?: string
          reason: string
        }
        Update: {
          created_at?: string
          email_hmac?: string
          id?: string
          reason?: string
        }
        Relationships: []
      }
      captcha_passes: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          ip_hash: string
          used: boolean
          user_id: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          ip_hash: string
          used?: boolean
          user_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          ip_hash?: string
          used?: boolean
          user_id?: string
        }
        Relationships: []
      }
      carousel_slides: {
        Row: {
          badge_variant: string | null
          bg_gradient: string | null
          created_at: string
          cta_text: string | null
          cta_url: string | null
          ends_at: string | null
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          starts_at: string
          subtitle: string | null
          tag: string | null
          title: string
        }
        Insert: {
          badge_variant?: string | null
          bg_gradient?: string | null
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          starts_at?: string
          subtitle?: string | null
          tag?: string | null
          title: string
        }
        Update: {
          badge_variant?: string | null
          bg_gradient?: string | null
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          starts_at?: string
          subtitle?: string | null
          tag?: string | null
          title?: string
        }
        Relationships: []
      }
      display_name_change_logs: {
        Row: {
          changed_at: string
          id: string
          new_name: string
          old_name: string | null
          user_id: string
        }
        Insert: {
          changed_at?: string
          id?: string
          new_name: string
          old_name?: string | null
          user_id: string
        }
        Update: {
          changed_at?: string
          id?: string
          new_name?: string
          old_name?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "display_name_change_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      economy_settings: {
        Row: {
          ad_min_account_age_days: number
          ad_min_seconds: number
          ad_min_trivias_completed: number
          ads_enabled: boolean
          block_size: number
          created_at: string
          daily_ad_views: number
          daily_pearl_cap: number
          id: string
          streak_bonus_config: Json
          weekly_pearl_cap: number
        }
        Insert: {
          ad_min_account_age_days?: number
          ad_min_seconds?: number
          ad_min_trivias_completed?: number
          ads_enabled?: boolean
          block_size?: number
          created_at?: string
          daily_ad_views?: number
          daily_pearl_cap?: number
          id?: string
          streak_bonus_config?: Json
          weekly_pearl_cap?: number
        }
        Update: {
          ad_min_account_age_days?: number
          ad_min_seconds?: number
          ad_min_trivias_completed?: number
          ads_enabled?: boolean
          block_size?: number
          created_at?: string
          daily_ad_views?: number
          daily_pearl_cap?: number
          id?: string
          streak_bonus_config?: Json
          weekly_pearl_cap?: number
        }
        Relationships: []
      }
      email_usage_tracker: {
        Row: {
          active_key_index: number
          created_at: string
          limit_reached_alert_sent: boolean
          period_yyyy_mm: string
          total_sent: number
          updated_at: string
        }
        Insert: {
          active_key_index?: number
          created_at?: string
          limit_reached_alert_sent?: boolean
          period_yyyy_mm: string
          total_sent?: number
          updated_at?: string
        }
        Update: {
          active_key_index?: number
          created_at?: string
          limit_reached_alert_sent?: boolean
          period_yyyy_mm?: string
          total_sent?: number
          updated_at?: string
        }
        Relationships: []
      }
      faqs: {
        Row: {
          answer: string
          created_at: string
          id: string
          is_published: boolean
          order_index: number
          question: string
        }
        Insert: {
          answer: string
          created_at?: string
          id?: string
          is_published?: boolean
          order_index?: number
          question: string
        }
        Update: {
          answer?: string
          created_at?: string
          id?: string
          is_published?: boolean
          order_index?: number
          question?: string
        }
        Relationships: []
      }
      fraud_telemetry: {
        Row: {
          action: string
          created_at: string
          device_id: string | null
          fan_id: string
          id: string
          ip_hash: string | null
        }
        Insert: {
          action: string
          created_at?: string
          device_id?: string | null
          fan_id: string
          id?: string
          ip_hash?: string | null
        }
        Update: {
          action?: string
          created_at?: string
          device_id?: string | null
          fan_id?: string
          id?: string
          ip_hash?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fraud_telemetry_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      games: {
        Row: {
          created_at: string
          game_date: string
          id: string
          is_home: boolean
          location: string
          opponent: string
          opponent_score: number | null
          our_score: number | null
          status: Database["public"]["Enums"]["game_status"]
        }
        Insert: {
          created_at?: string
          game_date: string
          id?: string
          is_home?: boolean
          location?: string
          opponent: string
          opponent_score?: number | null
          our_score?: number | null
          status?: Database["public"]["Enums"]["game_status"]
        }
        Update: {
          created_at?: string
          game_date?: string
          id?: string
          is_home?: boolean
          location?: string
          opponent?: string
          opponent_score?: number | null
          our_score?: number | null
          status?: Database["public"]["Enums"]["game_status"]
        }
        Relationships: []
      }
      hall_of_fame_championships: {
        Row: {
          created_at: string
          highlight: string | null
          id: string
          is_hexa: boolean
          is_published: boolean
          order_index: number
          runner_up: string | null
          tournament: string
          year: number
        }
        Insert: {
          created_at?: string
          highlight?: string | null
          id?: string
          is_hexa?: boolean
          is_published?: boolean
          order_index?: number
          runner_up?: string | null
          tournament: string
          year: number
        }
        Update: {
          created_at?: string
          highlight?: string | null
          id?: string
          is_hexa?: boolean
          is_published?: boolean
          order_index?: number
          runner_up?: string | null
          tournament?: string
          year?: number
        }
        Relationships: []
      }
      hall_of_fame_jerseys: {
        Row: {
          badge_icon: string
          created_at: string
          description: string | null
          highlight: string | null
          id: string
          is_published: boolean
          jersey_number: number
          nickname: string | null
          order_index: number
          player_name: string
          position: string | null
          titles_badge: string | null
          titles_count: number
          years_active: string | null
        }
        Insert: {
          badge_icon?: string
          created_at?: string
          description?: string | null
          highlight?: string | null
          id?: string
          is_published?: boolean
          jersey_number: number
          nickname?: string | null
          order_index?: number
          player_name: string
          position?: string | null
          titles_badge?: string | null
          titles_count?: number
          years_active?: string | null
        }
        Update: {
          badge_icon?: string
          created_at?: string
          description?: string | null
          highlight?: string | null
          id?: string
          is_published?: boolean
          jersey_number?: number
          nickname?: string | null
          order_index?: number
          player_name?: string
          position?: string | null
          titles_badge?: string | null
          titles_count?: number
          years_active?: string | null
        }
        Relationships: []
      }
      hall_of_fame_legends: {
        Row: {
          achievements: string[]
          bio: string | null
          category: string
          created_at: string
          era: string | null
          id: string
          image_url: string | null
          is_published: boolean
          name: string
          nickname: string | null
          order_index: number
          position: string | null
          role: string
          titles: string[]
        }
        Insert: {
          achievements?: string[]
          bio?: string | null
          category?: string
          created_at?: string
          era?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          name: string
          nickname?: string | null
          order_index?: number
          position?: string | null
          role?: string
          titles?: string[]
        }
        Update: {
          achievements?: string[]
          bio?: string | null
          category?: string
          created_at?: string
          era?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          name?: string
          nickname?: string | null
          order_index?: number
          position?: string | null
          role?: string
          titles?: string[]
        }
        Relationships: []
      }
      hero_carousel_slides: {
        Row: {
          created_at: string
          cta_text: string | null
          cta_url: string | null
          guarantee_1: string | null
          guarantee_2: string | null
          guarantee_3: string | null
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          show_guarantees: boolean
          subtitle: string | null
          tag: string | null
          text_align: string
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          guarantee_1?: string | null
          guarantee_2?: string | null
          guarantee_3?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          show_guarantees?: boolean
          subtitle?: string | null
          tag?: string | null
          text_align?: string
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          guarantee_1?: string | null
          guarantee_2?: string | null
          guarantee_3?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          show_guarantees?: boolean
          subtitle?: string | null
          tag?: string | null
          text_align?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      history_milestones: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          text: string
          title: string
          year: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          text: string
          title: string
          year: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          text?: string
          title?: string
          year?: string
        }
        Relationships: []
      }
      instagram_posts: {
        Row: {
          caption: string | null
          created_at: string
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          post_url: string
          shortcode: string | null
        }
        Insert: {
          caption?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          post_url: string
          shortcode?: string | null
        }
        Update: {
          caption?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          post_url?: string
          shortcode?: string | null
        }
        Relationships: []
      }
      landing_ctas: {
        Row: {
          badge_text: string | null
          bg_color: string | null
          bg_gradient: string | null
          button_text: string | null
          button_url: string | null
          created_at: string
          font_family: string | null
          font_size: string | null
          font_weight: string | null
          heading: string | null
          id: string
          is_active: boolean
          is_published: boolean
          letter_spacing: string | null
          media_type: string | null
          media_value: string | null
          name: string
          phrase_text: string | null
          placement: string
          subtitle: string | null
          text_color: string | null
          type: string
          updated_at: string
        }
        Insert: {
          badge_text?: string | null
          bg_color?: string | null
          bg_gradient?: string | null
          button_text?: string | null
          button_url?: string | null
          created_at?: string
          font_family?: string | null
          font_size?: string | null
          font_weight?: string | null
          heading?: string | null
          id?: string
          is_active?: boolean
          is_published?: boolean
          letter_spacing?: string | null
          media_type?: string | null
          media_value?: string | null
          name: string
          phrase_text?: string | null
          placement?: string
          subtitle?: string | null
          text_color?: string | null
          type?: string
          updated_at?: string
        }
        Update: {
          badge_text?: string | null
          bg_color?: string | null
          bg_gradient?: string | null
          button_text?: string | null
          button_url?: string | null
          created_at?: string
          font_family?: string | null
          font_size?: string | null
          font_weight?: string | null
          heading?: string | null
          id?: string
          is_active?: boolean
          is_published?: boolean
          letter_spacing?: string | null
          media_type?: string | null
          media_value?: string | null
          name?: string
          phrase_text?: string | null
          placement?: string
          subtitle?: string | null
          text_color?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: []
      }
      landing_settings: {
        Row: {
          cta_primary_text: string
          cta_primary_url: string
          cta_secondary_text: string
          cta_secondary_url: string
          dark_mode_enabled: boolean
          footer_brand_description: string | null
          footer_copyright: string | null
          footer_disclaimer: string | null
          footer_location: string | null
          footer_support_hours: string | null
          footer_support_text: string | null
          footer_support_url: string | null
          hero_badge_text: string | null
          hero_card_color: string | null
          hero_carousel_enabled: boolean
          hero_guarantee_1: string | null
          hero_guarantee_2: string | null
          hero_guarantee_3: string | null
          hero_image_url: string | null
          hero_subtitle: string
          hero_title: string
          id: number
          theme_color: string
          updated_at: string
        }
        Insert: {
          cta_primary_text?: string
          cta_primary_url?: string
          cta_secondary_text?: string
          cta_secondary_url?: string
          dark_mode_enabled?: boolean
          footer_brand_description?: string | null
          footer_copyright?: string | null
          footer_disclaimer?: string | null
          footer_location?: string | null
          footer_support_hours?: string | null
          footer_support_text?: string | null
          footer_support_url?: string | null
          hero_badge_text?: string | null
          hero_card_color?: string | null
          hero_carousel_enabled?: boolean
          hero_guarantee_1?: string | null
          hero_guarantee_2?: string | null
          hero_guarantee_3?: string | null
          hero_image_url?: string | null
          hero_subtitle?: string
          hero_title?: string
          id?: number
          theme_color?: string
          updated_at?: string
        }
        Update: {
          cta_primary_text?: string
          cta_primary_url?: string
          cta_secondary_text?: string
          cta_secondary_url?: string
          dark_mode_enabled?: boolean
          footer_brand_description?: string | null
          footer_copyright?: string | null
          footer_disclaimer?: string | null
          footer_location?: string | null
          footer_support_hours?: string | null
          footer_support_text?: string | null
          footer_support_url?: string | null
          hero_badge_text?: string | null
          hero_card_color?: string | null
          hero_carousel_enabled?: boolean
          hero_guarantee_1?: string | null
          hero_guarantee_2?: string | null
          hero_guarantee_3?: string | null
          hero_image_url?: string | null
          hero_subtitle?: string
          hero_title?: string
          id?: number
          theme_color?: string
          updated_at?: string
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          fan_id: string
          id: string
          note: string | null
          source_id: string
          source_type: string
          status: Database["public"]["Enums"]["ledger_status"]
          type: Database["public"]["Enums"]["ledger_type"]
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          fan_id: string
          id?: string
          note?: string | null
          source_id: string
          source_type: string
          status?: Database["public"]["Enums"]["ledger_status"]
          type: Database["public"]["Enums"]["ledger_type"]
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          fan_id?: string
          id?: string
          note?: string | null
          source_id?: string
          source_type?: string
          status?: Database["public"]["Enums"]["ledger_status"]
          type?: Database["public"]["Enums"]["ledger_type"]
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ledger_hold_resolutions: {
        Row: {
          action: string
          created_at: string
          id: string
          ledger_id: string
          note: string
          resolved_by: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: string
          ledger_id: string
          note: string
          resolved_by: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: string
          ledger_id?: string
          note?: string
          resolved_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "ledger_hold_resolutions_ledger_id_fkey"
            columns: ["ledger_id"]
            isOneToOne: true
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_hold_resolutions_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      login_modal_slides: {
        Row: {
          created_at: string
          created_by: string | null
          cta_label: string
          cta_url: string
          ends_at: string | null
          id: string
          image_url: string | null
          position: number
          starts_at: string
          status: string
          subtitle: string | null
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          cta_label?: string
          cta_url: string
          ends_at?: string | null
          id?: string
          image_url?: string | null
          position: number
          starts_at?: string
          status?: string
          subtitle?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          cta_label?: string
          cta_url?: string
          ends_at?: string | null
          id?: string
          image_url?: string | null
          position?: number
          starts_at?: string
          status?: string
          subtitle?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      mfa_recovery_codes: {
        Row: {
          code_hash: string
          created_at: string
          id: string
          used_at: string | null
          user_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      notification_outbox: {
        Row: {
          attempts: number
          channel: string
          created_at: string
          error: string | null
          id: string
          next_attempt_at: string
          notification_id: string
          sent_at: string | null
          status: string
        }
        Insert: {
          attempts?: number
          channel: string
          created_at?: string
          error?: string | null
          id?: string
          next_attempt_at?: string
          notification_id: string
          sent_at?: string | null
          status?: string
        }
        Update: {
          attempts?: number
          channel?: string
          created_at?: string
          error?: string | null
          id?: string
          next_attempt_at?: string
          notification_id?: string
          sent_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_outbox_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          data: Json | null
          dedup_key: string
          id: string
          read_at: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          data?: Json | null
          dedup_key: string
          id?: string
          read_at?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json | null
          dedup_key?: string
          id?: string
          read_at?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      players: {
        Row: {
          age: number | null
          bio: string | null
          created_at: string
          height: string | null
          id: string
          instagram_url: string | null
          is_active: boolean
          is_star: boolean
          jersey_number: number
          name: string
          nationality: string | null
          position: string
        }
        Insert: {
          age?: number | null
          bio?: string | null
          created_at?: string
          height?: string | null
          id?: string
          instagram_url?: string | null
          is_active?: boolean
          is_star?: boolean
          jersey_number: number
          name: string
          nationality?: string | null
          position: string
        }
        Update: {
          age?: number | null
          bio?: string | null
          created_at?: string
          height?: string | null
          id?: string
          instagram_url?: string | null
          is_active?: boolean
          is_star?: boolean
          jersey_number?: number
          name?: string
          nationality?: string | null
          position?: string
        }
        Relationships: []
      }
      policy_documents: {
        Row: {
          content_markdown: string
          created_at: string
          id: string
          is_active: boolean
          published_at: string
          slug: string
          updated_at: string | null
          version: string
        }
        Insert: {
          content_markdown: string
          created_at?: string
          id?: string
          is_active?: boolean
          published_at?: string
          slug: string
          updated_at?: string | null
          version: string
        }
        Update: {
          content_markdown?: string
          created_at?: string
          id?: string
          is_active?: boolean
          published_at?: string
          slug?: string
          updated_at?: string | null
          version?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          active: boolean
          category: Database["public"]["Enums"]["product_category"]
          cost_pearls: number
          created_at: string
          description: string | null
          id: string
          images: string[] | null
          name: string
          stock: number
          valid_from: string
          valid_until: string | null
          variants: Json | null
        }
        Insert: {
          active?: boolean
          category?: Database["public"]["Enums"]["product_category"]
          cost_pearls: number
          created_at?: string
          description?: string | null
          id?: string
          images?: string[] | null
          name: string
          stock?: number
          valid_from?: string
          valid_until?: string | null
          variants?: Json | null
        }
        Update: {
          active?: boolean
          category?: Database["public"]["Enums"]["product_category"]
          cost_pearls?: number
          created_at?: string
          description?: string | null
          id?: string
          images?: string[] | null
          name?: string
          stock?: number
          valid_from?: string
          valid_until?: string | null
          variants?: Json | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          birth_date: string | null
          cover_url: string | null
          created_at: string
          deleted_at: string | null
          display_name: string
          favorite_player_id: string | null
          gender: string | null
          id: string
          last_birth_date_change: string | null
          municipality: string | null
          notification_prefs: Json | null
          pearls_rules_accepted_at: string | null
          pearls_rules_version: string | null
          privacy_accepted_at: string | null
          privacy_version: string | null
          referral_source: string | null
          shirt_size: string | null
          status: Database["public"]["Enums"]["user_status"]
          terms_accepted_at: string | null
          terms_version: string | null
        }
        Insert: {
          avatar_url?: string | null
          birth_date?: string | null
          cover_url?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name: string
          favorite_player_id?: string | null
          gender?: string | null
          id: string
          last_birth_date_change?: string | null
          municipality?: string | null
          notification_prefs?: Json | null
          pearls_rules_accepted_at?: string | null
          pearls_rules_version?: string | null
          privacy_accepted_at?: string | null
          privacy_version?: string | null
          referral_source?: string | null
          shirt_size?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          terms_version?: string | null
        }
        Update: {
          avatar_url?: string | null
          birth_date?: string | null
          cover_url?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name?: string
          favorite_player_id?: string | null
          gender?: string | null
          id?: string
          last_birth_date_change?: string | null
          municipality?: string | null
          notification_prefs?: Json | null
          pearls_rules_accepted_at?: string | null
          pearls_rules_version?: string | null
          privacy_accepted_at?: string | null
          privacy_version?: string | null
          referral_source?: string | null
          shirt_size?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          terms_version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_favorite_player"
            columns: ["favorite_player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
        ]
      }
      push_subscriptions: {
        Row: {
          auth: string
          created_at: string
          disabled_at: string | null
          endpoint: string
          id: string
          last_success_at: string | null
          p256dh: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          auth: string
          created_at?: string
          disabled_at?: string | null
          endpoint: string
          id?: string
          last_success_at?: string | null
          p256dh: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          auth?: string
          created_at?: string
          disabled_at?: string | null
          endpoint?: string
          id?: string
          last_success_at?: string | null
          p256dh?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      rate_limits: {
        Row: {
          action: string
          request_count: number
          user_id: string
          window_start: string
        }
        Insert: {
          action: string
          request_count?: number
          user_id: string
          window_start: string
        }
        Update: {
          action?: string
          request_count?: number
          user_id?: string
          window_start?: string
        }
        Relationships: []
      }
      redemption_history: {
        Row: {
          changed_by: string | null
          created_at: string
          id: string
          new_status: Database["public"]["Enums"]["redemption_status"]
          note: string | null
          previous_status:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id: string
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_status: Database["public"]["Enums"]["redemption_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id: string
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["redemption_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "redemption_history_redemption_id_fkey"
            columns: ["redemption_id"]
            isOneToOne: false
            referencedRelation: "redemptions"
            referencedColumns: ["id"]
          },
        ]
      }
      redemptions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          code_hash: string
          cost_pearls: number
          created_at: string
          delivered_at: string | null
          delivered_by: string | null
          delivery_idempotency_key: string | null
          expires_at: string | null
          fan_id: string
          id: string
          idempotency_key: string
          product_id: string
          qr_key_id: string | null
          status: Database["public"]["Enums"]["redemption_status"]
          variant: string | null
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          code_hash: string
          cost_pearls: number
          created_at?: string
          delivered_at?: string | null
          delivered_by?: string | null
          delivery_idempotency_key?: string | null
          expires_at?: string | null
          fan_id: string
          id?: string
          idempotency_key: string
          product_id: string
          qr_key_id?: string | null
          status?: Database["public"]["Enums"]["redemption_status"]
          variant?: string | null
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          code_hash?: string
          cost_pearls?: number
          created_at?: string
          delivered_at?: string | null
          delivered_by?: string | null
          delivery_idempotency_key?: string | null
          expires_at?: string | null
          fan_id?: string
          id?: string
          idempotency_key?: string
          product_id?: string
          qr_key_id?: string | null
          status?: Database["public"]["Enums"]["redemption_status"]
          variant?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "redemptions_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "redemptions_delivered_by_fkey"
            columns: ["delivered_by"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "redemptions_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "redemptions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      risk_flags: {
        Row: {
          created_at: string
          fan_id: string
          id: string
          reason: string
          resolved: boolean
          severity: Database["public"]["Enums"]["risk_severity"]
        }
        Insert: {
          created_at?: string
          fan_id: string
          id?: string
          reason: string
          resolved?: boolean
          severity?: Database["public"]["Enums"]["risk_severity"]
        }
        Update: {
          created_at?: string
          fan_id?: string
          id?: string
          reason?: string
          resolved?: boolean
          severity?: Database["public"]["Enums"]["risk_severity"]
        }
        Relationships: [
          {
            foreignKeyName: "risk_flags_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      risk_settings: {
        Row: {
          description: string | null
          id: string
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          description?: string | null
          id?: string
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          description?: string | null
          id?: string
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      scan_events: {
        Row: {
          code_hash: string
          created_at: string
          device: string | null
          id: string
          latitude: number | null
          longitude: number | null
          result: Database["public"]["Enums"]["scan_result"]
          staff_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string
          device?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          result: Database["public"]["Enums"]["scan_result"]
          staff_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string
          device?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          result?: Database["public"]["Enums"]["scan_result"]
          staff_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scan_events_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
        ]
      }
      segments: {
        Row: {
          created_at: string
          filters: Json
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          filters?: Json
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          filters?: Json
          id?: string
          name?: string
        }
        Relationships: []
      }
      site_announcements: {
        Row: {
          created_at: string
          ends_at: string | null
          id: string
          is_published: boolean
          link_url: string | null
          message: string
          starts_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          id?: string
          is_published?: boolean
          link_url?: string | null
          message: string
          starts_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          id?: string
          is_published?: boolean
          link_url?: string | null
          message?: string
          starts_at?: string
        }
        Relationships: []
      }
      site_stats: {
        Row: {
          created_at: string
          id: string
          is_published: boolean
          is_sponsor: boolean
          label: string
          logo_url: string | null
          note: string | null
          order_index: number
          value: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_published?: boolean
          is_sponsor?: boolean
          label: string
          logo_url?: string | null
          note?: string | null
          order_index?: number
          value: string
        }
        Update: {
          created_at?: string
          id?: string
          is_published?: boolean
          is_sponsor?: boolean
          label?: string
          logo_url?: string | null
          note?: string | null
          order_index?: number
          value?: string
        }
        Relationships: []
      }
      site_team_members: {
        Row: {
          created_at: string
          group_category: string
          id: string
          is_published: boolean
          name: string
          order_index: number
          photo_url: string | null
          role: string
        }
        Insert: {
          created_at?: string
          group_category: string
          id?: string
          is_published?: boolean
          name: string
          order_index?: number
          photo_url?: string | null
          role: string
        }
        Update: {
          created_at?: string
          group_category?: string
          id?: string
          is_published?: boolean
          name?: string
          order_index?: number
          photo_url?: string | null
          role?: string
        }
        Relationships: []
      }
      social_links: {
        Row: {
          created_at: string
          icon: string | null
          id: string
          is_published: boolean
          label: string
          order_index: number
          platform: string
          url: string
        }
        Insert: {
          created_at?: string
          icon?: string | null
          id?: string
          is_published?: boolean
          label: string
          order_index?: number
          platform: string
          url: string
        }
        Update: {
          created_at?: string
          icon?: string | null
          id?: string
          is_published?: boolean
          label?: string
          order_index?: number
          platform?: string
          url?: string
        }
        Relationships: []
      }
      sponsor_videos: {
        Row: {
          created_at: string
          cta_text: string
          drive_file_id: string
          id: string
          is_active: boolean
          min_seconds: number
          order_index: number
          redirect_url: string | null
          reward_points: number
          sponsor_name: string | null
          title: string
          updated_at: string
          video_url: string
        }
        Insert: {
          created_at?: string
          cta_text?: string
          drive_file_id: string
          id?: string
          is_active?: boolean
          min_seconds?: number
          order_index?: number
          redirect_url?: string | null
          reward_points?: number
          sponsor_name?: string | null
          title: string
          updated_at?: string
          video_url: string
        }
        Update: {
          created_at?: string
          cta_text?: string
          drive_file_id?: string
          id?: string
          is_active?: boolean
          min_seconds?: number
          order_index?: number
          redirect_url?: string | null
          reward_points?: number
          sponsor_name?: string | null
          title?: string
          updated_at?: string
          video_url?: string
        }
        Relationships: []
      }
      staff_members: {
        Row: {
          active: boolean
          created_at: string
          role: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          role?: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          role?: Database["public"]["Enums"]["staff_role"]
          user_id?: string
        }
        Relationships: []
      }
      standings: {
        Row: {
          created_at: string
          games_played: number
          id: string
          logo_url: string | null
          losses: number
          order_index: number
          points: number
          team_name: string
          wins: number
        }
        Insert: {
          created_at?: string
          games_played?: number
          id?: string
          logo_url?: string | null
          losses?: number
          order_index?: number
          points?: number
          team_name: string
          wins?: number
        }
        Update: {
          created_at?: string
          games_played?: number
          id?: string
          logo_url?: string | null
          losses?: number
          order_index?: number
          points?: number
          team_name?: string
          wins?: number
        }
        Relationships: []
      }
      system_alerts: {
        Row: {
          alert_type: string
          created_at: string
          id: string
          message: string
          metadata: Json | null
          resolved: boolean
          resolved_at: string | null
          resolved_by: string | null
          severity: string
        }
        Insert: {
          alert_type: string
          created_at?: string
          id?: string
          message: string
          metadata?: Json | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity: string
        }
        Update: {
          alert_type?: string
          created_at?: string
          id?: string
          message?: string
          metadata?: Json | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: string
        }
        Relationships: [
          {
            foreignKeyName: "system_alerts_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_attempts: {
        Row: {
          answers: Json | null
          expires_at: string
          fan_id: string
          id: string
          idempotency_key: string
          pearls_awarded: number
          score: number
          seed: number
          started_at: string
          submitted_at: string | null
          suspicious: boolean
          trivia_id: string
        }
        Insert: {
          answers?: Json | null
          expires_at: string
          fan_id: string
          id?: string
          idempotency_key: string
          pearls_awarded?: number
          score?: number
          seed?: number
          started_at?: string
          submitted_at?: string | null
          suspicious?: boolean
          trivia_id: string
        }
        Update: {
          answers?: Json | null
          expires_at?: string
          fan_id?: string
          id?: string
          idempotency_key?: string
          pearls_awarded?: number
          score?: number
          seed?: number
          started_at?: string
          submitted_at?: string | null
          suspicious?: boolean
          trivia_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_attempts_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_attempts_trivia_id_fkey"
            columns: ["trivia_id"]
            isOneToOne: false
            referencedRelation: "trivias"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_options: {
        Row: {
          id: string
          is_correct: boolean
          option_text: string
          question_id: string
        }
        Insert: {
          id?: string
          is_correct?: boolean
          option_text: string
          question_id: string
        }
        Update: {
          id?: string
          is_correct?: boolean
          option_text?: string
          question_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_options_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "trivia_questions"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_questions: {
        Row: {
          created_at: string
          id: string
          order_index: number
          points: number
          question_text: string
          trivia_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          order_index?: number
          points?: number
          question_text: string
          trivia_id: string
        }
        Update: {
          created_at?: string
          id?: string
          order_index?: number
          points?: number
          question_text?: string
          trivia_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_questions_trivia_id_fkey"
            columns: ["trivia_id"]
            isOneToOne: false
            referencedRelation: "trivias"
            referencedColumns: ["id"]
          },
        ]
      }
      trivias: {
        Row: {
          created_at: string
          description: string | null
          ends_at: string
          id: string
          max_attempts: number
          reward_rules: Json
          starts_at: string
          status: Database["public"]["Enums"]["trivia_status"]
          target_segment_id: string | null
          time_limit_seconds: number
          title: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          ends_at: string
          id?: string
          max_attempts?: number
          reward_rules?: Json
          starts_at: string
          status?: Database["public"]["Enums"]["trivia_status"]
          target_segment_id?: string | null
          time_limit_seconds?: number
          title: string
        }
        Update: {
          created_at?: string
          description?: string | null
          ends_at?: string
          id?: string
          max_attempts?: number
          reward_rules?: Json
          starts_at?: string
          status?: Database["public"]["Enums"]["trivia_status"]
          target_segment_id?: string | null
          time_limit_seconds?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivias_target_segment_id_fkey"
            columns: ["target_segment_id"]
            isOneToOne: false
            referencedRelation: "segments"
            referencedColumns: ["id"]
          },
        ]
      }
      wallets: {
        Row: {
          balance_cache: number
          fan_id: string
          updated_at: string
        }
        Insert: {
          balance_cache?: number
          fan_id: string
          updated_at?: string
        }
        Update: {
          balance_cache?: number
          fan_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallets_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      mv_daily_economy_stats: {
        Row: {
          entry_date: string | null
          pearls_held: number | null
          pearls_issued: number | null
          pearls_spent: number | null
        }
        Relationships: []
      }
      mv_daily_fan_activity: {
        Row: {
          activity_date: string | null
          fan_id: string | null
          pearls_earned: number | null
          trivias_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "trivia_attempts_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      mv_demographics: {
        Row: {
          age_group: string | null
          fan_count: number | null
          gender: string | null
          municipality: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      accept_terms: { Args: never; Returns: Json }
      activate_landing_cta: { Args: { p_id: string }; Returns: undefined }
      adjust_stock: {
        Args: { p_delta: number; p_product_id: string; p_reason: string }
        Returns: Json
      }
      admin_adjust_pearls: {
        Args: { p_amount: number; p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_archive_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_delete_game: { Args: { p_game_id: string }; Returns: Json }
      admin_delete_login_modal_slide: {
        Args: { p_slide_id: string }
        Returns: Json
      }
      admin_delete_player: { Args: { p_player_id: string }; Returns: Json }
      admin_duplicate_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_get_fan: { Args: { p_fan_id: string }; Returns: Json }
      admin_get_trivia_with_options: {
        Args: { p_trivia_id: string }
        Returns: Json
      }
      admin_list_fans: {
        Args: {
          p_age_max?: number
          p_age_min?: number
          p_cursor?: string
          p_favorite_player_id?: string
          p_inactive_days?: number
          p_limit?: number
          p_municipality?: string
          p_search?: string
          p_status?: Database["public"]["Enums"]["user_status"]
        }
        Returns: Json
      }
      admin_publish_policy: {
        Args: { p_content: string; p_slug: string; p_version: string }
        Returns: Json
      }
      admin_publish_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_reactivate_fan: {
        Args: { p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_release_held_pearls: {
        Args: { p_ledger_id: string; p_note: string }
        Returns: Json
      }
      admin_reorder_login_modal_slides: {
        Args: { p_slide_ids: string[] }
        Returns: Json
      }
      admin_resolve_redemption_issue: {
        Args: { p_action: string; p_note: string; p_redemption_id: string }
        Returns: Json
      }
      admin_resolve_risk_flag: {
        Args: { p_flag_id: string; p_note: string }
        Returns: Json
      }
      admin_revoke_held_pearls: {
        Args: { p_ledger_id: string; p_note: string }
        Returns: Json
      }
      admin_risk_queue: { Args: { p_resolved?: boolean }; Returns: Json }
      admin_suspend_fan: {
        Args: { p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_toggle_staff_active: {
        Args: { p_active: boolean; p_target_id: string }
        Returns: Json
      }
      admin_update_ads_settings: { Args: { p_settings: Json }; Returns: Json }
      admin_update_birth_date: {
        Args: { p_birth_date: string; p_reason: string; p_user_id: string }
        Returns: Json
      }
      admin_update_economy_settings: {
        Args: { p_settings: Json }
        Returns: Json
      }
      admin_update_staff_role: {
        Args: {
          p_new_role: Database["public"]["Enums"]["staff_role"]
          p_target_id: string
        }
        Returns: Json
      }
      admin_upsert_game: { Args: { p_game: Json }; Returns: Json }
      admin_upsert_login_modal_slide: {
        Args: {
          p_cta_label: string
          p_cta_url: string
          p_ends_at: string
          p_id: string
          p_image_url: string
          p_position: number
          p_starts_at: string
          p_status: string
          p_subtitle: string
          p_title: string
        }
        Returns: Json
      }
      admin_upsert_player: { Args: { p_player: Json }; Returns: Json }
      admin_upsert_product: { Args: { p_product: Json }; Returns: Json }
      admin_upsert_segment: { Args: { p_segment: Json }; Returns: Json }
      admin_upsert_trivia: {
        Args: { p_questions?: Json; p_trivia: Json }
        Returns: Json
      }
      analytics_active_users: {
        Args: {
          p_end_date?: string
          p_granularity?: string
          p_start_date?: string
        }
        Returns: Json
      }
      analytics_ads: { Args: { p_from?: string; p_to?: string }; Returns: Json }
      analytics_demographics: { Args: never; Returns: Json }
      analytics_economy: { Args: never; Returns: Json }
      analytics_engagement_hours: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_funnel: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_overview: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_products: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_top_fans: {
        Args: { p_end_date?: string; p_limit?: number; p_start_date?: string }
        Returns: Json
      }
      analytics_trivias: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      approve_redemption: {
        Args: { p_note?: string; p_redemption_id: string }
        Returns: Json
      }
      assert_active_verified_fan:
        | { Args: never; Returns: string }
        | { Args: { p_user_id: string }; Returns: string }
      assert_admin: { Args: never; Returns: boolean }
      assert_staff: { Args: never; Returns: boolean }
      audit_search: {
        Args: {
          p_action?: string
          p_actor_id?: string
          p_cursor?: string
          p_entity?: string
          p_from?: string
          p_limit?: number
          p_to?: string
        }
        Returns: Json
      }
      calculate_and_apply_streak_bonus: {
        Args: { p_fan_id: string }
        Returns: Json
      }
      cancel_ad_session: {
        Args: { p_reason: string; p_session_id: string }
        Returns: Json
      }
      cancel_redemption: {
        Args: { p_reason?: string; p_redemption_id: string }
        Returns: Json
      }
      check_email_exists: { Args: { p_email: string }; Returns: boolean }
      check_in_redemption: {
        Args: {
          p_idempotency_key: string
          p_note?: string
          p_redemption_id: string
        }
        Returns: Json
      }
      check_rate_limit: {
        Args: {
          p_action: string
          p_max: number
          p_user_id: string
          p_window_seconds: number
        }
        Returns: undefined
      }
      claim_birthday_bonus: { Args: never; Returns: Json }
      claim_video_points: { Args: { p_video_id: string }; Returns: Json }
      clean_test_records: { Args: never; Returns: undefined }
      complete_ad_session: {
        Args: { p_idempotency_key: string; p_session_id: string }
        Returns: Json
      }
      compute_redemption_code_hash: {
        Args: { p_code_or_hash: string }
        Returns: string
      }
      compute_risk: { Args: { p_fan_id: string }; Returns: undefined }
      confirm_test_user_email: { Args: { p_email: string }; Returns: undefined }
      create_notification: {
        Args: {
          p_body: string
          p_data?: Json
          p_dedup_key?: string
          p_title: string
          p_type: string
          p_user_id: string
        }
        Returns: string
      }
      create_security_notification: {
        Args: { p_body: string; p_title: string; p_user_id: string }
        Returns: undefined
      }
      cron_cleanup_old_notifications: { Args: never; Returns: undefined }
      cron_notify_expiring_redemptions: { Args: never; Returns: undefined }
      cron_notify_match_day: { Args: never; Returns: undefined }
      cron_notify_new_trivias: { Args: never; Returns: undefined }
      delete_my_account: { Args: never; Returns: Json }
      deliver_redemption:
        | { Args: { p_code: string; p_note?: string }; Returns: Json }
        | {
            Args: {
              p_idempotency_key: string
              p_note?: string
              p_redemption_id: string
            }
            Returns: Json
          }
      enqueue_birthday_notifications: {
        Args: { p_now?: string }
        Returns: Json
      }
      ensure_profile: { Args: never; Returns: Json }
      generate_redemption_code: {
        Args: { p_redemption_id: string }
        Returns: string
      }
      get_active_legal_versions: { Args: never; Returns: Json }
      get_ads_progress: { Args: never; Returns: Json }
      get_attempt_questions: { Args: { p_attempt_id: string }; Returns: Json }
      get_birthday_card: { Args: never; Returns: Json }
      get_daily_video_progress: { Args: never; Returns: Json }
      get_leaderboard: { Args: { p_period?: string }; Returns: Json }
      get_login_modal: { Args: never; Returns: Json }
      get_redemption_qr: { Args: { p_redemption_id: string }; Returns: Json }
      get_streak_info: { Args: { p_fan_id: string }; Returns: Json }
      health_check: { Args: never; Returns: Json }
      helper_generate_code_with_key: {
        Args: { p_key_id: string; p_redemption_id: string }
        Returns: string
      }
      home_summary: { Args: never; Returns: Json }
      import_ad_report: {
        Args: { p_day: string; p_impressions: number; p_notes?: string }
        Returns: Json
      }
      is_admin: { Args: { user_id: string }; Returns: boolean }
      is_admin_check: { Args: never; Returns: boolean }
      is_staff_or_admin: { Args: { user_id: string }; Returns: boolean }
      mark_all_notifications_read: { Args: never; Returns: Json }
      mark_notification_read: {
        Args: { p_notification_id: string }
        Returns: Json
      }
      parse_instagram_shortcode: { Args: { p_url: string }; Returns: string }
      purge_auth_identities: { Args: { p_user_id: string }; Returns: Json }
      purge_fraud_telemetry: { Args: never; Returns: undefined }
      reconcile_wallets: {
        Args: never
        Returns: {
          balance_cache: number
          computed_balance: number
          difference: number
          fan_id: string
        }[]
      }
      redeem_product: {
        Args: {
          p_idempotency_key: string
          p_product_id: string
          p_variant: string
        }
        Returns: Json
      }
      refresh_analytics_materialized_views: { Args: never; Returns: undefined }
      register_email_send_attempt: { Args: never; Returns: Json }
      register_push_subscription: {
        Args: {
          p_auth: string
          p_endpoint: string
          p_p256dh: string
          p_user_agent?: string
        }
        Returns: Json
      }
      reject_redemption: {
        Args: { p_reason: string; p_redemption_id: string }
        Returns: Json
      }
      report_redemption_issue:
        | { Args: { p_reason: string; p_redemption_id: string }; Returns: Json }
        | {
            Args: { p_note?: string; p_reason: string; p_redemption_id: string }
            Returns: Json
          }
      run_daily_wallet_reconciliation: { Args: never; Returns: undefined }
      save_mfa_recovery_code_hashes: {
        Args: { p_hashes: string[] }
        Returns: Json
      }
      seed_analytics_performance_data: {
        Args: { p_num_fans?: number; p_num_ledger?: number }
        Returns: Json
      }
      segment_count: { Args: { p_segment_id: string }; Returns: number }
      segment_members: {
        Args: { p_cursor?: string; p_limit?: number; p_segment_id: string }
        Returns: Json
      }
      send_test_birthday_notification: { Args: never; Returns: Json }
      set_birth_date: { Args: { p_birth_date: string }; Returns: Json }
      staff_redemption_queue: {
        Args: {
          p_cursor?: string
          p_limit?: number
          p_search?: string
          p_status?: string
        }
        Returns: {
          cost_pearls: number
          created_at: string
          delivered_at: string
          expires_at: string
          fan_avatar_url: string
          fan_display_name: string
          fan_id: string
          id: string
          product_category: Database["public"]["Enums"]["product_category"]
          product_id: string
          product_name: string
          status: Database["public"]["Enums"]["redemption_status"]
          variant: string
        }[]
      }
      staff_search_fans: {
        Args: { p_limit?: number; p_query: string }
        Returns: {
          avatar_url: string
          display_name: string
          id: string
          last_5_redemptions: Json
          pearl_balance: number
          status: string
        }[]
      }
      staff_upsert_product: { Args: { p_product: Json }; Returns: Json }
      staff_upsert_trivia:
        | { Args: { p_trivia: Json }; Returns: Json }
        | { Args: { p_questions?: Json; p_trivia: Json }; Returns: Json }
      start_ad_session: { Args: { p_idempotency_key?: string }; Returns: Json }
      start_trivia_attempt: {
        Args: { p_idempotency_key: string; p_trivia_id: string }
        Returns: Json
      }
      submit_trivia_attempt: {
        Args: {
          p_answers: Json
          p_attempt_id: string
          p_idempotency_key: string
        }
        Returns: Json
      }
      unregister_push_subscription: {
        Args: { p_endpoint: string }
        Returns: Json
      }
      update_birth_date: { Args: { p_birth_date: string }; Returns: Json }
      update_birthday_settings: {
        Args: {
          p_bonus_pearls: number
          p_enabled: boolean
          p_grace_days: number
          p_image_url: string
          p_message: string
          p_send_hour: number
          p_title: string
        }
        Returns: Json
      }
      update_display_name: { Args: { p_display_name: string }; Returns: Json }
      user_has_verified_mfa: { Args: { p_uid: string }; Returns: boolean }
      validate_crockford_base32_checksum: {
        Args: { p_code: string }
        Returns: boolean
      }
      validate_login_modal_urls: {
        Args: { p_cta_url: string; p_image_url: string }
        Returns: undefined
      }
      verify_redemption_code: {
        Args: { p_code: string; p_device?: string }
        Returns: Json
      }
      wallet_ledger: {
        Args: { p_cursor?: string; p_limit?: number; p_type?: string }
        Returns: Json
      }
      wallet_summary: { Args: never; Returns: Json }
    }
    Enums: {
      game_status: "scheduled" | "live" | "finished" | "cancelled"
      ledger_status: "confirmed" | "held" | "revoked"
      ledger_type:
        | "trivia_reward"
        | "redemption"
        | "refund"
        | "admin_adjustment"
        | "bonus"
        | "streak_bonus"
        | "birthday_bonus"
        | "ad_reward"
      product_category: "physical" | "experience" | "raffle"
      redemption_status:
        | "pending"
        | "approved"
        | "scheduled"
        | "delivered"
        | "completed"
        | "cancelled"
        | "rejected"
        | "issue"
        | "expired"
      risk_severity: "low" | "medium" | "high"
      scan_result: "success" | "invalid" | "already_delivered" | "expired"
      staff_role: "staff" | "admin"
      trivia_status: "draft" | "published" | "archived"
      user_status: "active" | "suspended" | "deleted"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      game_status: ["scheduled", "live", "finished", "cancelled"],
      ledger_status: ["confirmed", "held", "revoked"],
      ledger_type: [
        "trivia_reward",
        "redemption",
        "refund",
        "admin_adjustment",
        "bonus",
        "streak_bonus",
        "birthday_bonus",
        "ad_reward",
      ],
      product_category: ["physical", "experience", "raffle"],
      redemption_status: [
        "pending",
        "approved",
        "scheduled",
        "delivered",
        "completed",
        "cancelled",
        "rejected",
        "issue",
        "expired",
      ],
      risk_severity: ["low", "medium", "high"],
      scan_result: ["success", "invalid", "already_delivered", "expired"],
      staff_role: ["staff", "admin"],
      trivia_status: ["draft", "published", "archived"],
      user_status: ["active", "suspended", "deleted"],
    },
  },
} as const
