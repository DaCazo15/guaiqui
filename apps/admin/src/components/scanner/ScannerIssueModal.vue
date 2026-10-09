<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  isOpen: boolean
  redemptionId: string | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'submit', payload: { reason: string; note: string }): void
}>()

const selectedReason = ref('wrong_size')
const customNote = ref('')

const issueReasons = [
  { value: 'wrong_size', label: 'Talla o variante incorrecta' },
  { value: 'damaged', label: 'Producto dañado o defectuoso' },
  { value: 'identity_mismatch', label: 'Identidad del fanático no coincide' },
  { value: 'out_of_stock_physical', label: 'Sin inventario físico en taquilla' },
  { value: 'other', label: 'Otro motivo' }
]

const handleSubmit = () => {
  emit('submit', { reason: selectedReason.value, note: customNote.value })
  customNote.value = ''
}
</script>

<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-xs">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
      <div class="flex items-center justify-between border-b border-slate-800 pb-3">
        <h3 class="font-bold text-lg text-white flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill text-amber-500"></i>
          Reportar Incidencia de Canje
        </h3>
        <button @click="emit('close')" class="text-slate-400 hover:text-white">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Motivo de Incidencia <span class="text-amber-400">*</span>
          </label>
          <select
            v-model="selectedReason"
            required
            class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-amber-500"
          >
            <option v-for="r in issueReasons" :key="r.value" :value="r.value">{{ r.label }}</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Detalles u Observaciones
          </label>
          <textarea
            v-model="customNote"
            rows="3"
            placeholder="Explicación detallada de la incidencia..."
            class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500"
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
            class="px-4 py-2 bg-amber-600 hover:bg-amber-500 text-slate-950 font-bold text-xs rounded-xl"
          >
            Registrar Incidencia
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
