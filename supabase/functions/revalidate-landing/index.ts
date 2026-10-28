import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-revalidate-secret",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: caller }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !caller) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const { data: staffRow, error: staffErr } = await adminClient
      .from("staff_members")
      .select("role, active, team_id")
      .eq("user_id", caller.id)
      .maybeSingle();

    if (staffErr || !staffRow || !staffRow.active || staffRow.role !== "admin") {
      return new Response(JSON.stringify({ error: "Admin authorization required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const requestedTeamId = body.team_id || new URL(req.url).searchParams.get("team_id");

    if (staffRow.team_id !== null && requestedTeamId && requestedTeamId !== staffRow.team_id) {
      return new Response(
        JSON.stringify({ error: "No tienes autorización para revalidar la landing de otro equipo" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const effectiveTeamId = staffRow.team_id || requestedTeamId || "all";

    // Trigger revalidation event
    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      action: "revalidate_landing_cache",
      entity: "landing_content",
      after: { revalidated_at: new Date().toISOString(), team_id: effectiveTeamId },
    });

    return new Response(
      JSON.stringify({ message: "Landing content revalidated successfully", team_id: effectiveTeamId, timestamp: new Date().toISOString() }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
