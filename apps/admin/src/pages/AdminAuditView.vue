<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseCard, BaseButton, BaseBadge, BaseInput, BaseTable } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { supabase } from '../lib/supabase'

interface AuditLogRow {
  id: string
  actor_id?: string
  actor_name?: string
  action: string
  entity: string
  entity_id?: string
  before?: any
  after?: any
  created_at: string
}

const auditLogs = ref<AuditLogRow[]>([])
const loading = ref(true)
const errorMessage = ref<string | null>(null)

// Filters
const filterAction = ref('')
const filterEntity = ref('')

const columns = [
  { key: 'created_at', label: 'Fecha / Hora' },
  { key: 'actor_name', label: 'Actor' },
  { key: 'action', label: 'Acción' },
  { key: 'entity', label: 'Entidad' },
  { key: 'details', label: 'Detalles (Antes / Después)' }
]

const loadAuditLogs = async () => {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase.rpc('audit_search', {
      p_action: filterAction.value || null,
      p_entity: filterEntity.value || null,
      p_limit: 50
    })

    if (error) throw error
    auditLogs.value = data?.logs || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

onMounted(loadAuditLogs)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl sm:text-3xl font-bold font-title text-white">Registro de Auditoría</h1>
        <p class="text-sm text-slate-400">Inspección de logs de auditoría inmutables (solo lectura).</p>
      </div>

      <!-- Filters -->
      <BaseCard class="bg-slate-900 border-slate-800 p-4 space-y-3 shadow-xl">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BaseInput label="Acción" v-model="filterAction" placeholder="Ej: publish_trivia, suspend_fan..." />
          <BaseInput label="Entidad" v-model="filterEntity" placeholder="Ej: trivias, profiles, wallets..." />
          <div class="flex items-end">
            <BaseButton size="sm" variant="primary" class="w-full" @click="loadAuditLogs">
              <i class="bi bi-search mr-1.5"></i> Filtrar Auditoría
            </BaseButton>
          </div>
        </div>
      </BaseCard>

      <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="(auditLogs as any[])" :loading="loading" empty-text="No hay registros de auditoría que coincidan">
        <template #cell-created_at="{ row }">
          <span class="text-xs font-mono text-slate-400">{{ (row as AuditLogRow).created_at ? formatCaracas((row as AuditLogRow).created_at) : '' }}</span>
        </template>

        <template #cell-actor_name="{ row }">
          <span class="font-semibold text-white text-xs">{{ (row as AuditLogRow).actor_name || (row as AuditLogRow).actor_id || 'Sistema' }}</span>
        </template>

        <template #cell-action="{ row }">
          <span class="text-xs font-mono font-semibold text-emerald-300 px-2 py-0.5 rounded bg-emerald-950/80 border border-emerald-800">
            {{ (row as AuditLogRow).action }}
          </span>
        </template>

        <template #cell-entity="{ row }">
          <span class="text-xs text-slate-300 font-mono">{{ (row as AuditLogRow).entity }} ({{ (row as AuditLogRow).entity_id || '-' }})</span>
        </template>

        <template #cell-details="{ row }">
          <div class="text-[11px] font-mono text-slate-400 max-w-xs truncate">
            <span v-if="(row as AuditLogRow).before">Ant: {{ JSON.stringify((row as AuditLogRow).before) }}</span>
            <span v-if="(row as AuditLogRow).after" class="ml-1">Desp: {{ JSON.stringify((row as AuditLogRow).after) }}</span>
          </div>
        </template>
      </BaseTable>
    </div>
  </AdminLayout>
</template>
