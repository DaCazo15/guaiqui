<script setup lang="ts">
import { computed } from 'vue'

export type BadgeVariant = 'primary' | 'accent' | 'success' | 'warning' | 'danger' | 'info' | 'soft' | 'perlita'
export type BadgeSize = 'sm' | 'md' | 'lg'

interface Props {
  variant?: BadgeVariant
  size?: BadgeSize
  dot?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md',
  dot: false,
})

const variantClasses = computed(() => {
  switch (props.variant) {
    case 'accent':
      return 'bg-guaiqui-accent text-white'
    case 'success':
      return 'bg-guaiqui-status-success-soft text-emerald-800 border border-emerald-200'
    case 'warning':
      return 'bg-guaiqui-status-warning-soft text-amber-800 border border-amber-200'
    case 'danger':
      return 'bg-guaiqui-status-danger-soft text-rose-800 border border-rose-200'
    case 'info':
      return 'bg-guaiqui-status-info-soft text-blue-800 border border-blue-200'
    case 'soft':
      return 'bg-guaiqui-primary-soft text-guaiqui-primary-dark border border-green-200'
    case 'perlita':
      return 'bg-guaiqui-perlita-soft text-amber-900 border border-amber-300'
    case 'primary':
    default:
      return 'bg-guaiqui-primary text-white'
  }
})

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'px-2 py-0.5 text-xs font-medium gap-1'
    case 'lg':
      return 'px-3 py-1 text-sm font-semibold gap-2'
    case 'md':
    default:
      return 'px-2.5 py-0.5 text-xs font-semibold gap-1.5'
  }
})
</script>

<template>
  <span
    :class="[
      'inline-flex items-center rounded-guaiqui-full font-body leading-none',
      variantClasses,
      sizeClasses,
    ]"
  >
    <span
      v-if="dot"
      class="w-1.5 h-1.5 rounded-full bg-current opacity-80"
      aria-hidden="true"
    />
    <slot />
  </span>
</template>
