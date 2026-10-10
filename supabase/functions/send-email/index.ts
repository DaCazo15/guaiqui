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
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const resendKey1 = Deno.env.get("RESEND_API_KEY_1") || "";
    const resendKey2 = Deno.env.get("RESEND_API_KEY_2") || "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Faltan variables de entorno de Supabase en servidor." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      // empty body
    }

    const { to, subject, html, text } = body;
    if (!to || (!html && !text)) {
      return new Response(
        JSON.stringify({ error: "Los campos 'to' y 'html'/'text' son obligatorios." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Register send attempt & obtain active key index (1 or 2)
    const { data: trackerData, error: trackerErr } = await adminClient.rpc("register_email_send_attempt");

    if (trackerErr) {
      const isMaintenance = trackerErr.message.includes("Servicio en mantenimiento") || trackerErr.code === "P0001";
      const status = isMaintenance ? 503 : 500;
      const userMsg = isMaintenance
        ? "Servicio en mantenimiento. Por favor espera unos minutos antes de volver a intentarlo."
        : trackerErr.message;

      return new Response(
        JSON.stringify({ error: userMsg }),
        { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const keyIndex = trackerData?.key_index || 1;
    const activeApiKey = keyIndex === 2 ? resendKey2 : resendKey1;

    // 2. Call Resend API v1
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${activeApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Guaiqueríes de Margarita <onboarding@resend.dev>",
        to: Array.isArray(to) ? to : [to],
        subject: subject || "Notificación de Guaiqueríes de Margarita",
        html: html || text,
        text: text,
      }),
    });

    const resendData = await resendRes.json();

    if (!resendRes.ok) {
      return new Response(
        JSON.stringify({ error: resendData.message || "Error enviando correo vía Resend API." }),
        { status: resendRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        id: resendData.id,
        key_used: keyIndex,
        total_sent_this_month: trackerData?.total_sent,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Error interno enviando correo." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
