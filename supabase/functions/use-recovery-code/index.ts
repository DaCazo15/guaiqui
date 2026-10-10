import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function hashCode(code: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code.trim().toUpperCase());
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

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

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Token inválido o expirado" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { code } = body;
    if (!code || typeof code !== "string") {
      return new Response(JSON.stringify({ error: "El código de recuperación es requerido" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const codeHash = await hashCode(code);
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Find matching unused recovery code
    const { data: codeRow, error: codeErr } = await adminClient
      .from("mfa_recovery_codes")
      .select("id")
      .eq("user_id", user.id)
      .eq("code_hash", codeHash)
      .is("used_at", null)
      .maybeSingle();

    if (codeErr || !codeRow) {
      return new Response(JSON.stringify({ error: "Código de recuperación inválido o ya utilizado" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Mark code as used
    await adminClient
      .from("mfa_recovery_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("id", codeRow.id);

    // List factors and unenroll/delete TOTP factors
    const { data: factorData } = await adminClient.auth.admin.mfa.listFactors({ userId: user.id });
    if (factorData?.factors) {
      for (const factor of factorData.factors) {
        if (factor.factor_type === "totp") {
          await adminClient.auth.admin.mfa.deleteFactor({ userId: user.id, factorId: factor.id });
        }
      }
    }

    // Insert audit log & security notification
    await adminClient.from("audit_logs").insert({
      actor_id: user.id,
      action: "mfa_recovery_code_used",
      target_table: "auth",
      target_id: user.id,
      details: { message: "2FA disabled via single-use recovery code" },
    });

    await adminClient.rpc("create_security_notification", {
      p_user_id: user.id,
      p_title: "Seguridad de la cuenta",
      p_body: "Se utilizó un código de recuperación para desactivar la verificación en dos pasos (2FA).",
    });

    return new Response(
      JSON.stringify({ success: true, message: "2FA desactivado correctamente mediante código de recuperación." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
