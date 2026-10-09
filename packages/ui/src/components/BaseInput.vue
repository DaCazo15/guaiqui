<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  modelValue: string | number | null | undefined
  label?: string
  placeholder?: string
  type?: string
  id?: string
  hint?: string
  error?: string
  disabled?: boolean
  required?: boolean
  readonly?: boolean
  autocomplete?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  label: '',
  placeholder: '',
  type: 'text',
  id: undefined,
  hint: '',
  error: '',
  disabled: false,
  required: false,
  readonly: false,
  autocomplete: 'off',
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
  (e: 'blur', event: FocusEvent): void
  (e: 'focus', event: FocusEvent): void
}>()

const inputId = computed(() => props.id || `input-${Math.random().toString(36).slice(2, 9)}`)

const handleInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
}
</script>

<template>
  <div class="flex flex-col gap-1.5 w-full">
    <label
      v-if="label"
      :for="inputId"
      class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text"
    >
      {{ label }}
      <span v-if="required" class="text-guaiqui-accent ml-0.5">*</span>
    </label>

    <div class="relative flex items-center">
      <slot name="prefix" />
      <input
        :id="inputId"
        :type="type"
        :value="modelValue"
        :placeholder="placeholder"
        :disabled="disabled"
        :readonly="readonly"
        :required="required"
        :autocomplete="autocomplete"
        :aria-invalid="!!error"
        :aria-describedby="error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined"
        :class="[
          'w-full h-10 px-3.5 py-2 text-sm bg-white border rounded-guaiqui-md text-guaiqui-text placeholder-guaiqui-text-subtle transition-colors duration-150',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-1',
          error
            ? 'border-guaiqui-status-danger focus-visible:ring-guaiqui-status-danger'
            : 'border-guaiqui-border hover:border-gray-400 focus-visible:ring-guaiqui-primary focus-visible:border-guaiqui-primary',
          disabled ? 'bg-guaiqui-surface opacity-60 cursor-not-allowed' : '',
        ]"
        @input="handleInput"
        @blur="emit('blur', $event)"
        @focus="emit('focus', $event)"
      />
      <slot name="suffix" />
    </div>

    <p
      v-if="error"
      :id="`${inputId}-error`"
      class="text-xs text-guaiqui-status-danger font-medium flex items-center gap-1"
    >
      <span>{{ error }}</span>
    </p>

    <p
      v-else-if="hint"
      :id="`${inputId}-hint`"
      class="text-xs text-guaiqui-text-muted"
    >
      {{ hint }}
    </p>
  </div>
</template>
