<script setup lang="ts">
import { computed } from 'vue'
import perlaCoinImg from '../assets/perla-coin.webp'

export type PearlIconSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl'

interface Props {
  size?: PearlIconSize
  animated?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  animated: false,
})

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'xs':
      return 'w-4 h-4'
    case 'sm':
      return 'w-5 h-5'
    case 'lg':
      return 'w-7 h-7'
    case 'xl':
      return 'w-10 h-10'
    case 'md':
    default:
      return 'w-6 h-6'
  }
})
</script>

<template>
  <span
    :class="[
      'inline-flex items-center justify-center flex-shrink-0 relative select-none',
      sizeClasses,
      animated ? 'hover:scale-110 transition-transform duration-200' : '',
    ]"
    title="Perlitas"
    aria-label="Ícono de Perlita"
  >
    <img
      :src="perlaCoinImg"
      alt="Perlita"
      class="w-full h-full object-contain drop-shadow-xs"
    />
  </span>
</template>

