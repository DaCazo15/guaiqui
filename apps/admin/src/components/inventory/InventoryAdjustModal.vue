<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  isOpen: boolean
  product: any
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'submit', payload: { delta: number; reason: string }): void
}>()

const delta = ref(0)
const reason = ref('')
const isSubmitting = ref(false)

const handleSubmit = () => {
  if (!reason.value.trim()) {
    alert('El motivo del ajuste de inventario es obligatorio.')
    return
  }

  const currentStock = props.product?.stock || 0
  if (currentStock + delta.value < 0) {
    alert('El ajuste resultaría en existencias negativas. No está permitido.')
    return
  }

  isSubmitting.value = true
  emit('submit', { delta: delta.value, reason: reason.value.trim() })
  isSubmitting.value = false
}
</script>

<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-xs">
    <div class="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
      <div class="flex items-center justify-between border-b border-slate-800 pb-3">
        <h3 class="font-bold text-lg text-white flex items-center gap-2">
          <i class="bi bi-box-seam-fill text-emerald-400"></i>
          Ajustar Existencias
        </h3>
        <button @click="emit('close')" class="text-slate-400 hover:text-white">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>

      <div class="p-3 bg-slate-950/60 border border-slate-800 rounded-xl text-xs space-y-1">
        <span class="text-slate-400 block">Producto</span>
        <span class="font-bold text-white text-sm block">{{ product?.name }}</span>
        <span class="text-slate-400 block">Stock Actual: <strong class="text-emerald-400 font-mono">{{ product?.stock }}</strong> unidades</span>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Cantidad a Ajustar (Delta) <span class="text-emerald-400">*</span>
          </label>
          <div class="flex items-center gap-2">
            <button
              type="button"
              @click="delta--"
              class="w-10 h-10 bg-slate-800 hover:bg-slate-700 text-white font-bold rounded-xl text-lg flex items-center justify-center"
            >
              -
            </button>
            <input
              v-model.number="delta"
              type="number"
              required
              class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-center text-base font-mono font-bold text-white focus:outline-none focus:border-emerald-500"
            />
            <button
              type="button"
              @click="delta++"
              class="w-10 h-10 bg-slate-800 hover:bg-slate-700 text-white font-bold rounded-xl text-lg flex items-center justify-center"
            >
              +
            </button>
          </div>
          <span class="text-[11px] text-slate-500 mt-1 block">
            Stock Resultante: <strong :class="['font-mono', (product?.stock + delta) < 0 ? 'text-red-400' : 'text-emerald-400']">{{ (product?.stock || 0) + delta }}</strong>
          </span>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
            Motivo Obligatorio del Ajuste <span class="text-red-400">*</span>
          </label>
          <textarea
            v-model="reason"
            required
            rows="3"
            placeholder="Ej: Recepción de lote de proveedor, producto extraviado, etc."
            class="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
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
            :disabled="isSubmitting || !reason.trim()"
            class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-xl shadow-md disabled:opacity-50"
          >
            Guardar Ajuste
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
