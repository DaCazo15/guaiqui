<script setup lang="ts">
import { computed } from 'vue'

export interface SelectOption {
  label: string
  value: string | number
  disabled?: boolean
}

interface Props {
  modelValue: string | number | null | undefined
  options: SelectOption[]
  label?: string
  placeholder?: string
  id?: string
  hint?: string
  error?: string
  disabled?: boolean
  required?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  options: () => [],
  label: '',
  placeholder: 'Seleccionar una opción',
  id: undefined,
  hint: '',
  error: '',
  disabled: false,
  required: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string | number): void
  (e: 'change', event: Event): void
}>()

const selectId = computed(() => props.id || `select-${Math.random().toString(36).slice(2, 9)}`)

const handleChange = (event: Event) => {
  const target = event.target as HTMLSelectElement
  emit('update:modelValue', target.value)
  emit('change', event)
}
</script>

<template>
  <div class="flex flex-col gap-1.5 w-full">
    <label
      v-if="label"
      :for="selectId"
      class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text"
    >
      {{ label }}
      <span v-if="required" class="text-guaiqui-accent ml-0.5">*</span>
    </label>

    <div class="relative flex items-center">
      <select
        :id="selectId"
        :value="modelValue"
        :disabled="disabled"
        :required="required"
        :aria-invalid="!!error"
        :aria-describedby="error ? `${selectId}-error` : hint ? `${selectId}-hint` : undefined"
        :class="[
          'w-full h-10 px-3.5 py-2 text-sm bg-white border rounded-guaiqui-md text-guaiqui-text appearance-none transition-colors duration-150 pr-10',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-1',
          error
            ? 'border-guaiqui-status-danger focus-visible:ring-guaiqui-status-danger'
            : 'border-guaiqui-border hover:border-gray-400 focus-visible:ring-guaiqui-primary focus-visible:border-guaiqui-primary',
          disabled ? 'bg-guaiqui-surface opacity-60 cursor-not-allowed' : 'cursor-pointer',
        ]"
        @change="handleChange"
      >
        <option v-if="placeholder" value="" disabled :selected="!modelValue">
          {{ placeholder }}
        </option>
        <option
          v-for="opt in options"
          :key="opt.value"
          :value="opt.value"
          :disabled="opt.disabled"
        >
          {{ opt.label }}
        </option>
      </select>

      <div class="absolute right-3 pointer-events-none text-guaiqui-text-muted">
        <svg class="w-4 h-4 fill-current" viewBox="0 0 20 20">
          <path d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
        </svg>
      </div>
    </div>

    <p
      v-if="error"
      :id="`${selectId}-error`"
      class="text-xs text-guaiqui-status-danger font-medium"
    >
      {{ error }}
    </p>

    <p
      v-else-if="hint"
      :id="`${selectId}-hint`"
      class="text-xs text-guaiqui-text-muted"
    >
      {{ hint }}
    </p>
  </div>
</template>
