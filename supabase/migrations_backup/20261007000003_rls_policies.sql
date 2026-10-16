-- Migration: 20261007000003_rls_policies.sql
-- Description: Strict Row-Level Security (RLS) Policies per Role

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE trivias ENABLE ROW LEVEL SECURITY;
ALTER TABLE trivia_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trivia_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE trivia_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemption_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE scan_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE economy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------
-- 1. PROFILES
-- -------------------------------------------------------------
CREATE POLICY "Fan reads own profile"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid() OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Fan updates own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "Admin manages all profiles"
ON profiles FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 2. STAFF MEMBERS
-- -------------------------------------------------------------
CREATE POLICY "Staff reads staff directory"
ON staff_members FOR SELECT
TO authenticated
USING (is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages staff members"
ON staff_members FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 3. WALLETS (READ-ONLY FOR FANS, NO DIRECT CLIENT WRITE)
-- -------------------------------------------------------------
CREATE POLICY "Fan reads own wallet"
ON wallets FOR SELECT
TO authenticated
USING (fan_id = auth.uid() OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages wallets"
ON wallets FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 4. LEDGER ENTRIES (READ-ONLY FOR FANS, NO DIRECT CLIENT WRITE)
-- -------------------------------------------------------------
CREATE POLICY "Fan reads own ledger entries"
ON ledger_entries FOR SELECT
TO authenticated
USING (fan_id = auth.uid() OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages ledger"
ON ledger_entries FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 5. TRIVIAS, QUESTIONS & OPTIONS (SECRET ANSWERS HIDDEN FROM FANS)
-- -------------------------------------------------------------
CREATE POLICY "Public reads published trivias"
ON trivias FOR SELECT
TO authenticated, anon
USING (status IN ('published', 'archived') OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages trivias"
ON trivias FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "Public reads trivia questions"
ON trivia_questions FOR SELECT
TO authenticated, anon
USING (TRUE);

CREATE POLICY "Admin manages questions"
ON trivia_questions FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- Trivia Options: Fans can SELECT option text, but is_correct is graded solely on server
CREATE POLICY "Public reads trivia option text"
ON trivia_options FOR SELECT
TO authenticated, anon
USING (TRUE);

CREATE POLICY "Admin manages options"
ON trivia_options FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 6. TRIVIA ATTEMPTS
-- -------------------------------------------------------------
CREATE POLICY "Fan reads own attempts"
ON trivia_attempts FOR SELECT
TO authenticated
USING (fan_id = auth.uid() OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages attempts"
ON trivia_attempts FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 7. PRODUCTS (CATALOG)
-- -------------------------------------------------------------
CREATE POLICY "Public reads active products"
ON products FOR SELECT
TO authenticated, anon
USING (active = true OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Staff manages product stock"
ON products FOR UPDATE
TO authenticated
USING (is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages products"
ON products FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 8. REDEMPTIONS & HISTORY
-- -------------------------------------------------------------
CREATE POLICY "Fan reads own redemptions"
ON redemptions FOR SELECT
TO authenticated
USING (fan_id = auth.uid() OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Staff manages redemptions"
ON redemptions FOR ALL
TO authenticated
USING (is_staff_or_admin(auth.uid()));

CREATE POLICY "Staff reads redemption history"
ON redemption_history FOR SELECT
TO authenticated
USING (is_staff_or_admin(auth.uid()));

-- -------------------------------------------------------------
-- 9. PLAYERS & GAMES
-- -------------------------------------------------------------
CREATE POLICY "Public reads active players"
ON players FOR SELECT
TO authenticated, anon
USING (is_active = true OR is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages players"
ON players FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "Public reads games schedule"
ON games FOR SELECT
TO authenticated, anon
USING (TRUE);

CREATE POLICY "Admin manages games"
ON games FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

-- -------------------------------------------------------------
-- 10. ADMIN ONLY TABLES (SEGMENTS, ECONOMY, AUDIT, SCAN EVENTS)
-- -------------------------------------------------------------
CREATE POLICY "Staff logs scan events"
ON scan_events FOR ALL
TO authenticated
USING (is_staff_or_admin(auth.uid()));

CREATE POLICY "Admin manages segments"
ON segments FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "Admin manages economy settings"
ON economy_settings FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "Admin manages risk flags"
ON risk_flags FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "Admin views audit log"
ON audit_log FOR SELECT
TO authenticated
USING (is_admin(auth.uid()));
