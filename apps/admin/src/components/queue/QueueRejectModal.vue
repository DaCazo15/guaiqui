<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  isOpen: boolean
  redemption: any
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm', payload: { reason: string; note: string }): void
}>()

const selectedReason = ref('Sin inventario físico')
const customNote = ref('')
const isSubmitting = ref(false)

const predefinedReasons = [
  'Sin inventario físico',
  'Fanático no localizado',
  'Incumplimiento de términos',
  'Solicitado por el fanático',
  'Otro motivo'
]

const handleSubmit = () => {
  const finalReason = selectedReason.value === 'Otro motivo' ? (customNote.value || 'Otro motivo') : selectedReason.value
  isSubmitting.value = true
  emit('confirm', { reason: finalReason, note: customNote.value })
  isSubmitting.value = false
}
</script>

<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-xs">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
      <div class="flex items-center justify-between border-b border-slate-800 pb-3">
        <h3 class="font-bold text-lg text-white flex items-center gap-2">
          <i class="bi bi-x-circle-fill text-red-500"></i>
          Rechazar Canje
        </h3>
        <button @click="emit('close')" class="text-slate-400 hover:text-white">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <p class="text-xs text-slate-300">
        Se reembolsarán <strong class="text-emerald-400">{{ redemption?.cost_pearls }} perlitas</strong> al saldo del fanático de forma automática.
      </p>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Motivo de Rechazo <span class="text-red-400">*</span>
          </label>
          <select
            v-model="selectedReason"
            required
            class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-red-500"
          >
            <option v-for="r in predefinedReasons" :key="r" :value="r">{{ r }}</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Observaciones Adicionales
          </label>
          <textarea
            v-model="customNote"
            rows="3"
            placeholder="Detalles adicionales para auditoría..."
            class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-red-500"
          ></textarea>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button
            type="button"
            @click="emit('close')"
            class="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl"
          >
            Cancelar
          </button>
          <button
            type="submit"
            :disabled="isSubmitting"
            class="px-4 py-2 bg-red-600 hover:bg-red-500 text-white text-xs font-semibold rounded-xl"
          >
            Confirmar Rechazo
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
