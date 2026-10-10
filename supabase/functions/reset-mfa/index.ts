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
      return new Response(JSON.stringify({ error: "Token inválido o expirado" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify caller is admin
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const { data: staffRow } = await adminClient
      .from("staff_members")
      .select("role, active")
      .eq("user_id", caller.id)
      .maybeSingle();

    if (!staffRow || !staffRow.active || staffRow.role !== "admin") {
      return new Response(JSON.stringify({ error: "Autorización de Administrador requerida" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify AAL2 in caller token
    const token = authHeader.replace("Bearer ", "");
    let aal = "";
    try {
      const payloadBase64 = token.split(".")[1];
      const payload = JSON.parse(atob(payloadBase64));
      aal = payload.aal || "";
    } catch (_e) {
      aal = "";
    }

    if (aal !== "aal2") {
      return new Response(
        JSON.stringify({ error: "El restablecimiento de 2FA por un admin requiere inicio de sesión con 2FA (AAL2)" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { target_user_id } = await req.json();
    if (!target_user_id || typeof target_user_id !== "string") {
      return new Response(JSON.stringify({ error: "El ID de usuario objetivo es obligatorio" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Target must be a staff or admin
    const { data: targetStaff } = await adminClient
      .from("staff_members")
      .select("role, active")
      .eq("user_id", target_user_id)
      .maybeSingle();

    if (!targetStaff) {
      return new Response(JSON.stringify({ error: "Solo se puede restablecer el 2FA de miembros del personal" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Delete target MFA factors
    const { data: factorData } = await adminClient.auth.admin.mfa.listFactors({ userId: target_user_id });
    if (factorData?.factors) {
      for (const factor of factorData.factors) {
        if (factor.factor_type === "totp") {
          await adminClient.auth.admin.mfa.deleteFactor({ userId: target_user_id, factorId: factor.id });
        }
      }
    }

    // Delete target recovery codes
    await adminClient.from("mfa_recovery_codes").delete().eq("user_id", target_user_id);

    // Audit log
    await adminClient.from("audit_logs").insert({
      actor_id: caller.id,
      action: "admin_reset_mfa",
      target_table: "staff_members",
      target_id: target_user_id,
      details: { message: "Admin reset MFA for staff member" },
    });

    await adminClient.rpc("create_security_notification", {
      p_user_id: target_user_id,
      p_title: "Seguridad de la cuenta",
      p_body: "Un administrador ha restablecido la configuración de verificación en dos pasos de tu cuenta.",
    });

    return new Response(
      JSON.stringify({ success: true, message: "2FA del usuario restablecido correctamente" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
