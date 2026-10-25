<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { LandingCta } from '@guaiqui/shared'
import CtaTable from '../cta/CtaTable.vue'
import CtaEditorModal from '../cta/CtaEditorModal.vue'
import { DEFAULT_CTA_FORM, type CtaFormData } from '../cta/ctaTypes'

const ctas = ref<LandingCta[]>([])
const loading = ref(true)
const actionLoadingId = ref<string | null>(null)
const modalLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref<CtaFormData>({ ...DEFAULT_CTA_FORM })

const loadCtas = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('landing_ctas')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error
    ctas.value = (data as LandingCta[]) || []
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar los llamados a la acción.'
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  form.value = {
    ...DEFAULT_CTA_FORM,
    id: '',
    name: 'Nuevo Llamado ' + (ctas.value.length + 1)
  }
  showModal.value = true
}

const openEditModal = (item: LandingCta) => {
  form.value = {
    id: item.id,
    name: item.name,
    type: item.type,
    placement: item.placement || 'before_footer',
    is_active: item.is_active,
    is_published: item.is_published,
    badge_text: item.badge_text || '',
    heading: item.heading || '',
    subtitle: item.subtitle || '',
    button_text: item.button_text || '',
    button_url: item.button_url || '',
    bg_gradient: item.bg_gradient || DEFAULT_CTA_FORM.bg_gradient,
    bg_color: item.bg_color || '',
    phrase_text: item.phrase_text || '',
    font_family: item.font_family || DEFAULT_CTA_FORM.font_family,
    font_size: item.font_size || DEFAULT_CTA_FORM.font_size,
    letter_spacing: item.letter_spacing || DEFAULT_CTA_FORM.letter_spacing,
    font_weight: item.font_weight || DEFAULT_CTA_FORM.font_weight,
    text_color: item.text_color || DEFAULT_CTA_FORM.text_color,
    media_type: item.media_type || 'none',
    media_value: item.media_value || ''
  }
  showModal.value = true
}

const handleActivate = async (item: LandingCta) => {
  actionLoadingId.value = item.id
  try {
    const { error } = await supabase.rpc('activate_landing_cta', { p_id: item.id })
    if (error) throw error
    await loadCtas()
    successMessage.value = `CTA "${item.name}" ahora está activo en la landing page.`
    setTimeout(() => { successMessage.value = null }, 3500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al activar el llamado a la acción.'
  } finally {
    actionLoadingId.value = null
  }
}

const handleSave = async () => {
  if (!form.value.name.trim()) {
    errorMessage.value = 'El nombre descriptivo es obligatorio.'
    return
  }

  if (form.value.type === 'container' && !form.value.heading.trim()) {
    errorMessage.value = 'El título principal del contenedor es obligatorio.'
    return
  }

  if (form.value.type === 'phrase' && !form.value.phrase_text.trim()) {
    errorMessage.value = 'La frase destacada es obligatoria.'
    return
  }

  modalLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      name: form.value.name,
      type: form.value.type,
      placement: form.value.placement,
      is_published: true,
      badge_text: form.value.type === 'container' ? form.value.badge_text : null,
      heading: form.value.type === 'container' ? form.value.heading : null,
      subtitle: form.value.type === 'container' ? form.value.subtitle : null,
      button_text: form.value.type === 'container' ? form.value.button_text : null,
      button_url: form.value.type === 'container' ? form.value.button_url : null,
      bg_gradient: form.value.bg_color ? null : (form.value.bg_gradient || null),
      bg_color: form.value.bg_color || null,
      phrase_text: form.value.type === 'phrase' ? form.value.phrase_text : null,
      font_family: form.value.type === 'phrase' ? form.value.font_family : null,
      font_size: form.value.type === 'phrase' ? form.value.font_size : null,
      letter_spacing: form.value.type === 'phrase' ? form.value.letter_spacing : null,
      font_weight: form.value.type === 'phrase' ? form.value.font_weight : null,
      text_color: form.value.type === 'phrase' ? form.value.text_color : null,
      media_type: form.value.type === 'phrase' ? form.value.media_type : null,
      media_value: form.value.type === 'phrase' ? form.value.media_value : null,
      updated_at: new Date().toISOString()
    }

    if (form.value.id) {
      const { error } = await supabase
        .from('landing_ctas')
        .update(payload)
        .eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase
        .from('landing_ctas')
        .insert([{ ...payload, is_active: ctas.value.length === 0 }])
      if (error) throw error
    }

    showModal.value = false
    await loadCtas()
    successMessage.value = 'Llamado a la acción guardado con éxito.'
    setTimeout(() => { successMessage.value = null }, 3500)
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar el CTA.'
  } finally {
    modalLoading.value = false
  }
}

const handleDelete = async (item: LandingCta) => {
  if (item.is_active && ctas.value.length > 1) {
    alert('No puedes eliminar el CTA que está actualmente activo. Activa otro primero.')
    return
  }

  if (!confirm(`¿Eliminar definitivamente el CTA "${item.name}"?`)) return

  try {
    const { error } = await supabase
      .from('landing_ctas')
      .delete()
      .eq('id', item.id)

    if (error) throw error
    await loadCtas()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar el CTA.'
  }
}

onMounted(() => {
  loadCtas()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header Section -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-display uppercase tracking-wide text-white flex items-center gap-2">
          <i class="bi bi-megaphone-fill text-emerald-400"></i>
          Llamados a la Acción (CTA)
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Gestiona los bloques de llamado a la acción de la landing page. Alterna entre contenedores completos o frases de impacto.
        </p>
      </div>

      <BaseButton variant="primary" size="sm" @click="openCreateModal">
        <i class="bi bi-plus-lg mr-1.5"></i> Nuevo CTA
      </BaseButton>
    </div>

    <!-- Alerts -->
    <div v-if="successMessage" class="p-3 bg-emerald-950/60 border border-emerald-800 text-emerald-200 text-sm rounded-xl flex items-center gap-2">
      <i class="bi bi-check-circle-fill text-emerald-400"></i>
      <span>{{ successMessage }}</span>
    </div>

    <div v-if="errorMessage" class="p-3 bg-red-950/60 border border-red-800 text-red-200 text-sm rounded-xl flex items-center gap-2">
      <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
      <span>{{ errorMessage }}</span>
    </div>

    <!-- Table / Cards List -->
    <CtaTable
      :items="ctas"
      :loading="loading"
      :action-loading-id="actionLoadingId"
      @activate="handleActivate"
      @edit="openEditModal"
      @delete="handleDelete"
    />

    <!-- Editor Modal -->
    <CtaEditorModal
      :show="showModal"
      :form="form"
      :loading="modalLoading"
      :error-message="errorMessage"
      @close="showModal = false"
      @save="handleSave"
    />
  </div>
</template>
