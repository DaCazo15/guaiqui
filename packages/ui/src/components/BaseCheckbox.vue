<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  modelValue?: boolean
  label?: string
  id?: string
  hint?: string
  disabled?: boolean
  required?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  label: '',
  id: undefined,
  hint: '',
  disabled: false,
  required: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
}>()

const checkboxId = computed(() => props.id || `checkbox-${Math.random().toString(36).slice(2, 9)}`)

const toggle = () => {
  if (!props.disabled) {
    emit('update:modelValue', !props.modelValue)
  }
}
</script>

<template>
  <div class="flex items-start gap-2.5">
    <div class="relative flex items-center h-5">
      <input
        :id="checkboxId"
        type="checkbox"
        :checked="modelValue"
        :disabled="disabled"
        :required="required"
        class="sr-only peer"
        @change="toggle"
      />
      <div
        :class="[
          'w-5 h-5 rounded-guaiqui-sm border flex items-center justify-center transition-all duration-150 cursor-pointer',
          'peer-focus-visible:ring-2 peer-focus-visible:ring-guaiqui-primary peer-focus-visible:ring-offset-2',
          modelValue
            ? 'bg-guaiqui-primary border-guaiqui-primary text-white'
            : 'bg-white border-guaiqui-border hover:border-gray-400',
          disabled ? 'opacity-50 cursor-not-allowed bg-guaiqui-surface' : '',
        ]"
        @click="toggle"
      >
        <svg
          v-if="modelValue"
          class="w-3.5 h-3.5 fill-current stroke-current stroke-2"
          viewBox="0 0 24 24"
        >
          <path d="M20 6L9 17l-5-5" fill="none" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </div>
    </div>

    <div v-if="label || $slots.default" class="text-sm select-none">
      <label
        :for="checkboxId"
        :class="[
          'font-medium text-guaiqui-text cursor-pointer',
          disabled ? 'opacity-60 cursor-not-allowed' : '',
        ]"
      >
        <slot>{{ label }}</slot>
        <span v-if="required" class="text-guaiqui-accent ml-0.5">*</span>
      </label>
      <p v-if="hint" class="text-xs text-guaiqui-text-muted mt-0.5">
        {{ hint }}
      </p>
    </div>
  </div>
</template>
