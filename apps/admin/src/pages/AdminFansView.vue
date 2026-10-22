<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface FanRow {
  id: string
  display_name: string
  municipality?: string
  calculated_age?: number
  favorite_player_name?: string
  status: 'active' | 'suspended'
  pearl_balance: number
  created_at: string
}

const fans = ref<FanRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// Filters
const filterMunicipality = ref('')
const filterAgeMin = ref<number | undefined>(undefined)
const filterAgeMax = ref<number | undefined>(undefined)
const filterStatus = ref('')
const filterSearch = ref('')

// Modals
const showDetailModal = ref(false)
const showAdjustModal = ref(false)
const showSuspendModal = ref(false)

const selectedFan = ref<FanRow | null>(null)
const fanDetailData = ref<any>(null)

// Adjustment Form
const adjustAmount = ref(100)
const adjustReason = ref('')

// Suspend/Reactivate Form
const actionReason = ref('')
const suspendTargetStatus = ref<'active' | 'suspended'>('suspended')

const columns = [
  { key: 'display_name', label: 'Fanático' },
  { key: 'municipality', label: 'Municipio' },
  { key: 'calculated_age', label: 'Edad', align: 'center' as const },
  { key: 'pearl_balance', label: 'Saldo Perlitas', align: 'right' as const },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadFans = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_list_fans', {
      p_municipality: filterMunicipality.value || null,
      p_age_min: filterAgeMin.value || null,
      p_age_max: filterAgeMax.value || null,
      p_status: filterStatus.value || null,
      p_search: filterSearch.value || null,
      p_limit: 50
    })

    if (error) throw error
    fans.value = data?.fans || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openFanDetail = async (fan: FanRow) => {
  selectedFan.value = fan
  showDetailModal.value = true
  try {
    const { data, error } = await supabase.rpc('admin_get_fan', { p_fan_id: fan.id })
    if (error) throw error
    fanDetailData.value = data
  } catch (err: any) {
    errorMessage.value = err.message
  }
}

const openAdjustModal = (fan: FanRow) => {
  selectedFan.value = fan
  adjustAmount.value = 100
  adjustReason.value = ''
  showAdjustModal.value = true
}

const executeAdjustPearls = async () => {
  if (!selectedFan.value) return
  if (!adjustReason.value.trim()) {
    errorMessage.value = 'Se requiere un motivo obligatorio para el ajuste de perlitas.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_adjust_pearls', {
      p_fan_id: selectedFan.value.id,
      p_amount: Number(adjustAmount.value),
      p_reason: adjustReason.value.trim()
    })

    if (error) throw error
    successMessage.value = 'Saldo de perlitas ajustado correctamente.'
    showAdjustModal.value = false
    await loadFans()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const openSuspendModal = (fan: FanRow, targetStatus: 'active' | 'suspended') => {
  selectedFan.value = fan
  suspendTargetStatus.value = targetStatus
  actionReason.value = ''
  showSuspendModal.value = true
}

const executeStatusChange = async () => {
  if (!selectedFan.value) return
  if (!actionReason.value.trim()) {
    errorMessage.value = 'Se requiere una justificación obligatoria para esta acción.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const rpcName = suspendTargetStatus.value === 'suspended' ? 'admin_suspend_fan' : 'admin_reactivate_fan'
    const { error } = await supabase.rpc(rpcName, {
      p_fan_id: selectedFan.value.id,
      p_reason: actionReason.value.trim()
    })

    if (error) throw error
    successMessage.value = `Fanático ${suspendTargetStatus.value === 'suspended' ? 'suspendido' : 'reactivado'} correctamente.`
    showSuspendModal.value = false
    await loadFans()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadFans)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl sm:text-3xl font-bold font-title text-slate-900">Directorio de Fanáticos</h1>
        <p class="text-sm text-slate-600">Búsqueda avanzada, ficha de fanático, ajustes manuales de perlitas y suspensión.</p>
      </div>

      <BaseCard class="bg-white border-slate-200 p-4 space-y-3 shadow-xs">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          <BaseInput label="Buscar Nombre" v-model="filterSearch" placeholder="Nombre de fan..." />
          <BaseSelect
            label="Municipio"
            v-model="filterMunicipality"
            :options="[
              { value: '', label: 'Todos los municipios' },
              { value: 'Mariño', label: 'Mariño (Porlamar)' },
              { value: 'Maneiro', label: 'Maneiro (Pampatar)' },
              { value: 'Arismendi', label: 'Arismendi (La Asunción)' },
              { value: 'Marcano', label: 'Marcano (Juangriego)' }
            ]"
          />
          <BaseInput label="Edad Mínima" type="number" v-model="filterAgeMin" />
          <BaseInput label="Edad Máxima" type="number" v-model="filterAgeMax" />
          <BaseSelect
            label="Estado"
            v-model="filterStatus"
            :options="[
              { value: '', label: 'Todos los estados' },
              { value: 'active', label: 'Activos' },
              { value: 'suspended', label: 'Suspendidos' }
            ]"
          />
        </div>
        <div class="flex items-center justify-end">
          <BaseButton size="sm" variant="primary" @click="loadFans">
            <i class="bi bi-search mr-1.5"></i> Filtrar Fanáticos
          </BaseButton>
        </div>
      </BaseCard>

      <div v-if="errorMessage" class="p-4 bg-red-50 border border-red-200 text-red-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-slate-600"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(fans as any[])" :loading="loading" empty-text="No se encontraron fanáticos con los filtros seleccionados">
        <template #cell-display_name="{ row }">
          <div class="font-semibold text-slate-900">{{ (row as FanRow).display_name }}</div>
        </template>

        <template #cell-municipality="{ row }">
          <span class="text-xs text-slate-700">{{ (row as FanRow).municipality || 'N/I' }}</span>
        </template>

        <template #cell-calculated_age="{ row }">
          <span class="text-xs font-mono text-slate-600">{{ (row as FanRow).calculated_age ? (row as FanRow).calculated_age + ' años' : 'N/I' }}</span>
        </template>

        <template #cell-pearl_balance="{ row }">
          <span class="font-mono text-emerald-600 font-bold text-sm">{{ (row as FanRow).pearl_balance }}</span>
        </template>

        <template #cell-status="{ row }">
          <BaseBadge :variant="(row as FanRow).status === 'active' ? 'success' : 'danger'">
            {{ (row as FanRow).status === 'active' ? 'Activo' : 'Suspendido' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="openFanDetail(row as FanRow)" class="p-1.5 text-sky-600 hover:bg-sky-50 rounded-lg transition-colors" title="Ver Ficha">
              <i class="bi bi-file-person"></i>
            </button>
            <button @click="openAdjustModal(row as FanRow)" class="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors" title="Ajustar Perlitas">
              <i class="bi bi-coin"></i>
            </button>
            <button v-if="(row as FanRow).status === 'active'" @click="openSuspendModal(row as FanRow, 'suspended')" class="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors" title="Suspender">
              <i class="bi bi-person-x"></i>
            </button>
            <button v-else @click="openSuspendModal(row as FanRow, 'active')" class="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors" title="Reactivar">
              <i class="bi bi-person-check"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Detail Drawer/Modal -->
    <BaseModal v-if="showDetailModal" :is-open="showDetailModal" title="Ficha del Fanático (Auditada)" @close="showDetailModal = false">
      <div v-if="fanDetailData" class="space-y-4">
        <div class="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
          <div class="text-lg font-bold text-slate-900">{{ fanDetailData.profile?.display_name }}</div>
          <div class="text-xs text-slate-600">Municipio: {{ fanDetailData.profile?.municipality || 'N/I' }} | Talla: {{ fanDetailData.profile?.shirt_size || 'N/I' }}</div>
          <div class="text-sm font-mono text-emerald-700 font-bold">Saldo: {{ fanDetailData.balance }} perlitas</div>
        </div>

        <div>
          <h4 class="text-xs font-bold uppercase text-slate-500 mb-2">Trivias Recientes</h4>
          <div class="space-y-1 text-xs">
            <div v-for="t in fanDetailData.recent_trivias" :key="t.id" class="p-2 bg-slate-100 rounded border border-slate-200 flex justify-between">
              <span class="text-slate-800">{{ t.title }}</span>
              <span class="text-emerald-700 font-mono font-bold">+{{ t.pearls_awarded }} perlitas</span>
            </div>
            <div v-if="!fanDetailData.recent_trivias?.length" class="text-slate-500 text-xs">Sin trivias registradas</div>
          </div>
        </div>
      </div>
    </BaseModal>

    <!-- Adjust Pearls Modal -->
    <BaseModal v-if="showAdjustModal" :is-open="showAdjustModal" title="Ajuste Manual de Perlitas" @close="showAdjustModal = false">
      <div class="space-y-4">
        <div class="text-sm text-slate-700">Ajustando saldo de <strong class="text-slate-900">{{ selectedFan?.display_name }}</strong></div>
        <BaseInput label="Monto a Ajustar (Positivo para sumar, negativo para restar)" type="number" v-model="adjustAmount" />
        <BaseInput label="Motivo de Justificación (Obligatorio)" v-model="adjustReason" placeholder="Ej: Corrección por soporte técnico" />
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showAdjustModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="executeAdjustPearls">Aplicar Ajuste</BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Suspend/Reactivate Modal -->
    <BaseModal v-if="showSuspendModal" :is-open="showSuspendModal" :title="suspendTargetStatus === 'suspended' ? 'Suspender Fanático' : 'Reactivar Fanático'" @close="showSuspendModal = false">
      <div class="space-y-4">
        <p class="text-sm text-slate-700">
          ¿Desea {{ suspendTargetStatus === 'suspended' ? 'suspender el acceso a' : 'reactivar la cuenta de' }} <strong class="text-slate-900">{{ selectedFan?.display_name }}</strong>?
        </p>
        <BaseInput label="Motivo / Justificación Obligatoria" v-model="actionReason" placeholder="Indique la causa de la acción" />
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showSuspendModal = false">Cancelar</BaseButton>
          <BaseButton :variant="suspendTargetStatus === 'suspended' ? 'danger' : 'primary'" :loading="actionLoading" @click="executeStatusChange">
            Confirmar {{ suspendTargetStatus === 'suspended' ? 'Suspensión' : 'Reactivación' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
