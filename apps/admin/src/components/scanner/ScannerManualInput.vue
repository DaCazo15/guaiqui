<script setup lang="ts">
import { ref, computed } from 'vue'

const emit = defineEmits<{
  (e: 'submit', code: string): void
}>()

const inputCode = ref('')

// Crockford Base32 validation
const cleanCode = computed(() => {
  return inputCode.value.toUpperCase().replace(/[-\s]/g, '')
})

const isValidFormat = computed(() => {
  return cleanCode.value.length === 12 && /^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{12}$/.test(cleanCode.value)
})

const validateChecksum = (code: string): boolean => {
  if (code.length !== 12) return false
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
  let sum = 0
  for (let i = 0; i < 11; i++) {
    const pos = alphabet.indexOf(code[i])
    if (pos === -1) return false
    sum += pos * (i + 1)
  }
  const expectedCheck = alphabet[sum % 32]
  return code[11] === expectedCheck
}

const isValidChecksum = computed(() => {
  if (!isValidFormat.value) return false
  return validateChecksum(cleanCode.value)
})

const handleSubmit = () => {
  if (cleanCode.value) {
    emit('submit', cleanCode.value)
    inputCode.value = ''
  }
}
</script>

<template>
  <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 sm:p-6 shadow-xl space-y-4">
    <h2 class="font-semibold text-sm text-slate-200 flex items-center gap-2">
      <i class="bi bi-keyboard text-emerald-400 text-base"></i>
      Ingreso Manual de Código
    </h2>

    <form @submit.prevent="handleSubmit" class="space-y-3">
      <div>
        <label class="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
          Código Base32 de 12 Caracteres
        </label>
        <div class="relative">
          <input
            v-model="inputCode"
            type="text"
            maxlength="16"
            placeholder="EJ: 3JK9-MNPQ-RSTX"
            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm font-mono text-white tracking-widest uppercase placeholder-slate-600 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
          />
          <span v-if="cleanCode.length > 0" class="absolute right-3 top-2.5 text-xs">
            <i v-if="isValidChecksum" class="bi bi-check-circle-fill text-emerald-400" title="Código y dígito verificador válidos"></i>
            <i v-else-if="cleanCode.length === 12" class="bi bi-x-circle-fill text-red-400" title="Dígito verificador inválido"></i>
            <span v-else class="text-slate-500 font-mono">{{ cleanCode.length }}/12</span>
          </span>
        </div>
      </div>

      <button
        type="submit"
        :disabled="!cleanCode"
        class="w-full py-2.5 px-4 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white font-semibold text-xs rounded-xl transition-all duration-150 flex items-center justify-center gap-2 shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <i class="bi bi-search text-sm"></i>
        <span>Verificar Código</span>
      </button>
    </form>
  </div>
</template>
