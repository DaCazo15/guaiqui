-- ============================================================================
-- Migration: 20261016000001_schema_and_types.sql
-- Description: Consolidated base database schema, extensions, enums, tables,
--              constraints, indexes, and storage buckets for Guaiqueríes Platform.
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE user_status AS ENUM ('active', 'suspended', 'deleted');
CREATE TYPE staff_role AS ENUM ('staff', 'admin');
CREATE TYPE ledger_type AS ENUM ('trivia_reward', 'redemption', 'refund', 'admin_adjustment', 'bonus', 'streak_bonus', 'birthday_bonus', 'ad_reward');
CREATE TYPE ledger_status AS ENUM ('confirmed', 'held', 'revoked');
CREATE TYPE trivia_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE product_category AS ENUM ('physical', 'experience', 'raffle');
CREATE TYPE redemption_status AS ENUM ('pending', 'approved', 'scheduled', 'delivered', 'completed', 'cancelled', 'rejected', 'issue', 'expired');
CREATE TYPE scan_result AS ENUM ('success', 'invalid', 'already_delivered', 'expired');
CREATE TYPE game_status AS ENUM ('scheduled', 'live', 'finished', 'cancelled');
CREATE TYPE risk_severity AS ENUM ('low', 'medium', 'high');

-- ============================================================================
-- TABLES DEFINITION
-- ============================================================================

CREATE TABLE public.players (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    jersey_number INT NOT NULL,
    position TEXT NOT NULL,
    height TEXT,
    age INT,
    nationality TEXT DEFAULT 'Venezuela'::text,
    bio TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    is_star BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT players_pkey PRIMARY KEY (id)
);

CREATE TABLE public.segments (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    filters JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT segments_pkey PRIMARY KEY (id)
);

CREATE TABLE public.profiles (
    id UUID NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    municipality TEXT,
    birth_date DATE,
    gender TEXT,
    favorite_player_id UUID,
    shirt_size TEXT,
    referral_source TEXT,
    notification_prefs JSONB DEFAULT '{"push": true, "email": true}'::jsonb,
    status user_status DEFAULT 'active'::user_status NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    terms_accepted_at TIMESTAMPTZ,
    terms_version TEXT DEFAULT '1.0'::text,
    privacy_accepted_at TIMESTAMPTZ,
    privacy_version TEXT DEFAULT '1.0'::text,
    pearls_rules_accepted_at TIMESTAMPTZ,
    pearls_rules_version TEXT DEFAULT '1.0'::text,
    deleted_at TIMESTAMPTZ,
    last_birth_date_change TIMESTAMPTZ,
    CONSTRAINT profiles_pkey PRIMARY KEY (id)
);

CREATE TABLE public.staff_members (
    user_id UUID NOT NULL,
    role staff_role DEFAULT 'staff'::staff_role NOT NULL,
    active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT staff_members_pkey PRIMARY KEY (user_id)
);

CREATE TABLE public.wallets (
    fan_id UUID NOT NULL,
    balance_cache INT DEFAULT 0 NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT wallets_pkey PRIMARY KEY (fan_id),
    CONSTRAINT wallets_balance_cache_check CHECK ((balance_cache >= 0))
);

CREATE TABLE public.ledger_entries (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    fan_id UUID NOT NULL,
    amount INT NOT NULL,
    type ledger_type NOT NULL,
    status ledger_status DEFAULT 'confirmed'::ledger_status NOT NULL,
    source_type TEXT NOT NULL,
    source_id TEXT NOT NULL,
    note TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT ledger_entries_pkey PRIMARY KEY (id)
);

CREATE TABLE public.ledger_hold_resolutions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    ledger_id UUID NOT NULL,
    action TEXT NOT NULL,
    note TEXT NOT NULL,
    resolved_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT ledger_hold_resolutions_pkey PRIMARY KEY (id),
    CONSTRAINT ledger_hold_resolutions_ledger_id_key UNIQUE (ledger_id),
    CONSTRAINT ledger_hold_resolutions_action_check CHECK ((action = ANY (ARRAY['release'::text, 'revoke'::text])))
);

CREATE TABLE public.games (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    opponent TEXT NOT NULL,
    location TEXT DEFAULT 'Gimnasio Ciudad de La Asunción'::text NOT NULL,
    game_date TIMESTAMPTZ NOT NULL,
    is_home BOOLEAN DEFAULT true NOT NULL,
    status game_status DEFAULT 'scheduled'::game_status NOT NULL,
    our_score INT DEFAULT 0,
    opponent_score INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT games_pkey PRIMARY KEY (id)
);

CREATE TABLE public.trivias (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    status trivia_status DEFAULT 'draft'::trivia_status NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    time_limit_seconds INT DEFAULT 60 NOT NULL,
    reward_rules JSONB DEFAULT '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb NOT NULL,
    max_attempts INT DEFAULT 1 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    target_segment_id UUID,
    CONSTRAINT trivias_pkey PRIMARY KEY (id)
);

CREATE TABLE public.trivia_questions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    trivia_id UUID NOT NULL,
    question_text TEXT NOT NULL,
    points INT DEFAULT 50 NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT trivia_questions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.trivia_options (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    question_id UUID NOT NULL,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT false NOT NULL,
    CONSTRAINT trivia_options_pkey PRIMARY KEY (id)
);

CREATE TABLE public.trivia_attempts (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    fan_id UUID NOT NULL,
    trivia_id UUID NOT NULL,
    started_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    submitted_at TIMESTAMPTZ,
    answers JSONB,
    score INT DEFAULT 0 NOT NULL,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    suspicious BOOLEAN DEFAULT false NOT NULL,
    seed INT DEFAULT 12345 NOT NULL,
    idempotency_key TEXT NOT NULL,
    CONSTRAINT trivia_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT uq_fan_trivia_attempt UNIQUE (fan_id, trivia_id, idempotency_key)
);

CREATE TABLE public.products (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category product_category DEFAULT 'physical'::product_category NOT NULL,
    cost_pearls INT NOT NULL,
    stock INT DEFAULT 0 NOT NULL,
    variants JSONB DEFAULT '[]'::jsonb,
    active BOOLEAN DEFAULT true NOT NULL,
    valid_from TIMESTAMPTZ DEFAULT now() NOT NULL,
    valid_until TIMESTAMPTZ,
    images TEXT[] DEFAULT ARRAY[]::text[],
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT products_pkey PRIMARY KEY (id),
    CONSTRAINT products_cost_pearls_check CHECK ((cost_pearls > 0)),
    CONSTRAINT products_stock_check CHECK ((stock >= 0))
);

CREATE TABLE public.redemptions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    fan_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant TEXT,
    cost_pearls INT NOT NULL,
    status redemption_status DEFAULT 'pending'::redemption_status NOT NULL,
    code_hash TEXT NOT NULL,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    delivered_by UUID,
    delivered_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    delivery_idempotency_key TEXT,
    qr_key_id TEXT DEFAULT 'v2'::text,
    CONSTRAINT redemptions_pkey PRIMARY KEY (id),
    CONSTRAINT redemptions_code_hash_key UNIQUE (code_hash),
    CONSTRAINT uq_fan_redemption_idempotency UNIQUE (fan_id, idempotency_key),
    CONSTRAINT redemptions_cost_pearls_check CHECK ((cost_pearls > 0))
);

CREATE TABLE public.redemption_history (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    redemption_id UUID NOT NULL,
    previous_status redemption_status,
    new_status redemption_status NOT NULL,
    changed_by UUID,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT redemption_history_pkey PRIMARY KEY (id)
);

CREATE TABLE public.scan_events (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    staff_id UUID NOT NULL,
    code_hash TEXT NOT NULL,
    result scan_result NOT NULL,
    device TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    latitude NUMERIC,
    longitude NUMERIC,
    CONSTRAINT scan_events_pkey PRIMARY KEY (id)
);

CREATE TABLE public.economy_settings (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    daily_pearl_cap INT DEFAULT 1000 NOT NULL,
    weekly_pearl_cap INT DEFAULT 5000 NOT NULL,
    streak_bonus_config JSONB DEFAULT '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ads_enabled BOOLEAN DEFAULT true NOT NULL,
    daily_ad_views INT DEFAULT 50 NOT NULL,
    block_size INT DEFAULT 10 NOT NULL,
    ad_min_seconds INT DEFAULT 6 NOT NULL,
    ad_min_account_age_days INT DEFAULT 3 NOT NULL,
    ad_min_trivias_completed INT DEFAULT 1 NOT NULL,
    CONSTRAINT economy_settings_pkey PRIMARY KEY (id)
);

CREATE TABLE public.risk_flags (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    fan_id UUID NOT NULL,
    reason TEXT NOT NULL,
    severity risk_severity DEFAULT 'medium'::risk_severity NOT NULL,
    resolved BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT risk_flags_pkey PRIMARY KEY (id)
);

CREATE TABLE public.risk_settings (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    key TEXT NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT risk_settings_pkey PRIMARY KEY (id),
    CONSTRAINT risk_settings_key_key UNIQUE (key)
);

CREATE TABLE public.audit_log (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    actor_id UUID,
    action TEXT NOT NULL,
    entity TEXT NOT NULL,
    entity_id TEXT,
    before JSONB,
    after JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT audit_log_pkey PRIMARY KEY (id)
);

CREATE TABLE public.notifications (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    dedup_key TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT notifications_pkey PRIMARY KEY (id),
    CONSTRAINT unique_user_dedup UNIQUE (user_id, dedup_key)
);

CREATE TABLE public.push_subscriptions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    last_success_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id),
    CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint)
);

CREATE TABLE public.notification_outbox (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    notification_id UUID NOT NULL,
    channel TEXT NOT NULL,
    status TEXT DEFAULT 'pending'::text NOT NULL,
    attempts INT DEFAULT 0 NOT NULL,
    next_attempt_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT notification_outbox_pkey PRIMARY KEY (id),
    CONSTRAINT notification_outbox_channel_check CHECK ((channel = ANY (ARRAY['push'::text, 'email'::text]))),
    CONSTRAINT notification_outbox_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text, 'skipped'::text])))
);

CREATE TABLE public.site_announcements (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    message TEXT NOT NULL,
    link_url TEXT,
    is_published BOOLEAN DEFAULT true NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT site_announcements_pkey PRIMARY KEY (id)
);

CREATE TABLE public.carousel_slides (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    tag TEXT,
    title TEXT NOT NULL,
    subtitle TEXT,
    cta_text TEXT,
    cta_url TEXT,
    image_url TEXT,
    bg_gradient TEXT DEFAULT 'from-emerald-900 via-guaiqui-primary-dark to-slate-900'::text,
    badge_variant TEXT DEFAULT 'primary'::text,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT carousel_slides_pkey PRIMARY KEY (id)
);

CREATE TABLE public.history_milestones (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    year TEXT NOT NULL,
    title TEXT NOT NULL,
    text TEXT NOT NULL,
    image_url TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT history_milestones_pkey PRIMARY KEY (id)
);

CREATE TABLE public.site_team_members (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    group_category TEXT NOT NULL,
    photo_url TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT site_team_members_pkey PRIMARY KEY (id),
    CONSTRAINT site_team_members_group_category_check CHECK ((group_category = ANY (ARRAY['directiva'::text, 'tecnico'::text, 'logistica'::text])))
);

CREATE TABLE public.faqs (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT faqs_pkey PRIMARY KEY (id)
);

CREATE TABLE public.site_stats (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    note TEXT,
    is_sponsor BOOLEAN DEFAULT false NOT NULL,
    logo_url TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT site_stats_pkey PRIMARY KEY (id)
);

CREATE TABLE public.social_links (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    platform TEXT NOT NULL,
    label TEXT NOT NULL,
    url TEXT NOT NULL,
    icon TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT social_links_pkey PRIMARY KEY (id)
);

CREATE TABLE public.policy_documents (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    slug TEXT NOT NULL,
    version TEXT NOT NULL,
    content_markdown TEXT NOT NULL,
    published_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT policy_documents_pkey PRIMARY KEY (id),
    CONSTRAINT policy_documents_slug_check CHECK ((slug = ANY (ARRAY['terminos'::text, 'privacidad'::text, 'perlitas'::text, 'canjes'::text])))
);

CREATE TABLE public.standings (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    team_name TEXT NOT NULL,
    logo_url TEXT,
    games_played INT DEFAULT 0 NOT NULL,
    wins INT DEFAULT 0 NOT NULL,
    losses INT DEFAULT 0 NOT NULL,
    points INT DEFAULT 0 NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT standings_pkey PRIMARY KEY (id)
);

CREATE TABLE public.captcha_passes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    ip_hash TEXT NOT NULL,
    used BOOLEAN DEFAULT false NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT captcha_passes_pkey PRIMARY KEY (id)
);

CREATE TABLE public.rate_limits (
    user_id UUID NOT NULL,
    action TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    request_count INT DEFAULT 1 NOT NULL,
    CONSTRAINT rate_limits_pkey PRIMARY KEY (user_id, action, window_start)
);

CREATE TABLE public.system_alerts (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    resolved BOOLEAN DEFAULT false NOT NULL,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT system_alerts_pkey PRIMARY KEY (id),
    CONSTRAINT system_alerts_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text])))
);

CREATE TABLE public.instagram_posts (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    post_url TEXT NOT NULL,
    shortcode TEXT,
    image_url TEXT,
    caption TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT instagram_posts_pkey PRIMARY KEY (id)
);

CREATE TABLE public.blocked_identities (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    email_hmac TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT blocked_identities_pkey PRIMARY KEY (id),
    CONSTRAINT blocked_identities_email_hmac_key UNIQUE (email_hmac)
);

CREATE TABLE public.fraud_telemetry (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    fan_id UUID NOT NULL,
    device_id TEXT,
    ip_hash TEXT,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT fraud_telemetry_pkey PRIMARY KEY (id)
);

CREATE TABLE public.birthday_settings (
    id INT DEFAULT 1 NOT NULL,
    enabled BOOLEAN DEFAULT true NOT NULL,
    title TEXT DEFAULT '¡Feliz Cumpleaños, Guaiquerí!'::text NOT NULL,
    message TEXT DEFAULT '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}! 🏀\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.'::text NOT NULL,
    image_url TEXT,
    send_hour INT DEFAULT 9 NOT NULL,
    grace_days INT DEFAULT 3 NOT NULL,
    bonus_pearls INT DEFAULT 0 NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT birthday_settings_pkey PRIMARY KEY (id),
    CONSTRAINT birthday_settings_bonus_pearls_check CHECK ((bonus_pearls >= 0)),
    CONSTRAINT birthday_settings_grace_days_check CHECK ((grace_days >= 0)),
    CONSTRAINT birthday_settings_id_check CHECK ((id = 1)),
    CONSTRAINT birthday_settings_send_hour_check CHECK (((send_hour >= 0) AND (send_hour <= 23)))
);

CREATE TABLE public.landing_settings (
    id INT DEFAULT 1 NOT NULL,
    hero_title TEXT DEFAULT 'La Tribu Insular Vive en la Fan Zone Oficial'::text NOT NULL,
    hero_subtitle TEXT DEFAULT 'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.'::text NOT NULL,
    cta_primary_text TEXT DEFAULT 'Únete a la Tribu Gratis'::text NOT NULL,
    cta_primary_url TEXT DEFAULT '/register'::text NOT NULL,
    cta_secondary_text TEXT DEFAULT 'Explorar Premios'::text NOT NULL,
    cta_secondary_url TEXT DEFAULT '#premios'::text NOT NULL,
    dark_mode_enabled BOOLEAN DEFAULT true NOT NULL,
    theme_color TEXT DEFAULT '#059669'::text NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT landing_settings_pkey PRIMARY KEY (id),
    CONSTRAINT single_row CHECK ((id = 1))
);

CREATE TABLE public.app_secrets (
    key_name TEXT NOT NULL,
    secret_value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT app_secrets_pkey PRIMARY KEY (key_name)
);

CREATE TABLE public.email_usage_tracker (
    period_yyyy_mm TEXT NOT NULL,
    total_sent INT DEFAULT 0 NOT NULL,
    active_key_index INT DEFAULT 1 NOT NULL,
    limit_reached_alert_sent BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT email_usage_tracker_pkey PRIMARY KEY (period_yyyy_mm)
);

CREATE TABLE public.mfa_recovery_codes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    code_hash TEXT NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT mfa_recovery_codes_pkey PRIMARY KEY (id)
);

CREATE TABLE public.display_name_change_logs (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    old_name TEXT,
    new_name TEXT NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT display_name_change_logs_pkey PRIMARY KEY (id)
);

CREATE TABLE public.login_modal_slides (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    position INT NOT NULL,
    image_url TEXT,
    title TEXT NOT NULL,
    subtitle TEXT,
    cta_label TEXT DEFAULT 'Ver más'::text NOT NULL,
    cta_url TEXT NOT NULL,
    status TEXT DEFAULT 'draft'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ends_at TIMESTAMPTZ,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT login_modal_slides_pkey PRIMARY KEY (id),
    CONSTRAINT login_modal_slides_position_check CHECK ((("position" >= 1) AND ("position" <= 5))),
    CONSTRAINT login_modal_slides_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text]))),
    CONSTRAINT login_modal_slides_subtitle_check CHECK ((char_length(subtitle) <= 160)),
    CONSTRAINT login_modal_slides_title_check CHECK ((char_length(title) <= 80))
);

CREATE TABLE public.ad_reward_tiers (
    block_number INT NOT NULL,
    pearls INT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT ad_reward_tiers_pkey PRIMARY KEY (block_number),
    CONSTRAINT ad_reward_tiers_block_number_check CHECK ((block_number > 0)),
    CONSTRAINT ad_reward_tiers_pearls_check CHECK ((pearls > 0))
);

CREATE TABLE public.ad_sessions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    started_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL,
    reason TEXT,
    day DATE NOT NULL,
    block_index INT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT ad_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT ad_sessions_status_check CHECK ((status = ANY (ARRAY['started'::text, 'completed'::text, 'void'::text, 'expired'::text, 'no_fill'::text, 'declined'::text, 'closed_early'::text, 'error'::text])))
);

CREATE TABLE public.ad_daily_progress (
    user_id UUID NOT NULL,
    day DATE NOT NULL,
    completed_count INT DEFAULT 0 NOT NULL,
    blocks_paid INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT ad_daily_progress_pkey PRIMARY KEY (user_id, day),
    CONSTRAINT ad_daily_progress_blocks_paid_check CHECK ((blocks_paid >= 0)),
    CONSTRAINT ad_daily_progress_completed_count_check CHECK (((completed_count >= 0) AND (completed_count <= 50)))
);

CREATE TABLE public.ad_reconciliation (
    day DATE NOT NULL,
    google_rewarded_impressions INT DEFAULT 0 NOT NULL,
    imported_by UUID,
    imported_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    notes TEXT,
    CONSTRAINT ad_reconciliation_pkey PRIMARY KEY (day),
    CONSTRAINT ad_reconciliation_google_rewarded_impressions_check CHECK ((google_rewarded_impressions >= 0))
);

-- ============================================================================
-- FOREIGN KEYS
-- ============================================================================

ALTER TABLE public.profiles ADD CONSTRAINT fk_favorite_player FOREIGN KEY (favorite_player_id) REFERENCES players(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE RESTRICT;
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.wallets ADD CONSTRAINT wallets_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ledger_entries ADD CONSTRAINT ledger_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.ledger_entries ADD CONSTRAINT ledger_entries_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.trivias ADD CONSTRAINT trivias_target_segment_id_fkey FOREIGN KEY (target_segment_id) REFERENCES segments(id) ON DELETE SET NULL;
ALTER TABLE public.trivia_questions ADD CONSTRAINT trivia_questions_trivia_id_fkey FOREIGN KEY (trivia_id) REFERENCES trivias(id) ON DELETE CASCADE;
ALTER TABLE public.trivia_options ADD CONSTRAINT trivia_options_question_id_fkey FOREIGN KEY (question_id) REFERENCES trivia_questions(id) ON DELETE CASCADE;
ALTER TABLE public.trivia_attempts ADD CONSTRAINT trivia_attempts_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.trivia_attempts ADD CONSTRAINT trivia_attempts_trivia_id_fkey FOREIGN KEY (trivia_id) REFERENCES trivias(id) ON DELETE CASCADE;
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES staff_members(user_id);
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_delivered_by_fkey FOREIGN KEY (delivered_by) REFERENCES staff_members(user_id);
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT;
ALTER TABLE public.redemption_history ADD CONSTRAINT redemption_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id);
ALTER TABLE public.redemption_history ADD CONSTRAINT redemption_history_redemption_id_fkey FOREIGN KEY (redemption_id) REFERENCES redemptions(id) ON DELETE CASCADE;
ALTER TABLE public.scan_events ADD CONSTRAINT scan_events_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(user_id);
ALTER TABLE public.risk_flags ADD CONSTRAINT risk_flags_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.push_subscriptions ADD CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.notification_outbox ADD CONSTRAINT notification_outbox_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;
ALTER TABLE public.captcha_passes ADD CONSTRAINT captcha_passes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.rate_limits ADD CONSTRAINT rate_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.system_alerts ADD CONSTRAINT system_alerts_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES profiles(id);
ALTER TABLE public.fraud_telemetry ADD CONSTRAINT fraud_telemetry_fan_id_fkey FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ledger_hold_resolutions ADD CONSTRAINT ledger_hold_resolutions_ledger_id_fkey FOREIGN KEY (ledger_id) REFERENCES ledger_entries(id) ON DELETE RESTRICT;
ALTER TABLE public.ledger_hold_resolutions ADD CONSTRAINT ledger_hold_resolutions_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES profiles(id);
ALTER TABLE public.mfa_recovery_codes ADD CONSTRAINT mfa_recovery_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.display_name_change_logs ADD CONSTRAINT display_name_change_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.login_modal_slides ADD CONSTRAINT login_modal_slides_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
ALTER TABLE public.ad_sessions ADD CONSTRAINT ad_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ad_daily_progress ADD CONSTRAINT ad_daily_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ad_reconciliation ADD CONSTRAINT ad_reconciliation_imported_by_fkey FOREIGN KEY (imported_by) REFERENCES auth.users(id);

-- ============================================================================
-- MATERIALIZED VIEWS
-- ============================================================================

CREATE MATERIALIZED VIEW public.mv_daily_fan_activity AS
SELECT ((started_at AT TIME ZONE 'America/Caracas'::text))::date AS activity_date,
    fan_id,
    count(DISTINCT id) AS trivias_count,
    COALESCE(sum(pearls_awarded), (0)::bigint) AS pearls_earned
FROM public.trivia_attempts ta
WHERE (submitted_at IS NOT NULL)
GROUP BY (((started_at AT TIME ZONE 'America/Caracas'::text))::date), fan_id
WITH DATA;

CREATE MATERIALIZED VIEW public.mv_demographics AS
SELECT COALESCE(NULLIF(TRIM(BOTH FROM municipality), ''::text), 'Sin especificar'::text) AS municipality,
    COALESCE(NULLIF(TRIM(BOTH FROM gender), ''::text), 'Sin especificar'::text) AS gender,
    CASE
        WHEN (birth_date IS NULL) THEN 'Sin especificar'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (18)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (24)::numeric)) THEN '18-24'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (25)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (34)::numeric)) THEN '25-34'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (35)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (44)::numeric)) THEN '35-44'::text
        WHEN (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (45)::numeric) THEN '45+'::text
        ELSE 'Menor de 18'::text
    END AS age_group,
    count(id) AS fan_count
FROM public.profiles p
WHERE (status = 'active'::user_status)
GROUP BY COALESCE(NULLIF(TRIM(BOTH FROM municipality), ''::text), 'Sin especificar'::text), COALESCE(NULLIF(TRIM(BOTH FROM gender), ''::text), 'Sin especificar'::text),
    CASE
        WHEN (birth_date IS NULL) THEN 'Sin especificar'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (18)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (24)::numeric)) THEN '18-24'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (25)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (34)::numeric)) THEN '25-34'::text
        WHEN ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (35)::numeric) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) <= (44)::numeric)) THEN '35-44'::text
        WHEN (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (birth_date)::timestamp with time zone)) >= (45)::numeric) THEN '45+'::text
        ELSE 'Menor de 18'::text
    END
WITH DATA;

CREATE MATERIALIZED VIEW public.mv_daily_economy_stats AS
SELECT ((created_at AT TIME ZONE 'America/Caracas'::text))::date AS entry_date,
    COALESCE(sum(
        CASE
            WHEN ((status = 'confirmed'::ledger_status) AND (amount > 0)) THEN amount
            ELSE 0
        END), (0)::bigint) AS pearls_issued,
    COALESCE(sum(
        CASE
            WHEN ((status = 'confirmed'::ledger_status) AND (amount < 0)) THEN abs(amount)
            ELSE 0
        END), (0)::bigint) AS pearls_spent,
    COALESCE(sum(
        CASE
            WHEN ((status = 'held'::ledger_status) AND (NOT (EXISTS ( SELECT 1
               FROM ledger_hold_resolutions r
              WHERE (r.ledger_id = le.id))))) THEN amount
            ELSE 0
        END), (0)::bigint) AS pearls_held
FROM public.ledger_entries le
GROUP BY (((created_at AT TIME ZONE 'America/Caracas'::text))::date)
WITH DATA;

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_ad_sessions_status ON public.ad_sessions USING btree (status);
CREATE INDEX idx_ad_sessions_user_day ON public.ad_sessions USING btree (user_id, day);
CREATE INDEX idx_captcha_passes_user_valid ON public.captcha_passes USING btree (user_id, expires_at) WHERE (used = false);
CREATE INDEX idx_fraud_telemetry_device ON public.fraud_telemetry USING btree (device_id, created_at DESC);
CREATE INDEX idx_fraud_telemetry_fan ON public.fraud_telemetry USING btree (fan_id, created_at DESC);
CREATE INDEX idx_fraud_telemetry_ip ON public.fraud_telemetry USING btree (ip_hash, created_at DESC);
CREATE UNIQUE INDEX idx_ledger_ad_block ON public.ledger_entries USING btree (source_type, source_id) WHERE (source_type = 'ad_block'::text);
CREATE INDEX idx_ledger_fan_created ON public.ledger_entries USING btree (fan_id, created_at DESC);
CREATE UNIQUE INDEX idx_ledger_unique_payout ON public.ledger_entries USING btree (source_type, source_id, type) WHERE (status = 'confirmed'::ledger_status);
CREATE UNIQUE INDEX idx_mv_daily_economy_stats_pk ON public.mv_daily_economy_stats USING btree (entry_date);
CREATE INDEX idx_mv_daily_fan_activity_date ON public.mv_daily_fan_activity USING btree (activity_date);
CREATE UNIQUE INDEX idx_mv_daily_fan_activity_pk ON public.mv_daily_fan_activity USING btree (activity_date, fan_id);
CREATE INDEX idx_mv_demographics_muni ON public.mv_demographics USING btree (municipality);
CREATE INDEX idx_outbox_pending ON public.notification_outbox USING btree (status, next_attempt_at) WHERE (status = 'pending'::text);
CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);
CREATE INDEX idx_push_sub_user ON public.push_subscriptions USING btree (user_id) WHERE (disabled_at IS NULL);

-- ============================================================================
-- STORAGE BUCKETS
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('product-images', 'product-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]),
    ('site-media', 'site-media', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']::text[]),
    ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/avif']::text[])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

