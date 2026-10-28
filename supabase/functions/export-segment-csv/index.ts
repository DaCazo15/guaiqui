import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    const url = new URL(req.url);
    const segmentId = url.searchParams.get("segment_id") || (await req.json().catch(() => ({}))).segment_id;

    if (!segmentId) {
      return new Response(JSON.stringify({ error: "segment_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify segment belongs to caller's team (unless platform admin)
    const { data: segmentRow, error: segErr } = await adminClient
      .from("segments")
      .select("team_id")
      .eq("id", segmentId)
      .maybeSingle();

    if (segErr || !segmentRow) {
      return new Response(JSON.stringify({ error: "Segmento no encontrado" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (staffRow.team_id !== null && segmentRow.team_id !== staffRow.team_id) {
      return new Response(
        JSON.stringify({ error: "No tienes autorización para exportar segmentos de otro equipo" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Call RPC segment_members
    const { data, error: rpcErr } = await callerClient.rpc("segment_members", {
      p_segment_id: segmentId,
      p_limit: 5000,
    });

    if (rpcErr) {
      return new Response(JSON.stringify({ error: rpcErr.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const members = data?.members || [];

    // Minimal CSV format (id, display_name, municipality, created_at) - strictly no email
    let csv = "id,display_name,municipality,created_at\n";
    for (const m of members) {
      const name = `"${(m.display_name || "").replace(/"/g, '""')}"`;
      const mun = `"${(m.municipality || "").replace(/"/g, '""')}"`;
      csv += `${m.id},${name},${mun},${m.created_at}\n`;
    }

    // Audit log
    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      action: "export_segment_csv",
      entity: "segments",
      entity_id: segmentId,
      after: { count: members.length },
    });

    return new Response(csv, {
      headers: {
        ...corsHeaders,
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="segment_${segmentId}.csv"`,
      },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
