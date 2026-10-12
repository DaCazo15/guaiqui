<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface SegmentRow {
  id: string
  name: string
  filters: Record<string, any>
  created_at: string
}

const segments = ref<SegmentRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const showMembersModal = ref(false)

const selectedSegment = ref<SegmentRow | null>(null)
const memberCount = ref<number | null>(null)
const segmentMembersList = ref<any[]>([])

const segmentForm = ref({
  id: '',
  name: '',
  municipality: '',
  gender: '',
  shirt_size: '',
  status: '',
  min_age: undefined as number | undefined,
  max_age: undefined as number | undefined
})

const columns = [
  { key: 'name', label: 'Nombre del Segmento' },
  { key: 'filters', label: 'Criterios de Filtro' },
  { key: 'created_at', label: 'Creado El' },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadSegments = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('segments')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error
    segments.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewSegment = () => {
  selectedSegment.value = null
  segmentForm.value = {
    id: '',
    name: '',
    municipality: '',
    gender: '',
    shirt_size: '',
    status: '',
    min_age: undefined,
    max_age: undefined
  }
  memberCount.value = null
  showEditorModal.value = true
}

const previewSegmentCount = async () => {
  actionLoading.value = true
  try {
    const filters: Record<string, any> = {}
    if (segmentForm.value.municipality) filters.municipality = segmentForm.value.municipality
    if (segmentForm.value.gender) filters.gender = segmentForm.value.gender
    if (segmentForm.value.shirt_size) filters.shirt_size = segmentForm.value.shirt_size
    if (segmentForm.value.status) filters.status = segmentForm.value.status
    if (segmentForm.value.min_age) filters.min_age = Number(segmentForm.value.min_age)
    if (segmentForm.value.max_age) filters.max_age = Number(segmentForm.value.max_age)

    let tempId = segmentForm.value.id
    if (!tempId) {
      const { data: created, error: createErr } = await supabase.rpc('admin_upsert_segment', {
        p_segment: { name: segmentForm.value.name || 'Borrador Temp', filters }
      })
      if (createErr) throw createErr
      tempId = created.id
      segmentForm.value.id = tempId
    } else {
      await supabase.rpc('admin_upsert_segment', {
        p_segment: { id: tempId, name: segmentForm.value.name, filters }
      })
    }

    const { data: count, error: countErr } = await supabase.rpc('segment_count', { p_segment_id: tempId })
    if (countErr) throw countErr

    memberCount.value = count
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const saveSegment = async () => {
  if (!segmentForm.value.name) {
    errorMessage.value = 'El nombre del segmento es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const filters: Record<string, any> = {}
    if (segmentForm.value.municipality) filters.municipality = segmentForm.value.municipality
    if (segmentForm.value.gender) filters.gender = segmentForm.value.gender
    if (segmentForm.value.shirt_size) filters.shirt_size = segmentForm.value.shirt_size
    if (segmentForm.value.status) filters.status = segmentForm.value.status
    if (segmentForm.value.min_age) filters.min_age = Number(segmentForm.value.min_age)
    if (segmentForm.value.max_age) filters.max_age = Number(segmentForm.value.max_age)

    const payload = {
      id: segmentForm.value.id || undefined,
      name: segmentForm.value.name,
      filters
    }

    const { error } = await supabase.rpc('admin_upsert_segment', { p_segment: payload })
    if (error) throw error

    successMessage.value = 'Segmento guardado correctamente.'
    showEditorModal.value = false
    await loadSegments()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const viewMembers = async (seg: SegmentRow) => {
  selectedSegment.value = seg
  showMembersModal.value = true
  actionLoading.value = true
  try {
    const { data, error } = await supabase.rpc('segment_members', { p_segment_id: seg.id })
    if (error) throw error
    segmentMembersList.value = data?.members || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const exportCSV = async (seg: SegmentRow) => {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token

    const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/export-segment-csv?segment_id=${seg.id}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    if (!response.ok) throw new Error('Error al generar la exportación en CSV.')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `segmento_${seg.name.replace(/\s+/g, '_')}.csv`
    a.click()

    successMessage.value = 'Exportación CSV descargada (auditada).'
  } catch (err: any) {
    errorMessage.value = err.message
  }
}

onMounted(loadSegments)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white">Segmentación de Fanáticos</h1>
          <p class="text-sm text-slate-400">Crear audiencias personalizadas mediante criterios seguros y exportar informes auditados.</p>
        </div>
        <BaseButton variant="primary" @click="openNewSegment">
          <i class="bi bi-pie-chart-fill mr-1.5"></i> Crear Segmento
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

      <BaseTable :columns="columns" :data="segments" :loading="loading" empty-text="No hay segmentos configurados">
        <template #cell-name="{ row }">
          <span class="font-semibold text-slate-100">{{ (row as any).name }}</span>
        </template>

        <template #cell-filters="{ row }">
          <span class="text-xs font-mono text-slate-400 truncate max-w-md block">
            {{ JSON.stringify((row as any).filters) }}
          </span>
        </template>

        <template #cell-created_at="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ (row as any).created_at ? formatCaracas((row as any).created_at) : '' }}</span>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="viewMembers(row as any)" class="p-1.5 text-sky-400 hover:bg-sky-950 rounded-lg" title="Ver Miembros">
              <i class="bi bi-people"></i>
            </button>
            <button @click="exportCSV(row as any)" class="p-1.5 text-emerald-400 hover:bg-emerald-950 rounded-lg" title="Exportar CSV (sin email)">
              <i class="bi bi-download"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Segment Editor -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Constructor de Segmento" @close="showEditorModal = false">
      <div class="space-y-4">
        <BaseInput label="Nombre del Segmento" v-model="segmentForm.name" placeholder="Ej: Fanáticos Adultos de Pampatar" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseSelect
            label="Municipio"
            v-model="segmentForm.municipality"
            :options="[
              { value: '', label: 'Cualquier municipio' },
              { value: 'Mariño', label: 'Mariño' },
              { value: 'Maneiro', label: 'Maneiro' },
              { value: 'Arismendi', label: 'Arismendi' }
            ]"
          />
          <BaseSelect
            label="Estado del Usuario"
            v-model="segmentForm.status"
            :options="[
              { value: '', label: 'Cualquier estado' },
              { value: 'active', label: 'Activo' },
              { value: 'suspended', label: 'Suspendido' }
            ]"
          />
          <BaseInput label="Edad Mínima" type="number" v-model="segmentForm.min_age" />
          <BaseInput label="Edad Máxima" type="number" v-model="segmentForm.max_age" />
        </div>

        <div class="p-4 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-between">
          <div class="text-xs text-slate-400">
            <span>Conteo de Audiencia: </span>
            <strong v-if="memberCount !== null" class="text-emerald-400 font-mono text-base font-bold ml-1">{{ memberCount }} fanáticos</strong>
            <span v-else class="italic ml-1">Presione calcular</span>
          </div>
          <BaseButton size="sm" variant="secondary" :loading="actionLoading" @click="previewSegmentCount">
            Calcular Conteo
          </BaseButton>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveSegment">Guardar Segmento</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Modal View Members -->
    <BaseModal v-if="showMembersModal" :is-open="showMembersModal" title="Miembros del Segmento" @close="showMembersModal = false">
      <div class="space-y-3">
        <div class="text-xs text-slate-400">Mostrando miembros que coinciden con el segmento <strong>{{ selectedSegment?.name }}</strong>:</div>
        <div class="space-y-1.5 max-h-80 overflow-y-auto">
          <div v-for="m in segmentMembersList" :key="m.id" class="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-xs flex justify-between">
            <span class="font-semibold text-slate-200">{{ m.display_name }}</span>
            <span class="text-slate-400">{{ m.municipality || 'N/I' }}</span>
          </div>
          <div v-if="segmentMembersList.length === 0" class="text-xs text-slate-500 text-center py-4">No hay miembros en este segmento</div>
        </div>
      </div>
    </BaseModal>
  </AdminLayout>
</template>
