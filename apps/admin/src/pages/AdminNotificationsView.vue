<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import NotificationTemplateCard from '../components/notifications/NotificationTemplateCard.vue'
import NotificationTemplateEditModal from '../components/notifications/NotificationTemplateEditModal.vue'
import NotificationEmailWebhookCard from '../components/notifications/NotificationEmailWebhookCard.vue'
import { supabase } from '../lib/supabase'
import type { NotificationTemplate } from '@guaiqui/shared'

const templates = ref<NotificationTemplate[]>([])
const loading = ref(false)
const saving = ref(false)
const selectedTemplate = ref<NotificationTemplate | null>(null)
const isEditModalOpen = ref(false)
const feedbackMessage = ref<string | null>(null)
const feedbackType = ref<'success' | 'error'>('success')

const fetchTemplates = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('notification_templates')
      .select('*')
      .order('category', { ascending: true })

    if (error) throw error
    templates.value = (data as NotificationTemplate[]) || []
  } catch (err: any) {
    feedbackType.value = 'error'
    feedbackMessage.value = err.message || 'Error al cargar las plantillas de notificación'
  } finally {
    loading.value = false
  }
}

const openEditModal = (tmpl: NotificationTemplate) => {
  selectedTemplate.value = tmpl
  isEditModalOpen.value = true
}

const handleSaveTemplate = async (payload: { id: string; title_template: string; body_template: string; is_active: boolean }) => {
  saving.value = true
  feedbackMessage.value = null

  try {
    const { data, error } = await supabase.rpc('admin_update_notification_template', {
      p_template_id: payload.id,
      p_title_template: payload.title_template,
      p_body_template: payload.body_template,
      p_is_active: payload.is_active
    })

    if (error) throw error

    feedbackType.value = 'success'
    feedbackMessage.value = 'Plantilla de notificación actualizada correctamente.'
    isEditModalOpen.value = false
    await fetchTemplates()
  } catch (err: any) {
    feedbackType.value = 'error'
    feedbackMessage.value = err.message || 'Error al guardar los cambios en la plantilla'
  } finally {
    saving.value = false
  }
}

const handleToggleActive = async (tmpl: NotificationTemplate) => {
  try {
    const { error } = await supabase.rpc('admin_update_notification_template', {
      p_template_id: tmpl.id,
      p_title_template: tmpl.title_template,
      p_body_template: tmpl.body_template,
      p_is_active: !tmpl.is_active
    })

    if (error) throw error

    tmpl.is_active = !tmpl.is_active
    feedbackType.value = 'success'
    feedbackMessage.value = `Plantilla "${tmpl.id}" ${tmpl.is_active ? 'activada' : 'desactivada'}.`
  } catch (err: any) {
    feedbackType.value = 'error'
    feedbackMessage.value = err.message || 'Error al cambiar estado'
  }
}

onMounted(() => {
  fetchTemplates()
})
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-bell-fill text-emerald-400"></i>
            <span>Gestión de Notificaciones Automatizadas</span>
          </h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Modifica las plantillas y mensajes que el sistema envía automáticamente a los fanáticos ante nuevas trivias, alertas de expiración y resolución de perlitas retenidas.
          </p>
        </div>
      </div>

      <!-- Feedback Banner -->
      <div
        v-if="feedbackMessage"
        :class="[
          'p-3.5 rounded-xl text-xs font-semibold flex items-center justify-between border shadow-sm',
          feedbackType === 'success'
            ? 'bg-emerald-950/70 border-emerald-700/60 text-emerald-300'
            : 'bg-rose-950/70 border-rose-700/60 text-rose-300'
        ]"
      >
        <div class="flex items-center gap-2">
          <i :class="['bi', feedbackType === 'success' ? 'bi-check-circle-fill' : 'bi-exclamation-triangle-fill']"></i>
          <span>{{ feedbackMessage }}</span>
        </div>
        <button type="button" @click="feedbackMessage = null" class="text-slate-400 hover:text-white">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <!-- Informative Note -->
      <div class="p-4 bg-slate-900/60 border border-slate-800 rounded-2xl flex items-start gap-3">
        <div class="w-8 h-8 rounded-lg bg-emerald-950 text-emerald-400 border border-emerald-800/60 flex items-center justify-center shrink-0 text-base">
          <i class="bi bi-info-circle-fill"></i>
        </div>
        <div class="text-xs text-slate-300 leading-relaxed">
          <span class="font-bold text-white block mb-0.5">Comportamiento del Módulo de Notificaciones:</span>
          Las notificaciones del sistema son eventos automáticos desencadenados por el ciclo de vida del club (publicación de trivias, fechas de cierre, liberación o rechazo de perlitas retenidas). En esta sección puedes personalizar el contenido, títulos y variables de cada mensaje sin alterar la lógica de negocio.
        </div>
      </div>

      <!-- Email Channel & Webhook Configuration -->
      <NotificationEmailWebhookCard />

      <!-- Loading State -->
      <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div v-for="i in 4" :key="i" class="p-6 bg-slate-900 border border-slate-800 rounded-2xl animate-pulse h-64"></div>
      </div>

      <!-- Templates Grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <NotificationTemplateCard
          v-for="tmpl in templates"
          :key="tmpl.id"
          :template="tmpl"
          @edit="openEditModal"
          @toggle-active="handleToggleActive"
        />
      </div>

      <!-- Edit Modal -->
      <NotificationTemplateEditModal
        v-model="isEditModalOpen"
        :template="selectedTemplate"
        :loading="saving"
        @save="handleSaveTemplate"
      />
    </div>
  </AdminLayout>
</template>
