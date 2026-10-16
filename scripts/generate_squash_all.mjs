import fs from 'fs';
import path from 'path';

const stepsDir = 'C:\\Users\\dcazo\\.gemini\\antigravity-ide\\brain\\211005b2-01ce-463c-87a9-8eaff6f8b421\\.system_generated\\steps';
const outDir = 'supabase/migrations';

function readStepJson(stepNum) {
  const file = path.join(stepsDir, `${stepNum}`, 'output.txt');
  const raw = fs.readFileSync(file, 'utf8');
  const parsed = JSON.parse(raw);
  const startIdx = parsed.result.indexOf('>\n[');
  const endIdx = parsed.result.lastIndexOf(']\n<');
  if (startIdx === -1 || endIdx === -1) {
    throw new Error(`Could not locate JSON array in step ${stepNum}`);
  }
  return JSON.parse(parsed.result.substring(startIdx + 2, endIdx + 1));
}

const columns = readStepJson(438);
const constraints = readStepJson(440);
const functions = readStepJson(444);
const policies = readStepJson(450);
const indexes = readStepJson(476);
const acls = readStepJson(482);
const seedRows = readStepJson(496);

console.log('Building Migration 1: Schema and Types...');
let sql1 = `-- ============================================================================
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

`;

// Map columns by table
const tablesMap = new Map();
for (const col of columns) {
  if (!tablesMap.has(col.table_name)) {
    tablesMap.set(col.table_name, []);
  }
  tablesMap.get(col.table_name).push(col);
}

// Table creation order
const tableOrder = [
  'players',
  'segments',
  'profiles',
  'staff_members',
  'wallets',
  'ledger_entries',
  'ledger_hold_resolutions',
  'games',
  'trivias',
  'trivia_questions',
  'trivia_options',
  'trivia_attempts',
  'products',
  'redemptions',
  'redemption_history',
  'scan_events',
  'economy_settings',
  'risk_flags',
  'risk_settings',
  'audit_log',
  'notifications',
  'push_subscriptions',
  'notification_outbox',
  'site_announcements',
  'carousel_slides',
  'history_milestones',
  'site_team_members',
  'faqs',
  'site_stats',
  'social_links',
  'policy_documents',
  'standings',
  'captcha_passes',
  'rate_limits',
  'system_alerts',
  'instagram_posts',
  'blocked_identities',
  'fraud_telemetry',
  'birthday_settings',
  'landing_settings',
  'app_secrets',
  'email_usage_tracker',
  'mfa_recovery_codes',
  'display_name_change_logs',
  'login_modal_slides',
  'ad_reward_tiers',
  'ad_sessions',
  'ad_daily_progress',
  'ad_reconciliation'
];

// Helper to format PostgreSQL types
function mapColType(col) {
  if (col.udt_name === 'timestamptz') return 'TIMESTAMPTZ';
  if (col.udt_name === 'timestamp') return 'TIMESTAMP';
  if (col.udt_name === 'date') return 'DATE';
  if (col.udt_name === 'uuid') return 'UUID';
  if (col.udt_name === 'int4') return 'INT';
  if (col.udt_name === 'int8') return 'BIGINT';
  if (col.udt_name === 'bool') return 'BOOLEAN';
  if (col.udt_name === 'text') return 'TEXT';
  if (col.udt_name === 'jsonb') return 'JSONB';
  if (col.udt_name === '_text') return 'TEXT[]';
  if (col.data_type === 'USER-DEFINED') return col.udt_name;
  return col.data_type.toUpperCase();
}

// Add table definitions
sql1 += `-- ============================================================================\n-- TABLES DEFINITION\n-- ============================================================================\n\n`;

for (const tbl of tableOrder) {
  const cols = tablesMap.get(tbl);
  if (!cols) continue;

  sql1 += `CREATE TABLE public.${tbl} (\n`;
  const lines = [];

  for (const c of cols) {
    let line = `    ${c.column_name} ${mapColType(c)}`;
    if (c.column_default !== null) {
      line += ` DEFAULT ${c.column_default}`;
    }
    if (c.is_nullable === 'NO') {
      line += ` NOT NULL`;
    }
    lines.push(line);
  }

  // Get primary key
  const pk = constraints.find(cn => cn.table_name === tbl && cn.constraint_type === 'p');
  if (pk) {
    lines.push(`    CONSTRAINT ${pk.constraint_name} ${pk.constraint_definition}`);
  }

  // Get unique constraints (excluding PK)
  const uqs = constraints.filter(cn => cn.table_name === tbl && cn.constraint_type === 'u');
  for (const u of uqs) {
    lines.push(`    CONSTRAINT ${u.constraint_name} ${u.constraint_definition}`);
  }

  // Get check constraints (excluding NOT NULL checks)
  const cks = constraints.filter(cn => cn.table_name === tbl && cn.constraint_type === 'c' && !cn.constraint_name.endsWith('_not_null'));
  for (const ck of cks) {
    lines.push(`    CONSTRAINT ${ck.constraint_name} ${ck.constraint_definition}`);
  }

  sql1 += lines.join(',\n') + '\n);\n\n';
}

// Add foreign key constraints
sql1 += `-- ============================================================================\n-- FOREIGN KEYS\n-- ============================================================================\n\n`;
const fks = constraints.filter(cn => cn.constraint_type === 'f');
for (const fk of fks) {
  sql1 += `ALTER TABLE public.${fk.table_name} ADD CONSTRAINT ${fk.constraint_name} ${fk.constraint_definition};\n`;
}
sql1 += '\n';

// Materialized Views
sql1 += `-- ============================================================================\n-- MATERIALIZED VIEWS\n-- ============================================================================\n\n`;

sql1 += `CREATE MATERIALIZED VIEW public.mv_daily_fan_activity AS
SELECT ((started_at AT TIME ZONE 'America/Caracas'::text))::date AS activity_date,
    fan_id,
    count(DISTINCT id) AS trivias_count,
    COALESCE(sum(pearls_awarded), (0)::bigint) AS pearls_earned
FROM public.trivia_attempts ta
WHERE (submitted_at IS NOT NULL)
GROUP BY (((started_at AT TIME ZONE 'America/Caracas'::text))::date), fan_id
WITH DATA;\n\n`;

sql1 += `CREATE MATERIALIZED VIEW public.mv_demographics AS
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
WITH DATA;\n\n`;

sql1 += `CREATE MATERIALIZED VIEW public.mv_daily_economy_stats AS
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
WITH DATA;\n\n`;

// Add secondary indexes (ignore PK and unique constraints which pg_indexes already has, or filter them)
sql1 += `-- ============================================================================\n-- INDEXES\n-- ============================================================================\n\n`;
const pkAndUqNames = new Set(constraints.filter(c => c.constraint_type === 'p' || c.constraint_type === 'u').map(c => c.constraint_name));

for (const idx of indexes) {
  if (pkAndUqNames.has(idx.indexname)) continue;
  sql1 += `${idx.indexdef};\n`;
}
sql1 += '\n';

// Storage buckets
sql1 += `-- ============================================================================\n-- STORAGE BUCKETS\n-- ============================================================================\n\n`;
sql1 += `INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('product-images', 'product-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]),
    ('site-media', 'site-media', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']::text[]),
    ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/avif']::text[])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

`;

fs.writeFileSync(path.join(outDir, '20261016000001_schema_and_types.sql'), sql1);
console.log('Created 20261016000001_schema_and_types.sql');


// ============================================================================
// Migration 2: Functions and Triggers
// ============================================================================
console.log('Building Migration 2: Functions and Triggers...');
let sql2 = `-- ============================================================================
-- Migration: 20261016000002_functions_and_triggers.sql
-- Description: Consolidated functions, triggers, and RPCs for Guaiqueríes Platform.
--              Includes security hardening, STABLE auth helpers, search_path,
--              and permission grants.
-- ============================================================================

`;

// Sort functions so core auth helpers come first
const coreHelpers = ['is_admin', 'is_staff_or_admin', 'is_admin_check', 'assert_admin', 'assert_staff', 'assert_active_verified_fan'];
const sortedFuncs = [...functions].sort((a, b) => {
  const aIdx = coreHelpers.indexOf(a.function_name);
  const bIdx = coreHelpers.indexOf(b.function_name);
  if (aIdx !== -1 && bIdx !== -1) return aIdx - bIdx;
  if (aIdx !== -1) return -1;
  if (bIdx !== -1) return 1;
  return a.function_name.localeCompare(b.function_name);
});

for (const fn of sortedFuncs) {
  let def = fn.definition.trim();

  // Ensure helper functions have STABLE and fixed search_path
  if (fn.function_name === 'is_admin' && fn.identity_arguments === 'user_id uuid') {
    def = `CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_admin.user_id 
          AND role = 'admin' 
          AND active = true
    );
END;
$function$`;
  } else if (fn.function_name === 'is_staff_or_admin' && fn.identity_arguments === 'user_id uuid') {
    def = `CREATE OR REPLACE FUNCTION public.is_staff_or_admin(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_staff_or_admin.user_id 
          AND active = true
    );
END;
$function$`;
  } else if (fn.function_name === 'is_admin_check' && fn.identity_arguments === '') {
    def = `CREATE OR REPLACE FUNCTION public.is_admin_check()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN public.is_admin(auth.uid());
END;
$function$`;
  } else if (fn.function_name === 'prevent_ledger_mutation') {
    def = `CREATE OR REPLACE FUNCTION public.prevent_ledger_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$function$`;
  } else if (fn.function_name === 'prevent_audit_log_mutation') {
    def = `CREATE OR REPLACE FUNCTION public.prevent_audit_log_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$function$`;
  } else if (fn.function_name === 'parse_instagram_shortcode') {
    def = `CREATE OR REPLACE FUNCTION public.parse_instagram_shortcode(p_url text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_parts TEXT[];
BEGIN
    IF p_url IS NULL THEN RETURN NULL; END IF;
    IF p_url LIKE '%/p/%' THEN
        v_parts := string_to_array(p_url, '/p/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    ELSIF p_url LIKE '%/reel/%' THEN
        v_parts := string_to_array(p_url, '/reel/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    END IF;
    RETURN NULL;
END;
$function$`;
  }

  sql2 += def + ';\n\n';
}

// Add Triggers
sql2 += `-- ============================================================================\n-- TRIGGERS\n-- ============================================================================\n\n`;
sql2 += `CREATE TRIGGER trg_prevent_ledger_mutation
    BEFORE DELETE OR UPDATE ON public.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();\n\n`;

sql2 += `CREATE TRIGGER trg_prevent_audit_log_mutation
    BEFORE DELETE OR UPDATE ON public.audit_log
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();\n\n`;

sql2 += `CREATE TRIGGER trg_check_max_5_published_login_modal_slides
    BEFORE INSERT OR UPDATE ON public.login_modal_slides
    FOR EACH ROW EXECUTE FUNCTION check_max_5_published_login_modal_slides();\n\n`;

sql2 += `CREATE CONSTRAINT TRIGGER trg_assert_min_admins
    AFTER DELETE OR UPDATE ON public.staff_members
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION assert_min_admins();\n\n`;

// Revoke and Grant Permissions
sql2 += `-- ============================================================================\n-- FUNCTION PERMISSIONS (REVOKE PUBLIC, GRANT EXPLICIT ROLES)\n-- ============================================================================\n\n`;
sql2 += `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;\n\n`;

// Grant based on ACLs
for (const a of acls) {
  const aclStr = a.proacl || '';
  const funcSig = `${a.proname}(${a.args})`;

  const grants = [];
  if (aclStr.includes('authenticated=X')) grants.push('authenticated');
  if (aclStr.includes('service_role=X')) grants.push('service_role');
  if (aclStr.includes('anon=X')) grants.push('anon');

  if (grants.length > 0) {
    sql2 += `GRANT EXECUTE ON FUNCTION public.${funcSig} TO ${grants.join(', ')};\n`;
  }
}
sql2 += '\n';

fs.writeFileSync(path.join(outDir, '20261016000002_functions_and_triggers.sql'), sql2);
console.log('Created 20261016000002_functions_and_triggers.sql');


// ============================================================================
// Migration 3: RLS Policies
// ============================================================================
console.log('Building Migration 3: RLS Policies...');
let sql3 = `-- ============================================================================
-- Migration: 20261016000003_rls_policies.sql
-- Description: Consolidated, hardened Row Level Security (RLS) policies for all
--              tables and storage objects. Uses (SELECT auth.uid()) for InitPlan
--              optimization, seals trivia_options data leakage, and ensures
--              symmetric WITH CHECK on mutations.
-- ============================================================================

`;

// Enable RLS on all 49 tables
sql3 += `-- Enable RLS on all public tables\n`;
for (const tbl of tableOrder) {
  sql3 += `ALTER TABLE public.${tbl} ENABLE ROW LEVEL SECURITY;\n`;
}
sql3 += '\n';

// Storage objects RLS
sql3 += `-- Enable RLS on storage.objects\n`;
sql3 += `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;\n\n`;

// Group policies by table
const policiesByTable = new Map();
for (const p of policies) {
  const key = `${p.schemaname}.${p.tablename}`;
  if (!policiesByTable.has(key)) {
    policiesByTable.set(key, []);
  }
  policiesByTable.get(key).push(p);
}

// Special consolidated policies for trivia_options, system_alerts, and storage
for (const [tblKey, pList] of policiesByTable.entries()) {
  sql3 += `-- ----------------------------------------------------------------------------\n-- Policies for ${tblKey}\n-- ----------------------------------------------------------------------------\n`;

  if (tblKey === 'public.trivia_options') {
    // Consolidated secure policy from migration 51
    sql3 += `CREATE POLICY "Trivia Options Staff Manage" ON public.trivia_options
    FOR ALL TO authenticated
    USING (public.is_staff_or_admin((SELECT auth.uid())))
    WITH CHECK (public.is_staff_or_admin((SELECT auth.uid())));\n\n`;
    continue;
  }

  if (tblKey === 'public.system_alerts') {
    // Fixed boolean policies from migration 51
    sql3 += `CREATE POLICY system_alerts_admin_select ON public.system_alerts
    FOR SELECT TO authenticated
    USING (public.is_admin((SELECT auth.uid())));\n\n`;

    sql3 += `CREATE POLICY system_alerts_admin_update ON public.system_alerts
    FOR UPDATE TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));\n\n`;
    continue;
  }

  if (tblKey === 'storage.objects') {
    // Hardened storage policies from migration 51 + avatars
    sql3 += `CREATE POLICY "ProductImages Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'product-images');

CREATE POLICY "ProductImages Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "ProductImages Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())))
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "ProductImages Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'site-media');

CREATE POLICY "SiteMedia Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())))
    WITH CHECK (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "Avatars Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

CREATE POLICY "Avatars User Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

CREATE POLICY "Avatars User Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    )
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

CREATE POLICY "Avatars User Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );\n\n`;
    continue;
  }

  // General policies: ensure clean InitPlan optimization
  for (const pol of pList) {
    let qual = pol.qual;
    let withCheck = pol.with_check;

    // Optimize auth.uid() -> (SELECT auth.uid()) if not already wrapped
    if (qual && qual.includes('auth.uid()') && !qual.includes('(SELECT auth.uid())')) {
      qual = qual.replace(/auth\.uid\(\)/g, '(SELECT auth.uid())');
    }
    if (withCheck && withCheck.includes('auth.uid()') && !withCheck.includes('(SELECT auth.uid())')) {
      withCheck = withCheck.replace(/auth\.uid\(\)/g, '(SELECT auth.uid())');
    }

    // Role format
    let roles = 'public';
    if (pol.roles && pol.roles !== '{public}') {
      roles = pol.roles.replace(/[{}]/g, '');
    }

    // Admin CMS tables optimization from migration 51
    if (pol.policyname.endsWith('Admin All') && roles === 'public') {
      roles = 'authenticated';
    }

    sql3 += `CREATE POLICY "${pol.policyname}" ON ${tblKey}\n    FOR ${pol.cmd} TO ${roles}\n`;
    if (qual) {
      sql3 += `    USING (${qual})\n`;
    }
    if (withCheck) {
      sql3 += `    WITH CHECK (${withCheck})\n`;
    }
    sql3 += `;\n\n`;
  }
}

sql3 += `NOTIFY pgrst, 'reload schema';\n`;

fs.writeFileSync(path.join(outDir, '20261016000003_rls_policies.sql'), sql3);
console.log('Created 20261016000003_rls_policies.sql');


// ============================================================================
// Migration 4: Initial Seed Data
// ============================================================================
console.log('Building Migration 4: Initial Seed...');
let sql4 = `-- ============================================================================
-- Migration: 20261016000004_initial_seed.sql
-- Description: Baseline system configuration seed data (Economy, Risk,
--              Landing settings, Birthday, Policies, Standings, Ad Tiers).
-- ============================================================================

`;

const seedTables = ['economy_settings', 'risk_settings', 'birthday_settings', 'landing_settings', 'ad_reward_tiers', 'policy_documents', 'standings'];

for (const tbl of seedTables) {
  const rows = seedRows.filter(r => r.tbl === tbl).map(r => r.row_data);
  if (rows.length === 0) continue;

  sql4 += `-- Seed for ${tbl}\n`;
  for (const r of rows) {
    const keys = Object.keys(r);
    const colsList = keys.join(', ');
    const valuesList = keys.map(k => {
      const v = r[k];
      if (v === null) return 'NULL';
      if (typeof v === 'boolean' || typeof v === 'number') return v;
      if (typeof v === 'object') return `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb`;
      return `'${String(v).replace(/'/g, "''")}'`;
    }).join(', ');

    sql4 += `INSERT INTO public.${tbl} (${colsList})\nVALUES (${valuesList})\nON CONFLICT DO NOTHING;\n\n`;
  }
}

fs.writeFileSync(path.join(outDir, '20261016000004_initial_seed.sql'), sql4);
console.log('Created 20261016000004_initial_seed.sql');

console.log('All 4 squashed migrations built successfully!');
