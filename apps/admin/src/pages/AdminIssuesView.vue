<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseCard, BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface IssueRow {
  id: string
  fan_id: string
  product_id: string
  cost_pearls: number
  status: string
  code_hash: string
  created_at: string
  fan_name?: string
  product_name?: string
}

const issues = ref<IssueRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showResolveModal = ref(false)
const selectedIssue = ref<IssueRow | null>(null)
const actionType = ref<'reissue' | 'refund' | 'close'>('refund')
const resolveNote = ref('')

const columns = [
  { key: 'fan_name', label: 'Fanático' },
  { key: 'product_name', label: 'Producto' },
  { key: 'cost_pearls', label: 'Costo' },
  { key: 'status', label: 'Estado', align: 'center' as const },
  { key: 'created_at', label: 'Fecha de Canje' },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const loadIssues = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('redemptions')
      .select('*, fan:profiles(display_name), product:products(name)')
      .eq('status', 'issue')
      .order('created_at', { ascending: false })

    if (error) throw error

    issues.value = (data || []).map((r: any) => ({
      ...r,
      fan_name: r.fan?.display_name || 'Fanático',
      product_name: r.product?.name || 'Producto'
    }))
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openResolveModal = (issue: IssueRow) => {
  selectedIssue.value = issue
  actionType.value = 'refund'
  resolveNote.value = ''
  showResolveModal.value = true
}

const executeResolve = async () => {
  if (!selectedIssue.value) return
  if (!resolveNote.value.trim()) {
    errorMessage.value = 'Se requiere una nota explicativa para resolver la incidencia.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.rpc('admin_resolve_redemption_issue', {
      p_redemption_id: selectedIssue.value.id,
      p_action: actionType.value,
      p_note: resolveNote.value.trim()
    })

    if (error) throw error
    successMessage.value = 'Incidencia resuelta correctamente.'
    showResolveModal.value = false
    await loadIssues()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadIssues)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold font-title text-white">Resolución de Incidencias de Canje</h1>
        <p class="text-sm text-slate-400">Atender y resolver solicitudes problemáticas mediante reemisión, reembolso o cierre.</p>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(issues as any[])" :loading="loading" empty-text="No hay incidencias abiertas actualmente">
        <template #cell-fan_name="{ row }">
          <span class="font-semibold text-slate-100">{{ (row as IssueRow).fan_name }}</span>
        </template>

        <template #cell-product_name="{ row }">
          <span class="text-slate-300">{{ (row as IssueRow).product_name }}</span>
        </template>

        <template #cell-cost_pearls="{ row }">
          <span class="font-mono text-emerald-400 font-bold text-xs">{{ (row as IssueRow).cost_pearls }} perlitas</span>
        </template>

        <template #cell-status="{ row }">
          <BaseBadge variant="warning">Incidencia Abierta</BaseBadge>
        </template>

        <template #cell-created_at="{ row }">
          <span class="text-xs text-slate-400 font-mono">{{ (row as IssueRow).created_at ? new Date((row as IssueRow).created_at).toLocaleString() : '' }}</span>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end">
            <BaseButton size="sm" variant="primary" @click="openResolveModal(row as IssueRow)">
              Resolver Incidencia
            </BaseButton>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Resolve Modal -->
    <BaseModal v-if="showResolveModal" :is-open="showResolveModal" title="Resolución de Incidencia" @close="showResolveModal = false">
      <div class="space-y-4">
        <div class="p-3 rounded-lg bg-slate-900 border border-slate-800 text-xs text-slate-300 space-y-1">
          <div><strong>Fanático:</strong> {{ selectedIssue?.fan_name }}</div>
          <div><strong>Producto:</strong> {{ selectedIssue?.product_name }}</div>
          <div><strong>Monto:</strong> {{ selectedIssue?.cost_pearls }} perlitas</div>
        </div>

        <BaseSelect
          label="Acción a Tomar"
          v-model="actionType"
          :options="[
            { value: 'refund', label: 'Reembolsar Perlitas (Devolución al libro)' },
            { value: 'reissue', label: 'Reemitir Código de Canje (Extender 7 días)' },
            { value: 'close', label: 'Cerrar sin Reembolso (Rechazar)' }
          ]"
        />

        <BaseInput label="Nota / Explicación del Administrador (Obligatorio)" v-model="resolveNote" placeholder="Describa el motivo de la resolución" />

        <div v-if="actionType === 'refund'" class="p-3 rounded-lg bg-emerald-950/60 border border-emerald-800 text-xs text-emerald-300">
          El reembolso acreditará <strong>+{{ selectedIssue?.cost_pearls }} perlitas</strong> en el saldo del fanático insertando una entrada atómica en el libro de transacciones.
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showResolveModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="executeResolve">Confirmar Resolución</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
