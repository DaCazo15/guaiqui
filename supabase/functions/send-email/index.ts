import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AuthUser {
  id?: string;
  email?: string;
  user_metadata?: Record<string, unknown>;
  [key: string]: unknown;
}

interface AuthEmailData {
  token?: string;
  token_hash?: string;
  redirect_to?: string;
  email_action_type?: string;
  site_url?: string;
  [key: string]: unknown;
}

interface SendEmailPayload {
  user?: AuthUser;
  email_data?: AuthEmailData;
  to?: string | string[];
  subject?: string;
  html?: string;
  text?: string;
  [key: string]: unknown;
}

function generateAuthEmail(supabaseUrl: string, user: AuthUser, emailData: AuthEmailData) {
  const actionType = emailData.email_action_type || "signup";
  const token = emailData.token || "";
  const tokenHash = emailData.token_hash || "";
  const redirectTo = emailData.redirect_to || "";

  // URL oficial de verificación de Supabase Auth
  const actionUrl = `${supabaseUrl}/auth/v1/verify?token=${tokenHash}&type=${actionType}&redirect_to=${encodeURIComponent(redirectTo)}`;

  let title = "Bienvenido a la Tribu";
  let subject = "Confirma tu correo — Guaiqueríes de Margarita";
  let buttonText = "Confirmar correo electrónico";
  let explanation = "Gracias por registrarte en la plataforma oficial de Guaiqueríes de Margarita. Para activar tu cuenta y comenzar a acumular y canjear perlitas, por favor confirma tu dirección de correo.";

  if (actionType === "recovery") {
    title = "Restablecer contraseña";
    subject = "Restablece tu contraseña — Guaiqueríes de Margarita";
    buttonText = "Restablecer contraseña";
    explanation = "Recibimos una solicitud para restablecer la contraseña de tu cuenta en Guaiqueríes Fan Zone. Haz clic en el botón para crear una nueva contraseña.";
  } else if (actionType === "email_change") {
    title = "Cambio de correo";
    subject = "Confirma tu nuevo correo — Guaiqueríes de Margarita";
    buttonText = "Confirmar nuevo correo";
    explanation = "Recibimos una solicitud para actualizar tu dirección de correo electrónico en Guaiqueríes Fan Zone. Haz clic en el botón para confirmar este cambio.";
  } else if (actionType === "magiclink") {
    title = "Iniciar sesión";
    subject = "Enlace de acceso — Guaiqueríes de Margarita";
    buttonText = "Iniciar sesión";
    explanation = "Haz clic en el botón de abajo para acceder a tu cuenta sin contraseña.";
  }

  const html = `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }
    .container { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
    .header { background-color: #005a36; padding: 32px 24px; text-align: center; }
    .header h1 { color: #ffffff; margin: 0; font-size: 24px; letter-spacing: 0.5px; text-transform: uppercase; font-weight: 800; }
    .header p { color: #86efac; margin: 6px 0 0 0; font-size: 13px; font-weight: 500; }
    .content { padding: 32px 28px; }
    .greeting { font-size: 18px; font-weight: 700; margin-bottom: 12px; color: #0f172a; }
    .text { font-size: 15px; line-height: 1.6; color: #475569; margin-bottom: 24px; }
    .btn-container { text-align: center; margin: 28px 0; }
    .btn { display: inline-block; background-color: #005a36; color: #ffffff !important; text-decoration: none; font-weight: 700; font-size: 15px; padding: 14px 28px; border-radius: 10px; }
    .code-box { background-color: #f1f5f9; border: 1px dashed #cbd5e1; border-radius: 8px; padding: 16px; text-align: center; margin: 24px 0; }
    .code-label { font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: #64748b; margin-bottom: 6px; }
    .code-value { font-family: monospace; font-size: 26px; font-weight: 800; letter-spacing: 4px; color: #005a36; }
    .footer { border-top: 1px solid #f1f5f9; padding: 20px 28px; font-size: 12px; color: #94a3b8; text-align: center; background-color: #fafafa; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Guaiqueríes</h1>
      <p>Fan Zone Oficial — Nueva Esparta</p>
    </div>
    <div class="content">
      <div class="greeting">¡Hola!</div>
      <div class="text">${explanation}</div>
      <div class="btn-container">
        <a href="${actionUrl}" class="btn" target="_blank">${buttonText}</a>
      </div>
      ${token ? `
      <div class="code-box">
        <div class="code-label">O usa este código de confirmación:</div>
        <div class="code-value">${token}</div>
      </div>
      ` : ""}
      <div class="text" style="font-size: 13px; color: #94a3b8; margin-top: 24px;">
        Si no realizaste esta solicitud, puedes ignorar este correo de forma segura.
      </div>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} Guaiqueríes de Margarita B.B.C. Todos los derechos reservados.
    </div>
  </div>
</body>
</html>
  `.trim();

  return { subject, html };
}

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

    let body: SendEmailPayload = {};
    try {
      body = (await req.json()) as SendEmailPayload;
    } catch {
      // empty body
    }

    const isAuthHook = !!(body.user && body.email_data);
    let recipientEmail = "";
    let emailSubject = "";
    let emailHtml = "";
    let emailText = "";

    if (isAuthHook) {
      recipientEmail = body.user?.email || "";
      const generated = generateAuthEmail(supabaseUrl, body.user ?? {}, body.email_data ?? {});
      emailSubject = generated.subject;
      emailHtml = generated.html;
    } else {
      recipientEmail = body.to;
      emailSubject = body.subject || "Notificación de Guaiqueríes de Margarita";
      emailHtml = body.html || body.text;
      emailText = body.text;
    }

    if (!recipientEmail || (!emailHtml && !emailText)) {
      return new Response(
        JSON.stringify({ error: "Faltan parámetros del destinatario o contenido del correo." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Registrar intento y obtener la clave activa (1 o 2) mediante rotación en BD
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

    // 2. Despachar correo vía Resend API v1
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${activeApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Guaiqueríes de Margarita <onboarding@resend.dev>",
        to: Array.isArray(recipientEmail) ? recipientEmail : [recipientEmail],
        subject: emailSubject,
        html: emailHtml || emailText,
        text: emailText || undefined,
      }),
    });

    const resendData = await resendRes.json();

    if (!resendRes.ok) {
      return new Response(
        JSON.stringify({ error: resendData.message || "Error enviando correo vía Resend API." }),
        { status: resendRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Si es un Auth Hook de Supabase, la respuesta esperada es {} con 200
    if (isAuthHook) {
      return new Response(JSON.stringify({}), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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
  } catch (err: unknown) {
    const errorMessage = err instanceof Error ? err.message : "Error interno enviando correo.";
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
