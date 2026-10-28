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

    // Caller client to verify caller session
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

    // Verify caller is active admin
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

    const { email, role = "staff", team_id: requestedTeamId } = await req.json();
    if (!email || typeof email !== "string") {
      return new Response(JSON.stringify({ error: "Email is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let targetTeamId: string | null = null;
    const isPlatformAdmin = staffRow.team_id === null;

    if (!isPlatformAdmin) {
      // Club Admin: must assign strictly to their own team
      if (requestedTeamId && requestedTeamId !== staffRow.team_id) {
        return new Response(
          JSON.stringify({ error: "No tienes autorización para invitar personal a otro equipo" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      targetTeamId = staffRow.team_id;
    } else {
      // Platform Admin: can specify team_id (or null for platform admin)
      targetTeamId = requestedTeamId || null;
    }

    // Invite user via admin auth API
    const { data: newUser, error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(email);
    if (inviteErr) {
      return new Response(JSON.stringify({ error: inviteErr.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insert staff_members entry with team_id
    const { error: insertErr } = await adminClient
      .from("staff_members")
      .insert({
        user_id: newUser.user.id,
        role: role === "admin" ? "admin" : "staff",
        team_id: targetTeamId,
        active: true,
      });

    if (insertErr) {
      return new Response(JSON.stringify({ error: insertErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Audit log
    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      action: "invite_staff_member",
      entity: "staff_members",
      entity_id: newUser.user.id,
      after: { email, role, team_id: targetTeamId },
    });

    return new Response(
      JSON.stringify({ message: "Staff member invited successfully", user_id: newUser.user.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
