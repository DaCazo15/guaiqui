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

  let createdTeamId: string | null = null;
  let adminClient: any = null;

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

    // 1. Authenticate caller
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

    // 2. Enforce AAL2 requirement
    try {
      const { data: aalData } = await callerClient.auth.mfa.getAuthenticatorAssuranceLevel();
      if (!aalData || aalData.currentLevel !== "aal2") {
        return new Response(
          JSON.stringify({ error: "Se requiere autenticación de dos factores (AAL2) para crear equipos" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } catch (_mfaErr) {
      // In automated test environments without MFA enrolled, allow if token has aal2 claim
      const jwtPayload = JSON.parse(atob(authHeader.replace("Bearer ", "").split(".")[1] || "{}"));
      if (jwtPayload.aal !== "aal2") {
        return new Response(
          JSON.stringify({ error: "Se requiere autenticación de dos factores (AAL2)" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 3. Verify caller is Platform Admin (team_id IS NULL)
    adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const { data: staffRow, error: staffErr } = await adminClient
      .from("staff_members")
      .select("role, active, team_id")
      .eq("user_id", caller.id)
      .maybeSingle();

    if (staffErr || !staffRow || !staffRow.active || staffRow.role !== "admin" || staffRow.team_id !== null) {
      return new Response(
        JSON.stringify({ error: "Solo los administradores de plataforma pueden dar de alta equipos" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Parse & Validate Payload
    const body = await req.json();
    const {
      name,
      slug,
      sport = "baloncesto",
      short_name = null,
      primary_color = "#005A36",
      secondary_color = "#E31B23",
      logo_url = null,
      admin_email,
      admin_name = null,
      initial_paid_months = 1,
    } = body;

    if (!name || typeof name !== "string" || name.trim().length < 2) {
      return new Response(JSON.stringify({ error: "El nombre del equipo es obligatorio (mínimo 2 caracteres)" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cleanSlug = (slug || "").toLowerCase().trim();
    if (!/^[a-z0-9-]+$/.test(cleanSlug) || cleanSlug.length < 2 || cleanSlug.length > 50) {
      return new Response(
        JSON.stringify({ error: "El slug debe contener solo minúsculas, números y guiones (2-50 caracteres)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!admin_email || typeof admin_email !== "string" || !admin_email.includes("@")) {
      return new Response(
        JSON.stringify({ error: "El correo electrónico del administrador inicial es obligatorio y debe ser válido" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check slug uniqueness
    const { data: existingTeam } = await adminClient
      .from("teams")
      .select("id")
      .eq("slug", cleanSlug)
      .maybeSingle();

    if (existingTeam) {
      return new Response(JSON.stringify({ error: "El slug proporcionado ya se encuentra registrado por otro equipo" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Calculate initial paid_until
    const now = new Date();
    const months = Math.max(1, Number(initial_paid_months) || 1);
    const paidUntil = new Date(now);
    paidUntil.setMonth(paidUntil.getMonth() + months);

    // 5. Compensable Step 1: Create Team
    const { data: newTeam, error: teamInsertErr } = await adminClient
      .from("teams")
      .insert({
        name: name.trim(),
        slug: cleanSlug,
        sport: sport.trim(),
        short_name: short_name ? short_name.trim() : null,
        primary_color: primary_color || "#005A36",
        secondary_color: secondary_color || "#E31B23",
        logo_url: logo_url || null,
        status: "active",
        joined_at: now.toISOString(),
        paid_until: paidUntil.toISOString(),
      })
      .select()
      .single();

    if (teamInsertErr || !newTeam) {
      return new Response(JSON.stringify({ error: `Error creando el equipo: ${teamInsertErr?.message}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    createdTeamId = newTeam.id;

    // 6. Step 2: Initialize default team records
    await adminClient.from("birthday_settings").upsert({
      team_id: newTeam.id,
      enabled: true,
      bonus_pearls: 100,
      grace_days: 3,
      title: "¡Feliz Cumpleaños!",
      message: `De parte de toda la familia de ${newTeam.name}, te deseamos un feliz día.`,
    });

    // 7. Compensable Step 3: Invite or assign initial team admin
    let targetUserId: string | null = null;

    // Invite user via Supabase admin auth
    const { data: inviteData, error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(admin_email);

    if (inviteErr) {
      // Check if user already exists in auth
      const { data: userList } = await adminClient.auth.admin.listUsers();
      const match = userList?.users?.find((u: any) => u.email?.toLowerCase() === admin_email.toLowerCase());
      if (match) {
        targetUserId = match.id;
      } else {
        // Rollback compensating action: delete created team
        await adminClient.from("teams").delete().eq("id", createdTeamId);
        return new Response(
          JSON.stringify({ error: `Error invitando al administrador: ${inviteErr.message}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else if (inviteData?.user) {
      targetUserId = inviteData.user.id;
    }

    if (!targetUserId) {
      await adminClient.from("teams").delete().eq("id", createdTeamId);
      return new Response(JSON.stringify({ error: "No se pudo resolver el ID del usuario administrador" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Step 4: Ensure profile and staff_member entry
    await adminClient.from("profiles").upsert({
      id: targetUserId,
      display_name: admin_name ? admin_name.trim() : `Admin ${newTeam.name}`,
      status: "active",
      terms_accepted_at: now.toISOString(),
      terms_version: "v1.0",
    });

    const { error: staffInsertErr } = await adminClient.from("staff_members").upsert({
      user_id: targetUserId,
      team_id: newTeam.id,
      role: "admin",
      active: true,
    });

    if (staffInsertErr) {
      // Rollback compensating action
      await adminClient.from("teams").delete().eq("id", createdTeamId);
      return new Response(JSON.stringify({ error: `Error asignando rol de administrador: ${staffInsertErr.message}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Step 5: Log initial billing event
    await adminClient.from("team_billing_events").insert({
      team_id: newTeam.id,
      event_type: "initial_subscription",
      amount: 0,
      currency: "USD",
      period_months: months,
      period_start: now.toISOString(),
      period_end: paidUntil.toISOString(),
      note: "Alta de equipo y período inicial activado.",
      registered_by: caller.id,
    });

    // Step 6: Audit log
    await adminClient.from("audit_log").insert({
      actor_id: caller.id,
      team_id: newTeam.id,
      action: "create_team",
      entity: "teams",
      entity_id: newTeam.id,
      after: {
        team: newTeam,
        initial_admin_id: targetUserId,
        admin_email,
      },
    });

    // Step 7: Queue welcome email to email_outbox
    await adminClient.from("email_outbox").insert({
      recipient_email: admin_email,
      subject: `¡Bienvenido a la plataforma! Tu equipo ${newTeam.name} ha sido creado`,
      body_html: `
        <h2>¡Hola!</h2>
        <p>Tu equipo <strong>${newTeam.name}</strong> ha sido dado de alta exitosamente en la plataforma.</p>
        <p>Has sido asignado como Administrador del Club. Revisa tu correo de invitación para establecer tu contraseña y acceder al panel administrativo.</p>
      `,
      metadata: { team_id: newTeam.id, action: "team_welcome" },
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Equipo y cuenta de administrador creados exitosamente",
        team: newTeam,
        admin_user_id: targetUserId,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    // If team was created but uncaught error happened, rollback
    if (createdTeamId && adminClient) {
      try {
        await adminClient.from("teams").delete().eq("id", createdTeamId);
      } catch (_compErr) {
        // ignore
      }
    }
    return new Response(JSON.stringify({ error: err.message || "Error inesperado en create-team" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
