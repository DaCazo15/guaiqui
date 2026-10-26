<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, BaseButton, BaseInput } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

const webhookUrl = 'https://mtxyracavyogxxljelvx.supabase.co/functions/v1/send-notifications'
const testEmail = ref('')
const isTesting = ref(false)
const testResult = ref<{ success: boolean; message: string; details?: any } | null>(null)
const isCopied = ref(false)

const copyWebhookUrl = () => {
  navigator.clipboard.writeText(webhookUrl)
  isCopied.value = true
  setTimeout(() => {
    isCopied.value = false
  }, 2000)
}

const sendTestEmail = async () => {
  if (!testEmail.value || !testEmail.value.includes('@')) {
    testResult.value = { success: false, message: 'Ingresa un correo electrónico válido.' }
    return
  }

  isTesting.value = true
  testResult.value = null

  try {
    const { data: userAuth } = await supabase.auth.getUser()
    const currentUserId = userAuth?.user?.id

    if (!currentUserId) {
      throw new Error('Debes haber iniciado sesión en el panel para enviar una prueba.')
    }

    // 1. Crear notificación temporal en la base de datos
    const { data: notifId, error: notifErr } = await supabase.rpc('create_notification', {
      p_user_id: currentUserId,
      p_type: 'new_trivia',
      p_title: 'Correo de Prueba — Guaiqueríes Fan Zone',
      p_body: `Esta es una prueba de envío automático vía Resend para el correo ${testEmail.value}. Tu configuración de notification_outbox está lista.`,
      p_data: { url: '/app/notificaciones', test: true },
      p_dedup_key: `test_email_${Date.now()}`
    })

    if (notifErr) throw notifErr

    // 2. Invocar la Edge Function send-notifications directamente
    const { data: edgeRes, error: edgeErr } = await supabase.functions.invoke('send-notifications', {
      body: { batch: true }
    })

    if (edgeErr) {
      testResult.value = {
        success: false,
        message: `Edge Function invocada con advertencia: ${edgeErr.message}`,
        details: edgeRes
      }
    } else {
      testResult.value = {
        success: true,
        message: '¡Notificación encolada y procesada por la Edge Function con éxito!',
        details: edgeRes
      }
    }
  } catch (err: any) {
    testResult.value = {
      success: false,
      message: err.message || 'Error al despachar correo de prueba.'
    }
  } finally {
    isTesting.value = false
  }
}
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-slate-900 border-slate-800 rounded-2xl space-y-5 shadow-lg">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-4">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-emerald-950 border border-emerald-700/60 flex items-center justify-center text-emerald-400 text-lg shrink-0">
          <i class="bi bi-envelope-at-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-bold text-base text-white">
            Canal de Correo Electrónico & Webhook (notification_outbox)
          </h3>
          <p class="text-xs text-slate-400 mt-0.5">
            Configuración lista para despachar correos cuando vincules tu dominio en Resend / Send.
          </p>
        </div>
      </div>

      <span class="px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-950 text-emerald-300 border border-emerald-800 flex items-center gap-1.5 self-start sm:self-auto">
        <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
        <span>Edge Function Activa</span>
      </span>
    </div>

    <!-- Webhook info box -->
    <div class="space-y-3">
      <label class="block text-xs font-bold text-slate-300">
        URL del Webhook de Supabase (Database Webhook / Edge Function):
      </label>
      <div class="flex items-center gap-2">
        <input
          type="text"
          readonly
          :value="webhookUrl"
          class="flex-1 px-3 py-2 text-xs bg-slate-950 text-emerald-300 font-mono rounded-xl border border-slate-700 focus:outline-none select-all"
        />
        <BaseButton
          variant="secondary"
          size="sm"
          @click="copyWebhookUrl"
          class="shrink-0"
        >
          <i :class="['bi', isCopied ? 'bi-check-lg text-emerald-400' : 'bi-clipboard']"></i>
          <span class="ms-1">{{ isCopied ? 'Copiado' : 'Copiar URL' }}</span>
        </BaseButton>
      </div>
    </div>

    <!-- Instructions when custom domain is ready -->
    <div class="p-4 bg-slate-950/80 border border-slate-800 rounded-xl space-y-2 text-xs text-slate-300">
      <div class="flex items-center gap-1.5 font-bold text-white">
        <i class="bi bi-globe2 text-emerald-400"></i>
        <span>Paso final: Cuando verifiques tu dominio en Resend (Send)</span>
      </div>
      <p class="leading-relaxed text-slate-400">
        Cuando configures tu dominio (por ejemplo <code class="text-emerald-300 font-mono">send.guaiqueries.com</code> o <code class="text-emerald-300 font-mono">guaiqueries.com</code>):
      </p>
      <ol class="list-decimal list-inside space-y-1 text-slate-400 pl-1">
        <li>Agrega el secreto en Supabase: <code class="text-emerald-300 font-mono">RESEND_DOMAIN = "send.guaiqueries.com"</code> (o <code class="text-emerald-300 font-mono">RESEND_FROM_EMAIL = "Guaiqueríes &lt;notificaciones@send.guaiqueries.com&gt;"</code>).</li>
        <li>El sistema cambiará el remitente automáticamente desde <code class="text-slate-300 font-mono">onboarding@resend.dev</code> hacia tu dominio oficial verificado sin requerir ningún cambio de código.</li>
      </ol>
    </div>

    <!-- Test dispatch section -->
    <div class="pt-2 border-t border-slate-800 space-y-3">
      <div class="flex items-center gap-2">
        <span class="text-xs font-bold text-white">Probar Envío de Correo de Notificación:</span>
        <span class="text-[11px] text-slate-500">(Genera una fila en notification_outbox e invoca la función)</span>
      </div>

      <div class="flex flex-col sm:flex-row items-center gap-2">
        <BaseInput
          v-model="testEmail"
          type="email"
          placeholder="tu-correo@ejemplo.com"
          class="w-full sm:flex-1"
        />
        <BaseButton
          variant="primary"
          size="sm"
          @click="sendTestEmail"
          :disabled="isTesting || !testEmail"
          class="w-full sm:w-auto shrink-0"
        >
          <i :class="['bi', isTesting ? 'bi-arrow-clockwise animate-spin' : 'bi-send-fill', 'me-1']"></i>
          <span>{{ isTesting ? 'Enviando...' : 'Enviar Prueba' }}</span>
        </BaseButton>
      </div>

      <div
        v-if="testResult"
        :class="[
          'p-3 rounded-xl text-xs flex items-start gap-2 border',
          testResult.success ? 'bg-emerald-950/70 text-emerald-300 border-emerald-800/80' : 'bg-rose-950/70 text-rose-300 border-rose-800/80'
        ]"
      >
        <i :class="['bi', testResult.success ? 'bi-check-circle-fill' : 'bi-exclamation-triangle-fill', 'text-sm mt-0.5 shrink-0']"></i>
        <div class="space-y-1">
          <span class="font-bold block">{{ testResult.message }}</span>
          <pre v-if="testResult.details" class="text-[10px] bg-black/40 p-2 rounded-lg font-mono overflow-x-auto text-slate-300">{{ JSON.stringify(testResult.details, null, 2) }}</pre>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
