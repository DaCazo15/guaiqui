import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

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
    const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
    const ipSalt = Deno.env.get("IP_SALT");
    const environment = Deno.env.get("ENVIRONMENT") || Deno.env.get("NODE_ENV") || "production";
    const isLocal = environment === "local" || environment === "test";

    if (!isLocal && !turnstileSecret) {
      return new Response(
        JSON.stringify({ error: "TURNSTILE_SECRET_KEY no configurado en el servidor" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!isLocal && !ipSalt) {
      return new Response(
        JSON.stringify({ error: "IP_SALT no configurado en el servidor de producción" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const saltToUse = ipSalt || "_guaiqui_ip_salt_local_test";
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

    const clientIp = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || "127.0.0.1";
    const ipHash = await hashIp(clientIp, saltToUse);

    // Allow mock token "test-valid-pass" ONLY in local/test environment
    const isMockPass = isLocal && token === "test-valid-pass";

    if (!isMockPass) {
      const secretToUse = turnstileSecret || (isLocal ? "1x0000000000000000000000000000000AA" : "");
      if (!secretToUse) {
        return new Response(
          JSON.stringify({ error: "TURNSTILE_SECRET_KEY no configurado en servidor" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

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
