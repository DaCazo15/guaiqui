-- Migration: 20261007000001_create_schema.sql
-- Description: Base database schema for Guaiqueríes de Margarita Loyalty Platform

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE user_status AS ENUM ('active', 'suspended');
CREATE TYPE staff_role AS ENUM ('staff', 'admin');
CREATE TYPE ledger_type AS ENUM ('trivia_reward', 'redemption', 'refund', 'admin_adjustment', 'bonus', 'streak_bonus');
CREATE TYPE ledger_status AS ENUM ('confirmed', 'held', 'revoked');
CREATE TYPE trivia_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE product_category AS ENUM ('physical', 'experience', 'raffle');
CREATE TYPE redemption_status AS ENUM ('pending', 'approved', 'scheduled', 'delivered', 'completed', 'cancelled', 'rejected', 'issue', 'expired');
CREATE TYPE scan_result AS ENUM ('success', 'invalid', 'already_delivered', 'expired');
CREATE TYPE game_status AS ENUM ('scheduled', 'live', 'finished', 'cancelled');
CREATE TYPE risk_severity AS ENUM ('low', 'medium', 'high');

-- 1. Profiles
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    municipality TEXT,
    birth_date DATE,
    gender TEXT,
    favorite_player_id UUID,
    shirt_size TEXT,
    referral_source TEXT,
    notification_prefs JSONB DEFAULT '{"email": true, "push": true}'::jsonb,
    status user_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Staff Members
CREATE TABLE staff_members (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role staff_role NOT NULL DEFAULT 'staff',
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Wallets (Cache table updated strictly via atomic transactions)
CREATE TABLE wallets (
    fan_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    balance_cache INT NOT NULL DEFAULT 0 CHECK (balance_cache >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Ledger Entries (IMMUTABLE: Only INSERT allowed)
CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INT NOT NULL, -- Signed integer: positive for earnings, negative for redemptions
    type ledger_type NOT NULL,
    status ledger_status NOT NULL DEFAULT 'confirmed',
    source_type TEXT NOT NULL, -- e.g. 'trivia_attempt', 'redemption', 'admin'
    source_id TEXT NOT NULL,
    note TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique index to prevent duplicate payouts per source
CREATE UNIQUE INDEX idx_ledger_unique_payout 
ON ledger_entries (source_type, source_id, type) 
WHERE status = 'confirmed';

CREATE INDEX idx_ledger_fan_created ON ledger_entries (fan_id, created_at DESC);

-- Trigger to enforce immutable ledger_entries (NO UPDATE, NO DELETE)
CREATE OR REPLACE FUNCTION prevent_ledger_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_ledger_mutation
BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();

-- 5. Players
CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    jersey_number INT NOT NULL,
    position TEXT NOT NULL,
    height TEXT,
    age INT,
    nationality TEXT DEFAULT 'Venezuela',
    bio TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_star BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Foreign key link in profiles
ALTER TABLE profiles 
ADD CONSTRAINT fk_favorite_player 
FOREIGN KEY (favorite_player_id) REFERENCES players(id) ON DELETE SET NULL;

-- 6. Games
CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opponent TEXT NOT NULL,
    location TEXT NOT NULL DEFAULT 'Gimnasio Ciudad de La Asunción',
    game_date TIMESTAMPTZ NOT NULL,
    is_home BOOLEAN NOT NULL DEFAULT true,
    status game_status NOT NULL DEFAULT 'scheduled',
    our_score INT DEFAULT 0,
    opponent_score INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Trivias
CREATE TABLE trivias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    status trivia_status NOT NULL DEFAULT 'draft',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    time_limit_seconds INT NOT NULL DEFAULT 60,
    reward_rules JSONB NOT NULL DEFAULT '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb,
    max_attempts INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Trivia Questions
CREATE TABLE trivia_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trivia_id UUID NOT NULL REFERENCES trivias(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    points INT NOT NULL DEFAULT 50,
    order_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Trivia Options (is_correct hidden from client RLS)
CREATE TABLE trivia_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES trivia_questions(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL DEFAULT false
);

-- 10. Trivia Attempts
CREATE TABLE trivia_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    trivia_id UUID NOT NULL REFERENCES trivias(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    submitted_at TIMESTAMPTZ,
    answers JSONB,
    score INT NOT NULL DEFAULT 0,
    pearls_awarded INT NOT NULL DEFAULT 0,
    suspicious BOOLEAN NOT NULL DEFAULT false,
    seed INT NOT NULL DEFAULT 12345,
    idempotency_key TEXT NOT NULL,
    CONSTRAINT uq_fan_trivia_attempt UNIQUE (fan_id, trivia_id, idempotency_key)
);

-- 11. Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category product_category NOT NULL DEFAULT 'physical',
    cost_pearls INT NOT NULL CHECK (cost_pearls > 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    variants JSONB DEFAULT '[]'::jsonb,
    active BOOLEAN NOT NULL DEFAULT true,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    images TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Redemptions
CREATE TABLE redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    variant TEXT,
    cost_pearls INT NOT NULL CHECK (cost_pearls > 0),
    status redemption_status NOT NULL DEFAULT 'pending',
    code_hash TEXT UNIQUE NOT NULL,
    approved_by UUID REFERENCES staff_members(user_id),
    approved_at TIMESTAMPTZ,
    delivered_by UUID REFERENCES staff_members(user_id),
    delivered_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_fan_redemption_idempotency UNIQUE (fan_id, idempotency_key)
);

-- 13. Redemption History
CREATE TABLE redemption_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    redemption_id UUID NOT NULL REFERENCES redemptions(id) ON DELETE CASCADE,
    previous_status redemption_status,
    new_status redemption_status NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. Scan Events
CREATE TABLE scan_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID NOT NULL REFERENCES staff_members(user_id),
    code_hash TEXT NOT NULL,
    result scan_result NOT NULL,
    device TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 15. Segments
CREATE TABLE segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    filters JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. Economy Settings
CREATE TABLE economy_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    daily_pearl_cap INT NOT NULL DEFAULT 1000,
    weekly_pearl_cap INT NOT NULL DEFAULT 5000,
    streak_bonus_config JSONB NOT NULL DEFAULT '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. Risk Flags
CREATE TABLE risk_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    severity risk_severity NOT NULL DEFAULT 'medium',
    resolved BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 18. Audit Log
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    entity TEXT NOT NULL,
    entity_id TEXT,
    before JSONB,
    after JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
