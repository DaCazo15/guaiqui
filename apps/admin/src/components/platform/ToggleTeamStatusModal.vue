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
  (e: 'statusChanged'): void
}>()

const reason = ref('')
const isSubmitting = ref(false)
const errorMessage = ref<string | null>(null)

watch(() => props.isOpen, () => {
  reason.value = ''
  errorMessage.value = null
})

const isDeactivating = () => props.team?.status === 'active'

const handleSubmit = async () => {
  if (!props.team) return
  if (!reason.value.trim()) {
    errorMessage.value = 'Debe indicar un motivo obligatorio para el cambio de estado.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = null

  const targetStatus = isDeactivating() ? 'inactive' : 'active'

  try {
    const { error } = await supabase.rpc('admin_toggle_team_status', {
      p_team_id: props.team.id,
      p_status: targetStatus,
      p_reason: reason.value.trim()
    })

    if (error) throw error

    emit('statusChanged')
    emit('close')
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cambiar estado del equipo'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    :title="isDeactivating() ? `Desactivar Franquicia: ${team?.name || ''}` : `Reactivar Franquicia: ${team?.name || ''}`"
    @close="emit('close')"
  >
    <form @submit.prevent="handleSubmit" class="space-y-4 text-xs">
      <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-lg">
        {{ errorMessage }}
      </div>

      <div
        :class="[
          'p-3 rounded-lg border text-xs',
          isDeactivating()
            ? 'bg-amber-950/40 border-amber-900/60 text-amber-300'
            : 'bg-emerald-950/40 border-emerald-900/60 text-emerald-300'
        ]"
      >
        <div class="font-bold flex items-center gap-1.5 mb-1">
          <i :class="isDeactivating() ? 'bi bi-exclamation-triangle-fill text-amber-400' : 'bi bi-check-circle-fill text-emerald-400'"></i>
          {{ isDeactivating() ? 'Atención: Suspensión de Servicio' : 'Reactivación de Servicio' }}
        </div>
        <p v-if="isDeactivating()">
          Al pasar el equipo a estado <strong>Inactivo</strong>, su personal no podrá operar en el panel de taquilla/administración, y sus fanáticos no podrán jugar trivias ni canjear nuevos premios (sus saldos e historial se preservan de forma segura).
        </p>
        <p v-else>
          El equipo volverá a estar plenamente operativo para su personal y sus fanáticos.
        </p>
      </div>

      <div>
        <label class="block font-semibold text-slate-300 mb-1">
          Motivo del cambio de estado (auditoría obligatoria) *
        </label>
        <textarea
          v-model="reason"
          required
          rows="3"
          placeholder="Ej: Suspensión por acuerdo de directiva / Regularización de cuotas..."
          class="w-full bg-slate-900 border border-slate-700 rounded-lg p-2.5 text-slate-200 focus:ring-1 focus:ring-emerald-500"
        ></textarea>
      </div>

      <div class="flex items-center justify-end gap-2.5 pt-3 border-t border-slate-800">
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
          :class="isDeactivating() ? '!bg-red-600 hover:!bg-red-500 !text-white' : '!bg-emerald-600 hover:!bg-emerald-500 !text-white'"
        >
          <i v-if="isSubmitting" class="bi bi-arrow-repeat animate-spin mr-1"></i>
          {{ isSubmitting ? 'Procesando...' : (isDeactivating() ? 'Confirmar Desactivación' : 'Confirmar Reactivación') }}
        </BaseButton>
      </div>
    </form>
  </BaseModal>
</template>
