<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'

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
  { key: 'year', label: 'Año / Época', align: 'center' as const, width: '120px' },
  { key: 'title', label: 'Hito Histórico' },
  { key: 'is_published', label: 'Publicado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadMilestones = async () => {
  loading.value = true
  errorMessage.value = null
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
    order_index: milestones.value.length + 1,
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
      successMessage.value = 'Hito histórico actualizado correctamente.'
    } else {
      const { error } = await supabase.from('history_milestones').insert(payload)
      if (error) throw error
      successMessage.value = 'Nuevo hito agregado a la línea temporal.'
    }

    showEditorModal.value = false
    await loadMilestones()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este hito histórico de la línea de tiempo?')) return
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

onMounted(() => {
  loadMilestones()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-hourglass-split text-emerald-400"></i>
          Línea de Tiempo y Cronología
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Hitos cronológicos de la historia de Guaiqueríes de Margarita desde su fundación.
        </p>
      </div>
      <BaseButton variant="primary" size="sm" @click="openNew">
        <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Hito
      </BaseButton>
    </div>

    <!-- Alerts -->
    <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-sm flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-sm flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <BaseTable :columns="columns" :data="milestones" :loading="loading" empty-text="No hay hitos registrados">
      <template #cell-year="{ row }">
        <span class="font-mono font-bold text-emerald-400 bg-slate-950 px-2 py-0.5 rounded border border-slate-800">
          {{ (row as MilestoneRow).year }}
        </span>
      </template>

      <template #cell-title="{ row }">
        <div>
          <span class="font-bold text-white block">{{ (row as MilestoneRow).title }}</span>
          <span class="text-xs text-slate-400 truncate max-w-sm block">{{ (row as MilestoneRow).text }}</span>
        </div>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="(row as MilestoneRow).is_published ? 'success' : 'soft'">
          {{ (row as MilestoneRow).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editRow(row as MilestoneRow)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteRow((row as MilestoneRow).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" :title="form.id ? 'Editar Hito Histórico' : 'Nuevo Hito Histórico'" @close="showEditorModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Año o Rango de Años" v-model="form.year" placeholder="Ej: 1977 o 1978 - 1982" />
          <BaseInput label="Orden" type="number" v-model="form.order_index" />
        </div>
        <BaseInput label="Título del Hito" v-model="form.title" placeholder="Ej: Fundación del Club" />

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Descripción del Hito</label>
          <textarea
            v-model="form.text"
            rows="4"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 text-sm focus:outline-none focus:border-emerald-500 placeholder-slate-500"
            placeholder="Relato del hito histórico..."
          ></textarea>
        </div>

        <BaseInput label="URL de Imagen (Opcional)" v-model="form.image_url" placeholder="https://..." />

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado en la Línea de Tiempo</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Hito</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
