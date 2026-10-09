<script setup lang="ts">
import { computed } from 'vue'

export type SkeletonVariant = 'text' | 'circular' | 'rectangular' | 'card'

interface Props {
  variant?: SkeletonVariant
  width?: string
  height?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'text',
  width: undefined,
  height: undefined,
})

const variantClasses = computed(() => {
  switch (props.variant) {
    case 'circular':
      return 'rounded-full w-10 h-10'
    case 'rectangular':
      return 'rounded-guaiqui-md w-full h-32'
    case 'card':
      return 'rounded-guaiqui-lg w-full h-48'
    case 'text':
    default:
      return 'rounded-guaiqui-sm w-full h-4'
  }
})

const style = computed(() => {
  const res: Record<string, string> = {}
  if (props.width) res.width = props.width
  if (props.height) res.height = props.height
  return res
})
</script>

<template>
  <div
    :class="[
      'animate-pulse bg-gray-200/80 dark:bg-gray-700/60 inline-block',
      variantClasses,
    ]"
    :style="style"
    aria-hidden="true"
  />
</template>
