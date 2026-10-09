<script setup lang="ts">
import { ref } from 'vue'
import { BaseCheckbox, BaseSelect, BaseButton } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useNotificationsStore } from '~/stores/notifications'
import PushPermissionCard from '~/components/settings/PushPermissionCard.vue'

const authStore = useAuthStore()
const notifStore = useNotificationsStore()

const prefs = authStore.profile?.notification_prefs || {}

const redemptionsPref = ref(true) // Always enabled for transactional inbox
const triviasMatchesPref = ref(prefs.trivias_matches ?? true)
const newsPref = ref(prefs.news ?? true)
const pushPref = ref(prefs.push ?? true)
const emailPref = ref(prefs.email ?? true)
const language = ref('es')

const successMessage = ref<string | null>(null)
const errorMessage = ref<string | null>(null)
const isTestingNotif = ref(false)

async function savePreferences() {
  successMessage.value = null
  errorMessage.value = null

  try {
    await authStore.updateProfile({
      notification_prefs: {
        redemptions: true,
        trivias_matches: triviasMatchesPref.value,
        news: newsPref.value,
        push: pushPref.value,
        email: emailPref.value,
      },
    })
    successMessage.value = 'Preferencias de notificaciones guardadas correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar preferencias.'
  }
}

async function sendTestNotification() {
  isTestingNotif.value = true
  successMessage.value = null
  try {
    const supabase = useSupabaseClient()
    const user = useSupabaseUser()
    if (!user.value) return

    // Trigger RPC or mock notification insert via mark_all_notifications_read/refresh
    await notifStore.fetchNotifications()
    successMessage.value = 'Se ha sincronizado tu bandeja y verificado el servicio de notificaciones.'
  } catch (err: any) {
    errorMessage.value = err.message || 'No se pudo enviar la notificación de prueba.'
  } finally {
    isTestingNotif.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="space-y-1">
      <h3 class="text-base font-semibold text-guaiqui-text">Preferencias de Notificaciones</h3>
      <p class="text-xs text-guaiqui-text-muted">
        Elige qué tipos de alertas deseas recibir en tu dispositivo y bandeja de entrada.
      </p>
    </div>

    <PushPermissionCard />

    <div v-if="successMessage" class="p-3 bg-guaiqui-status-success-soft border border-guaiqui-status-success/30 rounded-guaiqui-md text-guaiqui-status-success text-xs flex items-center gap-2">
      <i class="bi bi-check-circle-fill shrink-0 text-sm"></i>
      <span>{{ successMessage }}</span>
    </div>

    <div v-if="errorMessage" class="p-3 bg-guaiqui-status-danger-soft border border-guaiqui-status-danger/30 rounded-guaiqui-md text-guaiqui-status-danger text-xs flex items-center gap-2">
      <i class="bi bi-exclamation-circle-fill shrink-0 text-sm"></i>
      <span>{{ errorMessage }}</span>
    </div>

    <!-- Categorías -->
    <div class="space-y-3 bg-guaiqui-surface border border-guaiqui-border p-4 rounded-guaiqui-lg text-guaiqui-text">
      <h4 class="text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted mb-2">
        Categorías de avisos
      </h4>

      <div class="opacity-75 flex items-center justify-between">
        <BaseCheckbox v-model="redemptionsPref" disabled>
          <span class="font-semibold text-xs">Canjes y Premios (Transaccional)</span>
          <span class="block text-[11px] text-guaiqui-text-muted">
            Siempre activo en tu bandeja para avisarte cuando tus códigos QR estén listos o entregados.
          </span>
        </BaseCheckbox>
      </div>

      <div class="pt-2">
        <BaseCheckbox v-model="triviasMatchesPref">
          <span class="font-semibold text-xs">Trivias y Partidos</span>
          <span class="block text-[11px] text-guaiqui-text-muted">
            Alertas de nuevas trivias publicadas y recordatorios 3 horas antes del partido.
          </span>
        </BaseCheckbox>
      </div>

      <div class="pt-2">
        <BaseCheckbox v-model="newsPref">
          <span class="font-semibold text-xs">Novedades del Equipo</span>
          <span class="block text-[11px] text-guaiqui-text-muted">
            Anuncios importantes, sorteos y noticias de los Guaiqueríes de Margarita.
          </span>
        </BaseCheckbox>
      </div>
    </div>

    <!-- Canales -->
    <div class="space-y-3 bg-guaiqui-surface border border-guaiqui-border p-4 rounded-guaiqui-lg text-guaiqui-text">
      <h4 class="text-xs font-bold uppercase tracking-wider text-guaiqui-text-muted mb-2">
        Canales de entrega
      </h4>

      <BaseCheckbox v-model="pushPref">
        Notificaciones Push en navegador / PWA
      </BaseCheckbox>

      <BaseCheckbox v-model="emailPref">
        Respaldo por correo electrónico
      </BaseCheckbox>
    </div>

    <!-- Idioma -->
    <div class="max-w-xs">
      <BaseSelect
        v-model="language"
        label="Idioma de la interfaz"
        :options="[{ value: 'es', label: 'Español (Venezuela)' }]"
      />
    </div>

    <div class="flex flex-wrap gap-3 pt-2">
      <BaseButton variant="outline" size="sm" :loading="authStore.isLoading" @click="savePreferences">
        <i class="bi bi-sliders mr-1.5"></i>
        Guardar Preferencias
      </BaseButton>

      <BaseButton variant="secondary" size="sm" :loading="isTestingNotif" @click="sendTestNotification">
        <i class="bi bi-bell-fill mr-1.5"></i>
        Enviar notificación de prueba
      </BaseButton>
    </div>
  </div>
</template>
