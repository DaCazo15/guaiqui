-- Migration: 20261009000017_fase12_production_readiness.sql
-- Description: Fase 12 - System alerts table, health check function, and daily reconciliation cron job.

CREATE TABLE IF NOT EXISTS public.system_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
  message TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.system_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY system_alerts_admin_select ON public.system_alerts
  FOR SELECT TO authenticated USING (public.assert_admin());

CREATE POLICY system_alerts_admin_update ON public.system_alerts
  FOR UPDATE TO authenticated USING (public.assert_admin());

-- Health check RPC
CREATE OR REPLACE FUNCTION public.health_check()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_unresolved_alerts INT;
  v_pending_redemptions INT;
  v_status TEXT := 'ok';
BEGIN
  SELECT COUNT(*) INTO v_unresolved_alerts FROM public.system_alerts WHERE resolved = false;
  SELECT COUNT(*) INTO v_pending_redemptions FROM public.redemptions WHERE status = 'pending';

  IF v_unresolved_alerts > 0 THEN
    v_status := 'degraded';
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'timestamp', NOW(),
    'unresolved_alerts', v_unresolved_alerts,
    'pending_redemptions', v_pending_redemptions,
    'database_version', version()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.health_check() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.health_check() TO anon, authenticated;

-- Daily Wallet Reconciliation wrapper for pg_cron
CREATE OR REPLACE FUNCTION public.run_daily_wallet_reconciliation()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_mismatches INT := 0;
  v_rec RECORD;
BEGIN
  FOR v_rec IN SELECT * FROM public.reconcile_wallets() LOOP
    v_mismatches := v_mismatches + 1;
    INSERT INTO public.system_alerts (alert_type, severity, message, metadata)
    VALUES (
      'wallet_mismatch',
      'critical',
      'Descalce detectado en billetera de usuario: ' || v_rec.user_id::text,
      jsonb_build_object(
        'user_id', v_rec.user_id,
        'cached_balance', v_rec.cached_balance,
        'ledger_calculated', v_rec.ledger_calculated,
        'diff', v_rec.diff
      )
    );
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.run_daily_wallet_reconciliation() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.run_daily_wallet_reconciliation() TO service_role;

-- Schedule daily cron job at 04:00 AM VET (08:00 UTC) if pg_cron is available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'daily_wallet_reconciliation',
      '0 8 * * *',
      'SELECT public.run_daily_wallet_reconciliation()'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not enabled or accessible in current environment';
END $$;
