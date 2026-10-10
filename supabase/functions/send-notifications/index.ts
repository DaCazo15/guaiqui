// Supabase Edge Function: send-notifications
// Batch processes pending notifications from notification_outbox for Push and Email channels.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'https://esm.sh/web-push@3.6.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export interface SendPushPayload {
  title: string
  body: string
  data?: Record<string, any>
}

export interface PushSub {
  id: string
  endpoint: string
  p256dh: string
  auth: string
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

    // Configuración VAPID
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

    // 1. Consultar lote de outbox pendiente (máx 50)
    const { data: outboxItems, error: fetchErr } = await supabaseAdmin
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
      .eq('status', 'pending')
      .lte('next_attempt_at', new Date().toISOString())
      .limit(50)

    if (fetchErr) {
      throw fetchErr
    }

    const processedCount = outboxItems?.length || 0
    const results = []

    for (const item of outboxItems || []) {
      const notif = (item as any).notifications
      const attempts = (item.attempts || 0) + 1

      if (item.channel === 'push') {
        // Consultar suscripciones activas del usuario
        const { data: subs } = await supabaseAdmin
          .from('push_subscriptions')
          .select('id, endpoint, p256dh, auth')
          .eq('user_id', notif.user_id)
          .is('disabled_at', null)

        if (!subs || subs.length === 0) {
          // El usuario no tiene dispositivos push registrados activos
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'No active push subscriptions found' })
            .eq('id', item.id)

          results.push({ id: item.id, status: 'skipped' })
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

              // Actualizar fecha de éxito en la suscripción
              await supabaseAdmin
                .from('push_subscriptions')
                .update({ last_success_at: new Date().toISOString() })
                .eq('id', sub.id)

              pushSuccessCount++
            } else {
              // Modo desarrollo/sin llaves VAPID configuradas en env
              pushSuccessCount++
            }
          } catch (pushErr: any) {
            const statusCode = pushErr.statusCode || pushErr.status
            lastError = pushErr.message || String(pushErr)

            if (statusCode === 404 || statusCode === 410) {
              // Endpoint expiró o no existe: desactivar suscripción
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
            .update({
              status: 'sent',
              sent_at: new Date().toISOString(),
              attempts,
              error: null,
            })
            .eq('id', item.id)

          results.push({ id: item.id, status: 'sent' })
        } else {
          // Fallaron todos los envíos
          if (attempts >= 5) {
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'failed', attempts, error: lastError || 'Max retries reached' })
              .eq('id', item.id)
            results.push({ id: item.id, status: 'failed' })
          } else {
            // Reintento con espera creciente (attempts * 5 min)
            const nextAttempt = new Date(Date.now() + attempts * 5 * 60 * 1000).toISOString()
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'pending', attempts, next_attempt_at: nextAttempt, error: lastError })
              .eq('id', item.id)
            results.push({ id: item.id, status: 'pending_retry' })
          }
        }
      } else if (item.channel === 'email') {
        const emailEnabled = Deno.env.get('EMAIL_SERVICE_ENABLED') === 'true'
        const resendKey1 = Deno.env.get('RESEND_API_KEY_1') || ''
        const resendKey2 = Deno.env.get('RESEND_API_KEY_2') || ''

        if (!emailEnabled) {
          await supabaseAdmin
            .from('notification_outbox')
            .update({ status: 'skipped', error: 'Email service interface disabled' })
            .eq('id', item.id)

          results.push({ id: item.id, status: 'skipped' })
        } else {
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
              .update({ status: 'skipped', error: 'Recipient email not found' })
              .eq('id', item.id)

            results.push({ id: item.id, status: 'skipped' })
            continue
          }

          // Registrar intento de envío y obtener clave activa (1 o 2)
          const { data: trackerData, error: trackerErr } = await supabaseAdmin.rpc('register_email_send_attempt')

          if (trackerErr) {
            const isMaintenance = trackerErr.message.includes('Servicio en mantenimiento') || trackerErr.code === 'P0001'
            await supabaseAdmin
              .from('notification_outbox')
              .update({
                status: isMaintenance ? 'failed' : 'pending',
                attempts,
                error: trackerErr.message
              })
              .eq('id', item.id)

            results.push({ id: item.id, status: isMaintenance ? 'failed' : 'pending_retry', error: trackerErr.message })
            continue
          }

          const activeApiKey = (trackerData?.key_index === 2) ? resendKey2 : resendKey1

          // Enviar vía Resend API v1
          const resendRes = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${activeApiKey}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              from: 'Guaiqueríes de Margarita <onboarding@resend.dev>',
              to: [targetEmail],
              subject: notif.title || 'Notificación Guaiqueríes',
              html: `<p>Hola ${userProfile?.display_name || 'Fanático'},</p><p>${notif.body}</p>`,
            })
          })

          if (resendRes.ok) {
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'sent', sent_at: new Date().toISOString(), attempts, error: null })
              .eq('id', item.id)

            results.push({ id: item.id, status: 'sent' })
          } else {
            const errBody = await resendRes.json()
            await supabaseAdmin
              .from('notification_outbox')
              .update({ status: 'pending', attempts, error: errBody.message || 'Resend API Error' })
              .eq('id', item.id)

            results.push({ id: item.id, status: 'pending_retry' })
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        processed: processedCount,
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
