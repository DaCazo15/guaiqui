<script setup lang="ts">
import { computed } from 'vue'

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'outline'

export type ButtonSize = 'sm' | 'md' | 'lg'

interface Props {
  variant?: ButtonVariant
  size?: ButtonSize
  type?: 'button' | 'submit' | 'reset'
  disabled?: boolean
  loading?: boolean
  block?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md',
  type: 'button',
  disabled: false,
  loading: false,
  block: false,
})

const emit = defineEmits<{
  (e: 'click', event: MouseEvent): void
}>()

const handleClick = (event: MouseEvent) => {
  if (!props.disabled && !props.loading) {
    emit('click', event)
  }
}

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'h-8 px-3 text-xs font-medium gap-1.5 rounded-guaiqui-sm'
    case 'lg':
      return 'h-12 px-6 text-base font-semibold gap-2.5 rounded-guaiqui-lg'
    case 'md':
    default:
      return 'h-10 px-4 text-sm font-semibold gap-2 rounded-guaiqui-md'
  }
})

const variantClasses = computed(() => {
  switch (props.variant) {
    case 'secondary':
    case 'outline':
      return 'bg-guaiqui-surface text-guaiqui-text border border-guaiqui-border hover:bg-guaiqui-surface-hover active:bg-gray-200'
    case 'ghost':
      return 'bg-transparent text-guaiqui-text hover:bg-guaiqui-primary-soft hover:text-guaiqui-primary active:bg-green-100'
    case 'danger':
      return 'bg-guaiqui-status-danger text-white hover:bg-red-600 active:bg-red-700'
    case 'primary':
    default:
      return 'bg-guaiqui-primary text-white hover:bg-guaiqui-primary-dark active:bg-emerald-900'
  }
})
</script>

<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :class="[
      'inline-flex items-center justify-center transition-colors duration-150 ease-in-out cursor-pointer select-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary focus-visible:ring-offset-2',
      sizeClasses,
      variantClasses,
      block ? 'w-full' : '',
      (disabled || loading) ? 'opacity-60 cursor-not-allowed pointer-events-none' : '',
    ]"
    @click="handleClick"
  >
    <!-- Spinner during loading -->
    <svg
      v-if="loading"
      class="animate-spin -ml-0.5 h-4 w-4 text-current"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <circle
        class="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        stroke-width="4"
      />
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      />
    </svg>

    <slot v-if="!loading" name="prefix" />
    <span><slot /></span>
    <slot v-if="!loading" name="suffix" />
  </button>
</template>
