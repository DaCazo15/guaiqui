<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import BulkImportModal from '../common/BulkImportModal.vue'

interface TeamMemberRow {
  id: string
  name: string
  role: string
  group_category: 'directiva' | 'tecnico' | 'logistica'
  photo_url?: string
  order_index: number
  is_published: boolean
  created_at: string
}

const members = ref<TeamMemberRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showModal = ref(false)
const showBulkImportModal = ref(false)
const form = ref({
  id: '',
  name: '',
  role: '',
  group_category: 'tecnico' as 'directiva' | 'tecnico' | 'logistica',
  photo_url: '',
  order_index: 0,
  is_published: true
})

const columns = [
  { key: 'name', label: 'Nombre' },
  { key: 'role', label: 'Cargo / Rol' },
  { key: 'group_category', label: 'Grupo' },
  { key: 'order_index', label: 'Orden', align: 'center' as const },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const categoryLabels: Record<string, string> = {
  directiva: 'Directiva',
  tecnico: 'Cuerpo Técnico',
  logistica: 'Staff / Logística'
}

const asMember = (r: unknown): TeamMemberRow => r as TeamMemberRow

const loadMembers = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('site_team_members')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    members.value = (data as TeamMemberRow[]) || []
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  form.value = {
    id: '',
    name: '',
    role: '',
    group_category: 'tecnico',
    photo_url: '',
    order_index: members.value.length + 1,
    is_published: true
  }
  showModal.value = true
}

const editRow = (row: TeamMemberRow) => {
  form.value = {
    id: row.id,
    name: row.name,
    role: row.role,
    group_category: row.group_category,
    photo_url: row.photo_url || '',
    order_index: row.order_index,
    is_published: row.is_published
  }
  showModal.value = true
}

const saveRow = async () => {
  if (!form.value.name || !form.value.role) {
    errorMessage.value = 'El nombre y el cargo son obligatorios.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      name: form.value.name,
      role: form.value.role,
      group_category: form.value.group_category,
      photo_url: form.value.photo_url || null,
      order_index: form.value.order_index,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase.from('site_team_members').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('site_team_members').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Miembro del equipo guardado correctamente.'
    showModal.value = false
    await loadMembers()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este miembro del equipo?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('site_team_members').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Miembro eliminado.'
    await loadMembers()
  } catch (err: unknown) {
    errorMessage.value = err instanceof Error ? err.message : String(err)
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadMembers()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-title text-white flex items-center gap-2">
          <i class="bi bi-person-lines-fill text-emerald-400"></i>
          Cuerpo Técnico y Directiva
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Personal técnico, directiva y staff mostrados en la página pública del equipo.
        </p>
      </div>
      <div class="flex items-center gap-2 flex-wrap">
        <BaseButton variant="secondary" size="sm" @click="showBulkImportModal = true">
          <i class="bi bi-file-earmark-spreadsheet text-emerald-400 mr-1.5"></i> Carga Masiva (Excel / CSV)
        </BaseButton>
        <BaseButton variant="primary" size="sm" @click="openNew">
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Integrante
        </BaseButton>
      </div>
    </div>

    <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>
    <div v-if="successMessage" class="p-4 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <BaseTable :columns="columns" :data="members" :loading="loading" empty-text="No hay integrantes registrados">
      <template #cell-name="{ row }">
        <div class="flex items-center gap-3">
          <img :src="asMember(row).photo_url || 'https://placehold.co/100x100?text=Guaiqueri'" class="w-9 h-9 rounded-full object-cover bg-slate-800 border border-slate-700" />
          <span class="font-semibold text-white">{{ asMember(row).name }}</span>
        </div>
      </template>

      <template #cell-role="{ row }">
        <span class="text-sm text-slate-300">{{ asMember(row).role }}</span>
      </template>

      <template #cell-group_category="{ row }">
        <BaseBadge variant="info">
          {{ categoryLabels[asMember(row).group_category] || asMember(row).group_category }}
        </BaseBadge>
      </template>

      <template #cell-order_index="{ row }">
        <span class="text-xs text-slate-400 font-mono">{{ asMember(row).order_index }}</span>
      </template>

      <template #cell-is_published="{ row }">
        <BaseBadge :variant="asMember(row).is_published ? 'success' : 'soft'">
          {{ asMember(row).is_published ? 'Visible' : 'Oculto' }}
        </BaseBadge>
      </template>

      <template #cell-actions="{ row }">
        <div class="flex items-center justify-end gap-1.5">
          <button @click="editRow(asMember(row))" class="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button @click="deleteRow(asMember(row).id)" class="p-1.5 text-red-400 hover:text-red-300 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </template>
    </BaseTable>

    <!-- Modal Editor -->
    <BaseModal v-if="showModal" :is-open="showModal" title="Integrante del Equipo" @close="showModal = false">
      <div class="space-y-4">
        <BaseInput label="Nombre Completo" v-model="form.name" placeholder="Ej: Fernando Duró" />
        <BaseInput label="Cargo o Rol" v-model="form.role" placeholder="Ej: Director Técnico" />

        <BaseSelect
          label="Categoría de Grupo"
          v-model="form.group_category"
          :options="[
            { value: 'directiva', label: 'Directiva' },
            { value: 'tecnico', label: 'Cuerpo Técnico' },
            { value: 'logistica', label: 'Staff / Logística' }
          ]"
        />

        <BaseInput label="URL de Foto (Opcional)" v-model="form.photo_url" placeholder="https://..." />
        <BaseInput label="Orden de Aparición" type="number" v-model.number="form.order_index" />

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado / Visible en la Web</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Integrante</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BulkImportModal
      :is-open="showBulkImportModal"
      type="staff"
      @close="showBulkImportModal = false"
      @success="loadMembers"
    />
  </div>
</template>
