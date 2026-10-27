import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { logger } from "../_shared/logger.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Helper: SHA-256 HMAC / Hex digest
async function hashIp(ip: string, salt: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(ip + salt);
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
    const environment = Deno.env.get("ENVIRONMENT") || Deno.env.get("NODE_ENV") || "production";
    const isLocal = environment === "local" || environment === "test";

    const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
    const ipSalt = Deno.env.get("IP_SALT");

    // In staging and production, FAIL CLOSED if secrets are not defined.
    if (!isLocal && (!turnstileSecret || !ipSalt)) {
      logger.error("Missing required TURNSTILE_SECRET_KEY or IP_SALT in non-local environment");
      return new Response(JSON.stringify({ error: "Error de configuración del servidor" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const secretToUse = turnstileSecret || (isLocal ? "1x0000000000000000000000000000000AA" : "");
    const saltToUse = ipSalt || (isLocal ? "_guaiqui_ip_salt_local_dev" : "");

    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();

    const callerClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: userData, error: userErr } = await callerClient.auth.getUser(jwt);

    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const caller = userData.user;

    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      // invalid body format
    }
    const token = body?.token;
    const device_id = body?.device_id;

    // Token is mandatory
    if (!token || typeof token !== "string" || token.trim() === "") {
      return new Response(
        JSON.stringify({ error: "Token de captcha obligatorio" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Secure IP extraction: prefer infrastructure headers; take last trusted hop from x-forwarded-for
    let clientIp = req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip");
    if (!clientIp) {
      const xff = req.headers.get("x-forwarded-for");
      if (xff) {
        const hops = xff.split(",").map((ip) => ip.trim()).filter(Boolean);
        clientIp = hops[hops.length - 1] || "127.0.0.1";
      } else {
        clientIp = "127.0.0.1";
      }
    }

    const ipHash = await hashIp(clientIp, saltToUse);

    // Mock token "test-valid-pass" is strictly allowed ONLY in local or test environments
    if (token === "test-valid-pass") {
      if (!isLocal) {
        logger.warn(`Rejected test-valid-pass token in ${environment} environment for user ${caller.id}`);
        return new Response(
          JSON.stringify({ error: "Token de captcha inválido" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      const cfFormData = new FormData();
      cfFormData.append("secret", secretToUse);
      cfFormData.append("response", token);
      cfFormData.append("remoteip", clientIp);

      const cfRes = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
        method: "POST",
        body: cfFormData,
      });

      const cfOutcome = await cfRes.json();

      if (!cfOutcome.success) {
        return new Response(
          JSON.stringify({ error: "CAPTCHA_VERIFICATION_FAILED" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    // 1. Insert Captcha Pass
    const { error: passErr } = await adminClient.from("captcha_passes").insert({
      user_id: caller.id,
      ip_hash: ipHash,
      used: false,
      expires_at: expiresAt,
    });

    if (passErr) {
      return new Response(JSON.stringify({ error: passErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Log Telemetry
    await adminClient.from("fraud_telemetry").insert({
      fan_id: caller.id,
      device_id: device_id || null,
      ip_hash: ipHash,
      action: "verify_captcha",
    });

    // 3. Trigger risk computation asynchronously
    await adminClient.rpc("compute_risk", { p_fan_id: caller.id });

    return new Response(
      JSON.stringify({ success: true, expires_at: expiresAt }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
