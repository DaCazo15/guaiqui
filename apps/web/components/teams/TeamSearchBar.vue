<script setup lang="ts">
defineProps<{
  modelValue: string
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
  (e: 'search'): void
}>()

const onInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
}

const clear = () => {
  emit('update:modelValue', '')
  emit('search')
}
</script>

<template>
  <div class="relative w-full">
    <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-guaiqui-text-muted">
      <i v-if="!loading" class="bi bi-search text-base"></i>
      <i v-else class="bi bi-arrow-repeat text-base animate-spin text-guaiqui-primary"></i>
    </div>
    <input
      :value="modelValue"
      type="text"
      placeholder="Buscar equipos por nombre o estado..."
      class="w-full pl-10 pr-10 py-2.5 bg-white border border-guaiqui-border rounded-guaiqui-lg text-sm text-guaiqui-text placeholder-guaiqui-text-muted focus:outline-none focus:border-guaiqui-primary focus:ring-2 focus:ring-guaiqui-primary/20 transition-all shadow-guaiqui-xs"
      @input="onInput"
      @keydown.enter="emit('search')"
    />
    <button
      v-if="modelValue"
      type="button"
      class="absolute inset-y-0 right-0 pr-3.5 flex items-center text-guaiqui-text-muted hover:text-guaiqui-text transition-colors cursor-pointer"
      title="Limpiar búsqueda"
      @click="clear"
    >
      <i class="bi bi-x-circle-fill text-sm"></i>
    </button>
  </div>
</template>
