<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface StatRow {
  id: string
  label: string
  value: string
  note?: string
  is_sponsor: boolean
  logo_url?: string
  order_index: number
  is_published: boolean
  created_at: string
}

const stats = ref<StatRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const form = ref({
  id: '',
  label: '',
  value: '',
  note: '',
  is_sponsor: false,
  logo_url: '',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'label', label: 'Etiqueta / Nombre' },
  { key: 'value', label: 'Valor / Cifra' },
  { key: 'is_sponsor', label: 'Tipo', align: 'center' as const },
  { key: 'order_index', label: 'Orden', align: 'center' as const },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const asStat = (r: unknown): StatRow => r as StatRow

const loadStats = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('site_stats')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    stats.value = (data as StatRow[]) || []
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    label: '',
    value: '',
    note: '',
    is_sponsor: false,
    logo_url: '',
    order_index: stats.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: StatRow) => {
  form.value = {
    id: row.id,
    label: row.label,
    value: row.value,
    note: row.note || '',
    is_sponsor: row.is_sponsor,
    logo_url: row.logo_url || '',
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const saveRow = async () => {
  if (!form.value.label || !form.value.value) {
    errorMessage.value = 'La etiqueta y la cifra/valor son obligatorios.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      label: form.value.label,
      value: form.value.value,
      note: form.value.note || null,
      is_sponsor: form.value.is_sponsor,
      logo_url: form.value.logo_url || null,
      order_index: form.value.order_index,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('site_stats').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('site_stats').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Estadística/Patrocinante guardado.'
    showModal.value = false
    await loadStats()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este registro?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('site_stats').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Registro eliminado.'
    await loadStats()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadStats)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-white">Cifras del Club y Patrocinantes</h1>
          <p class="text-sm text-slate-400">Gestionar métricas clave y logos de aliados estratégicos en la landing.</p>
        </div>
        <BaseButton variant="primary" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Cifra / Sponsor
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

      <BaseTable :columns="columns" :data="stats" :loading="loading" empty-text="No hay cifras ni patrocinantes registrados">
        <template #cell-label="{ row }">
          <div class="flex items-center gap-3">
            <img v-if="asStat(row).logo_url" :src="asStat(row).logo_url" class="w-8 h-8 rounded object-contain bg-slate-800 p-0.5 border border-slate-700" />
            <div>
              <p class="font-semibold text-white">{{ asStat(row).label }}</p>
              <p v-if="asStat(row).note" class="text-xs text-slate-400">{{ asStat(row).note }}</p>
            </div>
          </div>
        </template>

        <template #cell-value="{ row }">
          <span class="font-title font-bold text-emerald-400 text-base">{{ asStat(row).value }}</span>
        </template>

        <template #cell-is_sponsor="{ row }">
          <BaseBadge :variant="asStat(row).is_sponsor ? 'perlita' : 'info'">
            {{ asStat(row).is_sponsor ? 'Patrocinante' : 'Cifra Destacada' }}
          </BaseBadge>
        </template>

        <template #cell-order_index="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ asStat(row).order_index }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="asStat(row).is_published ? 'success' : 'soft'">
            {{ asStat(row).is_published ? 'Visible' : 'Oculto' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(asStat(row))" class="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow(asStat(row).id)" class="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" title="Cifra / Patrocinante" @close="showModal = false">
      <div class="space-y-4">
        <BaseInput label="Etiqueta / Nombre" v-model="form.label" placeholder="Ej: Campeonatos Nacionales o Polar Light" />
        <BaseInput label="Valor / Cifra" v-model="form.value" placeholder="Ej: 9 o Sponsor Oficial" />
        <BaseInput label="Nota / Subtítulo (Opcional)" v-model="form.note" placeholder="Ej: 1977 - 2024" />
        <BaseInput label="URL del Logo (Opcional)" v-model="form.logo_url" placeholder="https://..." />

        <div class="flex items-center gap-6 pt-2">
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
            <input type="checkbox" v-model="form.is_sponsor" class="accent-emerald-500 rounded" />
            <span>Es un Patrocinante</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer">
            <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
            <span>Visible en la Web</span>
          </label>
        </div>

        <BaseInput label="Orden de Aparición" type="number" v-model.number="form.order_index" />
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
