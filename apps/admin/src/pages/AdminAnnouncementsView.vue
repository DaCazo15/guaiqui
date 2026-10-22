<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface AnnouncementRow {
  id: string
  message: string
  link_url?: string
  is_published: boolean
  starts_at: string
  ends_at?: string
  created_at: string
}

const announcements = ref<AnnouncementRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const form = ref({
  id: '',
  message: '',
  link_url: '',
  is_published: true,
  starts_at: '',
  ends_at: ''
})

const columns = [
  { key: 'message', label: 'Mensaje de la Cinta' },
  { key: 'link_url', label: 'Enlace' },
  { key: 'is_published', label: 'Publicado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadAnnouncements = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('site_announcements')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error
    announcements.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    message: '',
    link_url: '',
    is_published: true,
    starts_at: nowCaracasInput(),
    ends_at: ''
  }
  showEditorModal.value = true
}

const editRow = (row: AnnouncementRow) => {
  form.value = {
    id: row.id,
    message: row.message,
    link_url: row.link_url || '',
    is_published: row.is_published,
    starts_at: row.starts_at ? isoToCaracasInput(row.starts_at) : '',
    ends_at: row.ends_at ? isoToCaracasInput(row.ends_at) : ''
  }
  showEditorModal.value = true
}

const saveRow = async () => {
  if (!form.value.message) {
    errorMessage.value = 'El mensaje del anuncio es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      message: form.value.message,
      link_url: form.value.link_url || null,
      is_published: form.value.is_published,
      starts_at: form.value.starts_at ? caracasInputToISO(form.value.starts_at) : caracasInputToISO(nowCaracasInput()),
      ends_at: form.value.ends_at ? caracasInputToISO(form.value.ends_at) : null
    }

    if (form.value.id) {
      const { error } = await supabase.from('site_announcements').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('site_announcements').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Anuncio guardado correctamente.'
    showEditorModal.value = false
    await loadAnnouncements()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este anuncio?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('site_announcements').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Anuncio eliminado.'
    await loadAnnouncements()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadAnnouncements)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Cinta Superior de Anuncios</h1>
          <p class="text-sm text-slate-400 mt-1">Gestionar mensajes emergentes y promociones con vigencia en la cabecera de la landing.</p>
        </div>
        <BaseButton variant="primary" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Anuncio
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="announcements" :loading="loading" empty-text="No hay anuncios en la cinta">
        <template #cell-message="{ row }">
          <span class="font-semibold text-white">{{ (row as any).message }}</span>
        </template>

        <template #cell-link_url="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ (row as any).link_url || '-' }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="(row as any).is_published ? 'success' : 'soft'">
            {{ (row as any).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(row as any)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow((row as any).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Anuncio" @close="showEditorModal = false">
      <div class="space-y-4">
        <BaseInput label="Mensaje del Anuncio" v-model="form.message" placeholder="Ej: ¡Hoy jugamos en casa! Trivias abiertas..." />
        <BaseInput label="Enlace al hacer click (Opcional)" v-model="form.link_url" placeholder="https://..." />
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Válido Desde — Hora de Caracas (GMT-4)" type="datetime-local" v-model="form.starts_at" />
          <BaseInput label="Válido Hasta (Opcional) — Hora de Caracas (GMT-4)" type="datetime-local" v-model="form.ends_at" />
        </div>
        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Landing</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Anuncio</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
