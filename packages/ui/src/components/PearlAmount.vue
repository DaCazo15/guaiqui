<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { formatPerlitas } from '@guaiqui/shared'
import PearlIcon, { type PearlIconSize } from './PearlIcon.vue'

interface Props {
  amount: number
  size?: 'sm' | 'md' | 'lg' | 'xl'
  showLabel?: boolean
  label?: string
  animated?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  amount: 0,
  size: 'md',
  showLabel: false,
  label: 'puntos',
  animated: false,
})

const displayAmount = ref(props.amount)

watch(
  () => props.amount,
  (newVal, oldVal) => {
    if (!props.animated || typeof window === 'undefined') {
      displayAmount.value = newVal
      return
    }

    const start = oldVal ?? 0
    const end = newVal
    const startTime = performance.now()
    const duration = 750

    const step = (currentTime: number) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      const easeProgress = 1 - Math.pow(1 - progress, 3)
      displayAmount.value = Math.round(start + (end - start) * easeProgress)

      if (progress < 1) {
        requestAnimationFrame(step)
      } else {
        displayAmount.value = end
      }
    }

    requestAnimationFrame(step)
  },
  { immediate: true }
)

const formatted = computed(() => formatPerlitas(displayAmount.value))

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'text-xs gap-1'
    case 'lg':
      return 'text-xl font-bold gap-2'
    case 'xl':
      return 'text-3xl font-extrabold gap-2.5'
    case 'md':
    default:
      return 'text-sm font-semibold gap-1.5'
  }
})

const iconSize = computed<PearlIconSize>(() => {
  switch (props.size) {
    case 'sm':
      return 'xs'
    case 'lg':
      return 'lg'
    case 'xl':
      return 'xl'
    case 'md':
    default:
      return 'md'
  }
})
</script>

<template>
  <span
    :class="[
      'inline-flex items-center font-display tracking-tight text-amber-900 dark:text-amber-300 tabular-nums select-none',
      sizeClasses,
    ]"
  >
    <PearlIcon :size="iconSize" animated />
    <span>{{ formatted }}</span>
    <span v-if="showLabel" class="font-body text-xs text-guaiqui-text-muted uppercase ml-0.5">
      {{ label }}
    </span>
  </span>
</template>
