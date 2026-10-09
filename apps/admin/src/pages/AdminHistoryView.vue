<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface MilestoneRow {
  id: string
  year: string
  title: string
  text: string
  image_url?: string
  order_index: number
  is_published: boolean
  created_at: string
}

const milestones = ref<MilestoneRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const form = ref({
  id: '',
  year: '1977',
  title: '',
  text: '',
  image_url: '',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'year', label: 'Año / Época', align: 'center' as const, width: '100px' },
  { key: 'title', label: 'Hito Histórico' },
  { key: 'is_published', label: 'Publicado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadMilestones = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('history_milestones')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    milestones.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    year: '1977',
    title: '',
    text: '',
    image_url: '',
    order_index: milestones.value.length,
    is_published: true
  }
  showEditorModal.value = true
}

const editRow = (row: MilestoneRow) => {
  form.value = {
    id: row.id,
    year: row.year,
    title: row.title,
    text: row.text,
    image_url: row.image_url || '',
    order_index: row.order_index,
    is_published: row.is_published
  }
  showEditorModal.value = true
}

const saveRow = async () => {
  if (!form.value.title || !form.value.year) {
    errorMessage.value = 'El año y el título son obligatorios.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      year: form.value.year,
      title: form.value.title,
      text: form.value.text,
      image_url: form.value.image_url || null,
      order_index: Number(form.value.order_index),
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('history_milestones').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('history_milestones').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Hito histórico guardado correctamente.'
    showEditorModal.value = false
    await loadMilestones()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este hito histórico?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('history_milestones').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Hito eliminado.'
    await loadMilestones()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadMilestones)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Historia y Cronología del Club</h1>
          <p class="text-sm text-slate-400">Gestionar hitos históricos para la sección /historia del sitio.</p>
        </div>
        <BaseButton variant="primary" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Hito
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="milestones" :loading="loading" empty-text="No hay hitos registrados">
        <template #cell-year="{ row }">
          <span class="font-mono font-bold text-amber-400">{{ (row as any).year }}</span>
        </template>

        <template #cell-title="{ row }">
          <div class="font-semibold text-slate-100">{{ (row as any).title }}</div>
          <div class="text-xs text-slate-400 truncate max-w-md">{{ (row as any).text }}</div>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="(row as any).is_published ? 'success' : 'soft'">
            {{ (row as any).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(row as any)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow((row as any).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Hito Histórico" @close="showEditorModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Año / Período" v-model="form.year" placeholder="1977 o 1978 - 1982" />
          <BaseInput label="Orden (#)" type="number" v-model="form.order_index" />
        </div>
        <BaseInput label="Título del Hito" v-model="form.title" placeholder="Ej: Fundación del Club" />
        <BaseInput label="Texto / Descripción" v-model="form.text" placeholder="Reseña histórica..." />
        
        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Web</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Hito</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
