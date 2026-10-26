export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: any }
  | any[]

export type UserStatus = 'active' | 'suspended'
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

export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile; Insert: Partial<Profile>; Update: Partial<Profile>; Relationships: [] }
      staff_members: { Row: StaffMember; Insert: Partial<StaffMember>; Update: Partial<StaffMember>; Relationships: [] }
      wallets: { Row: Wallet; Insert: Partial<Wallet>; Update: Partial<Wallet>; Relationships: [] }
      ledger_entries: { Row: LedgerEntry; Insert: Partial<LedgerEntry>; Update: Partial<LedgerEntry>; Relationships: [] }
      trivias: { Row: Trivia; Insert: Partial<Trivia>; Update: Partial<Trivia>; Relationships: [] }
      trivia_questions: { Row: TriviaQuestion; Insert: Partial<TriviaQuestion>; Update: Partial<TriviaQuestion>; Relationships: [] }
      trivia_options: { Row: TriviaOption; Insert: Partial<TriviaOption>; Update: Partial<TriviaOption>; Relationships: [] }
      trivia_attempts: { Row: TriviaAttempt; Insert: Partial<TriviaAttempt>; Update: Partial<TriviaAttempt>; Relationships: [] }
      products: { Row: Product; Insert: Partial<Product>; Update: Partial<Product>; Relationships: [] }
      redemptions: { Row: Redemption; Insert: Partial<Redemption>; Update: Partial<Redemption>; Relationships: [] }
      redemption_history: { Row: RedemptionHistory; Insert: Partial<RedemptionHistory>; Update: Partial<RedemptionHistory>; Relationships: [] }
      scan_events: { Row: ScanEvent; Insert: Partial<ScanEvent>; Update: Partial<ScanEvent>; Relationships: [] }
      players: { Row: Player; Insert: Partial<Player>; Update: Partial<Player>; Relationships: [] }
      games: { Row: Game; Insert: Partial<Game>; Update: Partial<Game>; Relationships: [] }
      segments: { Row: Segment; Insert: Partial<Segment>; Update: Partial<Segment>; Relationships: [] }
      economy_settings: { Row: EconomySettings; Insert: Partial<EconomySettings>; Update: Partial<EconomySettings>; Relationships: [] }
      risk_flags: { Row: RiskFlag; Insert: Partial<RiskFlag>; Update: Partial<RiskFlag>; Relationships: [] }
      audit_log: { Row: AuditLog; Insert: Partial<AuditLog>; Update: Partial<AuditLog>; Relationships: [] }
      site_announcements: { Row: SiteAnnouncement; Insert: Partial<SiteAnnouncement>; Update: Partial<SiteAnnouncement>; Relationships: [] }
      carousel_slides: { Row: CarouselSlideRow; Insert: Partial<CarouselSlideRow>; Update: Partial<CarouselSlideRow>; Relationships: [] }
      history_milestones: { Row: HistoryMilestone; Insert: Partial<HistoryMilestone>; Update: Partial<HistoryMilestone>; Relationships: [] }
      site_team_members: { Row: SiteTeamMember; Insert: Partial<SiteTeamMember>; Update: Partial<SiteTeamMember>; Relationships: [] }
      faqs: { Row: FaqItemRow; Insert: Partial<FaqItemRow>; Update: Partial<FaqItemRow>; Relationships: [] }
      site_stats: { Row: SiteStat; Insert: Partial<SiteStat>; Update: Partial<SiteStat>; Relationships: [] }
      social_links: { Row: SocialLink; Insert: Partial<SocialLink>; Update: Partial<SocialLink>; Relationships: [] }
      policy_documents: { Row: PolicyDocument; Insert: Partial<PolicyDocument>; Update: Partial<PolicyDocument>; Relationships: [] }
      birthday_settings: { Row: BirthdaySettings; Insert: Partial<BirthdaySettings>; Update: Partial<BirthdaySettings>; Relationships: [] }
      sponsor_videos: { Row: SponsorVideo; Insert: Partial<SponsorVideo>; Update: Partial<SponsorVideo>; Relationships: [] }
      landing_ctas: { Row: LandingCta; Insert: Partial<LandingCta>; Update: Partial<LandingCta>; Relationships: [] }
      landing_settings: { Row: LandingSettings; Insert: Partial<LandingSettings>; Update: Partial<LandingSettings>; Relationships: [] }
      hero_carousel_slides: { Row: HeroCarouselSlide; Insert: Partial<HeroCarouselSlide>; Update: Partial<HeroCarouselSlide>; Relationships: [] }
      guess_player_challenges: { Row: GuessPlayerChallenge; Insert: Partial<GuessPlayerChallenge>; Update: Partial<GuessPlayerChallenge>; Relationships: [] }
      guess_player_votes: { Row: GuessPlayerVote; Insert: Partial<GuessPlayerVote>; Update: Partial<GuessPlayerVote>; Relationships: [] }
    }
    Views: Record<string, any>
    Functions: {
      claim_video_points: {
        Args: { p_video_id: string }
        Returns: {
          success: boolean
          already_claimed: boolean
          message: string
          balance: number
          points_awarded: number
        }
      }
      [key: string]: {
        Args: any
        Returns: any
      }
    }
    Enums: Record<string, any>
    CompositeTypes: Record<string, any>
  }
}
