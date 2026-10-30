<script setup lang="ts">
import { ref, watch } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { TeamRow } from './PlatformTeamsTable.vue'

interface BillingEvent {
  id: string
  event_type: string
  amount: number | null
  currency: string
  period_months: number
  period_start: string
  period_end: string
  note: string | null
  registered_by: string
  created_at: string
}

const props = defineProps<{
  isOpen: boolean
  team: TeamRow | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const events = ref<BillingEvent[]>([])
const loading = ref(false)
const errorMessage = ref<string | null>(null)

const formatDate = (isoString?: string | null) => {
  if (!isoString) return '-'
  return new Date(isoString).toLocaleDateString('es-VE', { year: 'numeric', month: 'short', day: 'numeric' })
}

const formatDateTime = (isoString?: string | null) => {
  if (!isoString) return '-'
  return new Date(isoString).toLocaleString('es-VE', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

const fetchHistory = async () => {
  if (!props.team) return
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('team_billing_events')
      .select('*')
      .eq('team_id', props.team.id)
      .order('created_at', { ascending: false })

    if (error) throw error
    events.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message || 'Error cargando historial de pagos'
  } finally {
    loading.value = false
  }
}

watch(() => props.isOpen, (open) => {
  if (open && props.team) {
    fetchHistory()
  } else {
    events.value = []
  }
})
</script>

<template>
  <BaseModal :is-open="isOpen" :title="`Historial de Pagos: ${team?.name || ''}`" @close="emit('close')">
    <div class="space-y-4 text-xs">
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-lg">
        {{ errorMessage }}
      </div>

      <div v-if="loading" class="p-8 text-center text-slate-400">
        <i class="bi bi-arrow-repeat animate-spin text-xl text-purple-400 mb-2 inline-block"></i>
        <p>Consultando libro de pagos...</p>
      </div>

      <div v-else-if="events.length === 0" class="p-8 text-center text-slate-400 bg-slate-900 rounded-lg border border-slate-800">
        <i class="bi bi-receipt text-2xl text-slate-600 mb-1 inline-block"></i>
        <p class="font-medium text-slate-300">Sin pagos registrados</p>
        <p class="text-[11px] text-slate-500 mt-0.5">Aún no se han asentado pagos o extensiones para este club.</p>
      </div>

      <div v-else class="max-h-80 overflow-y-auto space-y-2.5 pr-1">
        <div
          v-for="ev in events"
          :key="ev.id"
          class="p-3 rounded-lg bg-slate-900 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-2"
        >
          <div>
            <div class="flex items-center gap-2">
              <span class="px-2 py-0.5 text-[10px] font-semibold uppercase font-mono rounded-full bg-purple-950/80 text-purple-300 border border-purple-800">
                {{ ev.event_type }}
              </span>
              <span class="text-slate-400 font-mono text-[11px]">
                {{ ev.period_months }} mes(es)
              </span>
            </div>
            <div class="text-[11px] text-slate-300 mt-1">
              Período: <span class="font-mono text-slate-200">{{ formatDate(ev.period_start) }}</span> → <span class="font-mono text-emerald-400 font-semibold">{{ formatDate(ev.period_end) }}</span>
            </div>
            <div v-if="ev.note" class="text-[11px] text-slate-400 italic mt-0.5">
              "{{ ev.note }}"
            </div>
          </div>

          <div class="text-left sm:text-right shrink-0">
            <div v-if="ev.amount !== null" class="font-mono text-sm font-bold text-white">
              {{ ev.amount.toLocaleString('es-VE', { minimumFractionDigits: 2 }) }} {{ ev.currency }}
            </div>
            <div v-else class="text-[11px] text-slate-500 italic">
              Sin monto (Cortesía / Ajuste)
            </div>
            <div class="text-[10px] text-slate-500 font-mono mt-0.5">
              {{ formatDateTime(ev.created_at) }}
            </div>
          </div>
        </div>
      </div>

      <div class="flex justify-end pt-3 border-t border-slate-800">
        <BaseButton variant="secondary" size="sm" @click="emit('close')">
          Cerrar
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>
