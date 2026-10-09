<script setup lang="ts">
import { computed } from 'vue'

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
      return 'w-3.5 h-3.5'
    case 'sm':
      return 'w-4 h-4'
    case 'lg':
      return 'w-7 h-7'
    case 'xl':
      return 'w-10 h-10'
    case 'md':
    default:
      return 'w-5 h-5'
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
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      class="w-full h-full drop-shadow-xs"
    >
      <!-- Base Pearl Gradient -->
      <defs>
        <radialGradient
          id="pearlGradient"
          cx="35%"
          cy="30%"
          r="65%"
          fx="30%"
          fy="25%"
        >
          <stop offset="0%" stop-color="#FFFFFF" />
          <stop offset="30%" stop-color="#FFFDF5" />
          <stop offset="65%" stop-color="#F5E4B8" />
          <stop offset="90%" stop-color="#E5C778" />
          <stop offset="100%" stop-color="#C59C38" />
        </radialGradient>

        <linearGradient
          id="strokeGradient"
          x1="0%"
          y1="0%"
          x2="100%"
          y2="100%"
        >
          <stop offset="0%" stop-color="#D9A736" />
          <stop offset="50%" stop-color="#9E7618" />
          <stop offset="100%" stop-color="#6B4D08" />
        </linearGradient>

        <filter id="pearlGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="1" stdDeviation="1" flood-color="#000000" flood-opacity="0.15" />
        </filter>
      </defs>

      <!-- Main Pearl Body with Fine Outline -->
      <circle
        cx="16"
        cy="16"
        r="13.5"
        fill="url(#pearlGradient)"
        stroke="url(#strokeGradient)"
        stroke-width="1.2"
        filter="url(#pearlGlow)"
      />

      <!-- Iridescent Pearl Sheen/Shine -->
      <ellipse
        cx="11.5"
        cy="10.5"
        rx="4"
        ry="2.5"
        transform="rotate(-30 11.5 10.5)"
        fill="#FFFFFF"
        fill-opacity="0.85"
      />

      <!-- Secondary Reflection Sparkle -->
      <circle cx="21" cy="20.5" r="1.2" fill="#FFFFFF" fill-opacity="0.5" />
    </svg>
  </span>
</template>
