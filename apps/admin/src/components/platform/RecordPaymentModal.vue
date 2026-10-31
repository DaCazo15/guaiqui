<script setup lang="ts">
import { ref, watch } from 'vue'
import { BaseButton, BaseModal } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { TeamRow } from './PlatformTeamsTable.vue'

const props = defineProps<{
  isOpen: boolean
  team: TeamRow | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'paymentRecorded'): void
}>()

const eventType = ref('subscription_payment')
const months = ref(1)
const amount = ref<number | null>(null)
const note = ref('')

const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)

watch(() => props.team, () => {
  eventType.value = 'subscription_payment'
  months.value = 1
  amount.value = null
  note.value = ''
  errorMessage.value = null
})

const formatDate = (isoString?: string | null) => {
  if (!isoString) return 'Sin fecha registrada'
  return new Date(isoString).toLocaleDateString('es-VE', { year: 'numeric', month: 'long', day: 'numeric' })
}

const handleSubmit = async () => {
  if (!props.team) return
  if (months.value < 1) {
    errorMessage.value = 'El período de extensión debe ser de al menos 1 mes.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  try {
    const { data, error } = await supabase.rpc('admin_record_team_payment', {
      p_team_id: props.team.id,
      p_event_type: eventType.value,
      p_amount: amount.value !== null && !isNaN(amount.value) ? amount.value : null,
      p_months: months.value,
      p_note: note.value.trim() || null
    })

    if (error) throw error

    emit('paymentRecorded')
    emit('close')
  } catch (err: any) {
    errorMessage.value = err.message || 'Error registrando el pago.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <BaseModal :is-open="isOpen" :title="`Registrar Pago / Extensión: ${team?.name || ''}`" @close="emit('close')">
    <form @submit.prevent="handleSubmit" class="space-y-4 text-xs">
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-lg">
        {{ errorMessage }}
      </div>

      <!-- Current status info banner -->
      <div class="p-3 bg-slate-900 border border-slate-800 rounded-lg flex items-center justify-between">
        <div>
          <div class="text-[11px] text-slate-400">Vencimiento Actual:</div>
          <div class="font-bold text-slate-200 mt-0.5 font-mono">{{ formatDate(team?.paid_until) }}</div>
        </div>
        <div class="text-right">
          <div class="text-[11px] text-slate-400">Estado:</div>
          <div class="font-semibold text-emerald-400 capitalize">{{ team?.status }}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block font-semibold text-slate-300 mb-1">Tipo de Evento *</label>
          <select
            v-model="eventType"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          >
            <option value="subscription_payment">Pago de Suscripción Regular</option>
            <option value="extension">Extensión Comercial</option>
            <option value="courtesy">Cortesía / Prueba Piloto</option>
            <option value="adjustment">Ajuste Manual</option>
          </select>
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Meses a Extender *</label>
          <input
            v-model.number="months"
            type="number"
            min="1"
            max="36"
            required
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 font-mono focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Monto Cobrado (USD opcional)</label>
          <input
            v-model.number="amount"
            type="number"
            step="0.01"
            min="0"
            placeholder="0.00"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 font-mono focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block font-semibold text-slate-300 mb-1">Nota / Referencia</label>
          <input
            v-model="note"
            type="text"
            placeholder="Ej: Factura #2026-081"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-slate-200 focus:ring-1 focus:ring-emerald-500"
          />
        </div>
      </div>

      <div class="p-2.5 bg-emerald-950/40 border border-emerald-900/60 rounded-lg text-emerald-300 text-[11px]">
        <i class="bi bi-info-circle mr-1"></i>
        Al registrar el pago, la fecha <code>paid_until</code> se ampliará automáticamente y, si el club estaba inactivo por cobro, se reactivará inmediatamente.
      </div>

      <!-- Actions -->
      <div class="flex items-center justify-end gap-2.5 pt-4 border-t border-slate-800">
        <BaseButton
          variant="secondary"
          size="sm"
          type="button"
          :disabled="isSubmitting"
          @click="emit('close')"
        >
          Cancelar
        </BaseButton>
        <BaseButton
          variant="primary"
          size="sm"
          type="submit"
          :disabled="isSubmitting"
          class="!bg-blue-600 hover:!bg-blue-500 !text-white font-semibold"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin mr-1"></i>
          {{ isSubmitting ? 'Registrando...' : 'Confirmar Pago & Extender' }}
        </BaseButton>
      </div>
    </form>
  </BaseModal>
</template>
