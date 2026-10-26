// Supabase Edge Function: send-notifications
// Handles both Database Webhook calls on notification_outbox INSERT and batch cron processing for Push and Email channels.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'https://esm.sh/web-push@3.6.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export interface PushSub {
  id: string
  endpoint: string
  p256dh: string
  auth: string
}

function buildHtmlEmail(params: {
  title: string
  body: string
  userName: string
  actionUrl: string
  actionLabel?: string
}) {
  const { title, body, userName, actionUrl, actionLabel = 'Ir a la Plataforma' } = params

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #020617; margin: 0; padding: 24px; color: #f8fafc; }
    .container { max-width: 580px; margin: 0 auto; background: #0f172a; border-radius: 20px; border: 1px solid #1e293b; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5); }
    .header { background: linear-gradient(135deg, #022c22 0%, #064e3b 100%); padding: 32px 24px; text-align: center; border-bottom: 2px solid #059669; }
    .header h1 { color: #ffffff; margin: 0; font-size: 26px; letter-spacing: 1px; text-transform: uppercase; font-weight: 800; }
    .header p { color: #6ee7b7; margin: 6px 0 0 0; font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
    .content { padding: 32px 28px; background: #0f172a; }
    .greeting { font-size: 18px; font-weight: 700; margin-bottom: 14px; color: #f1f5f9; }
    .title-box { background-color: #1e293b; border-left: 4px solid #10b981; padding: 14px 18px; border-radius: 8px; margin-bottom: 20px; }
    .title-text { font-size: 16px; font-weight: 700; color: #ffffff; margin: 0; }
    .body-text { font-size: 15px; line-height: 1.6; color: #cbd5e1; margin-bottom: 26px; }
    .btn-container { text-align: center; margin: 28px 0; }
    .btn { display: inline-block; background-color: #059669; color: #ffffff !important; text-decoration: none; font-weight: 700; font-size: 15px; padding: 14px 32px; border-radius: 12px; box-shadow: 0 4px 12px rgba(5, 150, 105, 0.4); }
    .footer { border-top: 1px solid #1e293b; padding: 20px 28px; font-size: 12px; color: #64748b; text-align: center; background-color: #020617; }
    .footer p { margin: 4px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Guaiqueríes</h1>
      <p>Fan Zone Oficial — La Tribu</p>
    </div>
    <div class="content">
      <div class="greeting">¡Hola, ${userName}!</div>
      <div class="title-box">
        <p class="title-text">${title}</p>
      </div>
      <div class="body-text">${body}</div>
      <div class="btn-container">
        <a href="${actionUrl}" class="btn" target="_blank">${actionLabel}</a>
      </div>
    </div>
    <div class="footer">
      <p>Guaiqueríes de Margarita BBC — Isla de Margarita, Venezuela</p>
      <p>Este es un correo automático generado por la plataforma de fidelización de fanáticos.</p>
    </div>
  </div>
</body>
</html>`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Faltan variables de entorno de Supabase.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Configuración VAPID para Web Push
    const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY') || ''
    const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY') || ''
    const vapidSubject = Deno.env.get('VAPID_SUBJECT') || 'mailto:soporte@guaiqueries.com'

    if (vapidPublicKey && vapidPrivateKey) {
      try {
        webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey)
      } catch (err) {
        console.warn('VAPID setup warning:', err)
      }
    }

    // Configuración de Remitente de Correo Dinámico para Resend / Send Domain
    const configuredFrom = Deno.env.get('RESEND_FROM_EMAIL')
    const configuredDomain = Deno.env.get('RESEND_DOMAIN')
    const fromSender = configuredFrom ||
      (configuredDomain
        ? `Guaiqueríes de Margarita <notificaciones@${configuredDomain}>`
        : 'Guaiqueríes de Margarita <onboarding@resend.dev>')

    // 1. Detectar si la invocación proviene de un Database Webhook (INSERT en notification_outbox)
    let webhookRecordId: string | null = null
    if (req.method === 'POST') {
      try {
        const payload = await req.json()
        if (payload?.type === 'INSERT' && payload?.table === 'notification_outbox' && payload?.record?.id) {
          webhookRecordId = payload.record.id
        } else if (payload?.outbox_id) {
          webhookRecordId = payload.outbox_id
        }
      } catch {
        // Invocación GET o cuerpo vacío: se procede a procesar el lote por cron
      }
    }

    // 2. Consultar registros de outbox pendientes
    let query = supabaseAdmin
      .from('notification_outbox')
      .select(`
        id,
        notification_id,
        channel,
        attempts,
        notifications!inner (
          id,
          user_id,
          type,
          title,
          body,
          data
        )
      `)

    if (webhookRecordId) {
      query = query.eq('id', webhookRecordId)
    } else {
      query = query
        .eq('status', 'pending')
        .lte('next_attempt_at', new Date().toISOString())
        .limit(50)
    }

    const { data: outboxItems, error: fetchErr } = await query

    if (fetchErr) {
      throw fetchErr
    }

    const processedCount = outboxItems?.length || 0
    const results = []

    for (const item of outboxItems || []) {
      const notif = (item as any).notifications
      const attempts = (item.attempts || 0) + 1

      // ==========================================
      // CANAL 1: PUSH NOTIFICATIONS
      // ==========================================
      if (item.channel === 'push') {
        const { data: subs } = await supabaseAdmin
          .from('push_subscriptions')
          .select('id, endpoint, p256dh, auth')
          .eq('user_id', notif.user_id)
          .is('disabled_at', null)

        if (!subs || subs.length === 0) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'No active push subscriptions found' })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'push', status: 'skipped' })
          continue
        }

        let pushSuccessCount = 0
        let lastError = ''

        for (const sub of subs as PushSub[]) {
          try {
            if (vapidPublicKey && vapidPrivateKey) {
              const pushPayload = JSON.stringify({
                title: notif.title,
                body: notif.body,
                data: notif.data,
              })

              await webpush.sendNotification(
                {
                  endpoint: sub.endpoint,
                  keys: {
                    p256dh: sub.p256dh,
                    auth: sub.auth,
                  },
                },
                pushPayload
              )

              await supabaseAdmin
                .from('push_subscriptions')
                .update({ last_success_at: new Date().toISOString() })
                .eq('id', sub.id)

              pushSuccessCount++
            } else {
              pushSuccessCount++
            }
          } catch (pushErr: any) {
            lastError = pushErr.message || 'Push dispatch error'
            if (pushErr.statusCode === 410 || pushErr.statusCode === 404) {
              await supabaseAdmin
                .from('push_subscriptions')
                .update({ disabled_at: new Date().toISOString() })
                .eq('id', sub.id)
            }
          }
        }

        if (pushSuccessCount > 0) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'sent', sent_at: new Date().toISOString(), attempts, error: null })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'push', status: 'sent', count: pushSuccessCount })
        } else {
          if (attempts >= 5) {
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'failed', attempts, error: lastError || 'Max retries reached' })
              .eq('id', item.id)
            results.push({ id: item.id, channel: 'push', status: 'failed' })
          } else {
            const nextAttempt = new Date(Date.now() + attempts * 5 * 60 * 1000).toISOString()
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'pending', attempts, next_attempt_at: nextAttempt, error: lastError })
              .eq('id', item.id)
            results.push({ id: item.id, channel: 'push', status: 'pending_retry' })
          }
        }
      }
      // ==========================================
      // CANAL 2: EMAIL NOTIFICATIONS (Send / Resend)
      // ==========================================
      else if (item.channel === 'email') {
        const emailServiceExplicitlyDisabled = Deno.env.get('EMAIL_SERVICE_ENABLED') === 'false'
        const resendKey1 = Deno.env.get('RESEND_API_KEY_1') || ''
        const resendKey2 = Deno.env.get('RESEND_API_KEY_2') || ''

        if (emailServiceExplicitlyDisabled) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'Email service explicitly disabled via env' })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'email', status: 'skipped' })
          continue
        }

        // Consultar correo del usuario destinatario
        const { data: userProfile } = await supabaseAdmin
          .from('profiles')
          .select('id, display_name')
          .eq('id', notif.user_id)
          .single()

        const { data: authUser } = await supabaseAdmin.auth.admin.getUserById(notif.user_id)
        const targetEmail = authUser?.user?.email

        if (!targetEmail) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'Recipient email not found in auth' })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'email', status: 'skipped' })
          continue
        }

        // Registrar intento de envío y obtener clave activa (1 o 2)
        const { data: trackerData, error: trackerErr } = await supabaseAdmin.rpc('register_email_send_attempt')

        if (trackerErr) {
          const isMaintenance = trackerErr.message?.includes('Servicio en mantenimiento') || trackerErr.code === 'P0001'
          await supabaseAdmin
            .from('notification_outbox')
            .update({
              status: isMaintenance ? 'failed' : 'pending',
              attempts,
              error: trackerErr.message,
            })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'email', status: isMaintenance ? 'failed' : 'pending_retry', error: trackerErr.message })
          continue
        }

        const activeApiKey = trackerData?.key_index === 2 ? resendKey2 : resendKey1

        if (!activeApiKey) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'Resend API key not configured yet' })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'email', status: 'skipped', reason: 'no_api_key' })
          continue
        }

        // URL de destino en la plataforma
        const siteUrl = Deno.env.get('SITE_URL') || 'https://guaiqueries.com'
        const relativeUrl = notif.data?.url || '/app/notificaciones'
        const actionUrl = relativeUrl.startsWith('http') ? relativeUrl : `${siteUrl}${relativeUrl}`

        const htmlContent = buildHtmlEmail({
          title: notif.title || 'Notificación Guaiqueríes',
          body: notif.body || '',
          userName: userProfile?.display_name || 'Fanático',
          actionUrl,
        })

        // Enviar vía Resend API v1
        const resendRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${activeApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: fromSender,
            to: [targetEmail],
            subject: notif.title || 'Notificación Guaiqueríes',
            html: htmlContent,
          }),
        })

        if (resendRes.ok) {
          const resendData = await resendRes.json()
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'sent', sent_at: new Date().toISOString(), attempts, error: null })
            .eq('id', item.id)

          results.push({ id: item.id, channel: 'email', status: 'sent', resend_id: resendData.id, from: fromSender })
        } else {
          const errBody = await resendRes.json()
          const errMsg = errBody.message || 'Resend API Error'

          if (attempts >= 5) {
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'failed', attempts, error: errMsg })
              .eq('id', item.id)
            results.push({ id: item.id, channel: 'email', status: 'failed', error: errMsg })
          } else {
            const nextAttempt = new Date(Date.now() + attempts * 5 * 60 * 1000).toISOString()
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'pending', attempts, next_attempt_at: nextAttempt, error: errMsg })
              .eq('id', item.id)
            results.push({ id: item.id, channel: 'email', status: 'pending_retry', error: errMsg })
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        webhook_triggered: Boolean(webhookRecordId),
        processed: processedCount,
        sender_configured: fromSender,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || 'Error procesando outbox de notificaciones.' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
