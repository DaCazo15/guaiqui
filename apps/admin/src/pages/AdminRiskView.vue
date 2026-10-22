<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface RiskFlagRow {
  flag_id: string
  fan_id: string
  display_name: string
  reason: string
  severity: 'low' | 'medium' | 'high'
  resolved: boolean
  created_at: string
  held_pearls: number
}

const flags = ref<RiskFlagRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showResolved = ref(false)
const selectedFlag = ref<RiskFlagRow | null>(null)
const showActionModal = ref(false)
const actionType = ref<'release' | 'revoke' | 'resolve'>('release')
const actionNote = ref('')
const selectedLedgerId = ref('')

const columns = [
  { key: 'display_name', label: 'Fanático' },
  { key: 'reason', label: 'Motivo de Alerta' },
  { key: 'severity', label: 'Severidad', align: 'center' as const },
  { key: 'held_pearls', label: 'Perlitas Retenidas', align: 'center' as const },
  { key: 'created_at', label: 'Fecha', align: 'right' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadQueue = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('admin_risk_queue', {
      p_resolved: showResolved.value
    })

    if (error) throw error
    flags.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openAction = (flag: RiskFlagRow, type: 'release' | 'revoke' | 'resolve') => {
  selectedFlag.value = flag
  actionType.value = type
  actionNote.value = ''
  selectedLedgerId.value = ''
  showActionModal.value = true
}

const executeAction = async () => {
  if (!actionNote.value.trim()) {
    errorMessage.value = 'La nota de justificación es obligatoria.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    if (actionType.value === 'release') {
      // Find held ledger entry for fan
      const { data: entries } = await supabase
        .from('ledger_entries')
        .select('id')
        .eq('fan_id', selectedFlag.value!.fan_id)
        .eq('status', 'held')
        .limit(1)

      const targetId = entries?.[0]?.id || selectedLedgerId.value
      if (!targetId) throw new Error('No se encontró ningún registro de perlitas retenidas para este usuario.')

      const { error } = await supabase.rpc('admin_release_held_pearls', {
        p_ledger_id: targetId,
        p_note: actionNote.value
      })
      if (error) throw error
      successMessage.value = 'Perlitas liberadas correctamente y sumadas al saldo del fanático.'
    } else if (actionType.value === 'revoke') {
      const { data: entries } = await supabase
        .from('ledger_entries')
        .select('id')
        .eq('fan_id', selectedFlag.value!.fan_id)
        .eq('status', 'held')
        .limit(1)

      const targetId = entries?.[0]?.id || selectedLedgerId.value
      if (!targetId) throw new Error('No se encontró ningún registro de perlitas retenidas para este usuario.')

      const { error } = await supabase.rpc('admin_revoke_held_pearls', {
        p_ledger_id: targetId,
        p_note: actionNote.value
      })
      if (error) throw error
      successMessage.value = 'Perlitas revocadas.'
    } else {
      const { error } = await supabase.rpc('admin_resolve_risk_flag', {
        p_flag_id: selectedFlag.value!.flag_id,
        p_note: actionNote.value
      })
      if (error) throw error
      successMessage.value = 'Alerta de riesgo marcada como resuelta.'
    }

    showActionModal.value = false
    await loadQueue()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadQueue)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-shield-exclamation text-amber-400"></i>
            Cola de Revisión Antifraude y Control de Riesgo
          </h1>
          <p class="text-sm text-slate-400">Revisión manual de perlitas retenidas y alertas de comportamiento inusual.</p>
        </div>

        <div class="flex items-center gap-2 bg-slate-900 border border-slate-800 p-1.5 rounded-xl text-xs">
          <button
            @click="showResolved = false; loadQueue()"
            :class="['px-3 py-1.5 font-semibold rounded-lg transition-colors', !showResolved ? 'bg-amber-950/80 text-amber-300 border border-amber-800' : 'text-slate-400 hover:text-white']"
          >
            Pendientes de Revisión
          </button>
          <button
            @click="showResolved = true; loadQueue()"
            :class="['px-3 py-1.5 font-semibold rounded-lg transition-colors', showResolved ? 'bg-emerald-950/80 text-emerald-300 border border-emerald-800' : 'text-slate-400 hover:text-white']"
          >
            Resueltas
          </button>
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

      <BaseTable :columns="columns" :data="flags" :loading="loading" empty-text="No hay alertas de riesgo registradas">
        <template #cell-display_name="{ row }">
          <span class="font-semibold text-white">{{ (row as any).display_name }}</span>
        </template>

        <template #cell-reason="{ row }">
          <span class="text-xs text-slate-300">{{ (row as any).reason }}</span>
        </template>

        <template #cell-severity="{ row }">
          <BaseBadge :variant="(row as any).severity === 'high' ? 'danger' : 'warning'">
            {{ (row as any).severity.toUpperCase() }}
          </BaseBadge>
        </template>

        <template #cell-held_pearls="{ row }">
          <span class="font-mono tabular-nums text-amber-400 font-bold">
            {{ (row as any).held_pearls > 0 ? (row as any).held_pearls + ' retenidas' : '0' }}
          </span>
        </template>

        <template #cell-created_at="{ row }">
          <span class="text-xs text-slate-400">{{ (row as any).created_at ? formatCaracas((row as any).created_at) : '' }}</span>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-2">
            <BaseButton
              v-if="(row as any).held_pearls > 0 && !(row as any).resolved"
              variant="primary"
              size="sm"
              @click="openAction(row as any, 'release')"
            >
              Liberar
            </BaseButton>
            <BaseButton
              v-if="(row as any).held_pearls > 0 && !(row as any).resolved"
              variant="danger"
              size="sm"
              @click="openAction(row as any, 'revoke')"
            >
              Revocar
            </BaseButton>
            <BaseButton
              v-if="!(row as any).resolved"
              variant="secondary"
              size="sm"
              @click="openAction(row as any, 'resolve')"
            >
              Resolver
            </BaseButton>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Action Justification -->
    <BaseModal
      v-if="showActionModal"
      :is-open="showActionModal"
      :title="actionType === 'release' ? 'Liberar Perlitas Retenidas' : actionType === 'revoke' ? 'Revocar Perlitas' : 'Resolver Alerta'"
      @close="showActionModal = false"
    >
      <div class="space-y-4">
        <p class="text-sm text-slate-300">
          Fanático: <strong class="text-white">{{ selectedFlag?.display_name }}</strong>
        </p>
        <p class="text-xs text-slate-300 bg-slate-950/60 p-3 rounded-xl border border-slate-800">
          Evidencia: {{ selectedFlag?.reason }}
        </p>

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Nota de Justificación (Obligatoria)</label>
          <textarea
            v-model="actionNote"
            rows="4"
            class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl px-3 py-2 text-xs focus:outline-none focus:border-emerald-500 placeholder-slate-500"
            placeholder="Indica el motivo de la decisión (ej: Verificado en taquilla, respuestas validadas)..."
          ></textarea>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showActionModal = false">Cancelar</BaseButton>
          <BaseButton
            :variant="actionType === 'revoke' ? 'danger' : 'primary'"
            :loading="actionLoading"
            @click="executeAction"
          >
            Confirmar Acción
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
