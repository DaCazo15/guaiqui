<script setup lang="ts">
import { ref, computed } from 'vue'

export type CardVariant = 'default' | 'flat' | 'outline' | 'interactive'
export type CardPadding = 'none' | 'sm' | 'md' | 'lg'

interface Props {
  variant?: CardVariant
  padding?: CardPadding
  spotlight?: boolean
  spotlightColor?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'default',
  padding: 'md',
  spotlight: false,
  spotlightColor: 'rgba(16, 185, 129, 0.16)',
})

const cardRef = ref<HTMLElement | null>(null)
const mousePos = ref({ x: 0, y: 0 })
const isHovered = ref(false)

const handleMouseMove = (e: MouseEvent) => {
  if (!props.spotlight || !cardRef.value) return
  const rect = cardRef.value.getBoundingClientRect()
  mousePos.value = {
    x: e.clientX - rect.left,
    y: e.clientY - rect.top,
  }
}

const handleMouseEnter = () => {
  if (props.spotlight) isHovered.value = true
}

const handleMouseLeave = () => {
  if (props.spotlight) isHovered.value = false
}

const variantClasses = computed(() => {
  switch (props.variant) {
    case 'flat':
      return 'bg-guaiqui-surface border-none text-guaiqui-text'
    case 'outline':
      return 'bg-guaiqui-surface border border-guaiqui-border text-guaiqui-text'
    case 'interactive':
      return 'bg-guaiqui-surface border border-guaiqui-border hover:border-guaiqui-primary hover:shadow-guaiqui-md cursor-pointer transition-all duration-200 text-guaiqui-text'
    case 'default':
    default:
      return 'bg-guaiqui-surface border border-guaiqui-border shadow-guaiqui-sm text-guaiqui-text'
  }
})

const paddingClasses = computed(() => {
  switch (props.padding) {
    case 'none':
      return 'p-0'
    case 'sm':
      return 'p-3 sm:p-4'
    case 'lg':
      return 'p-6 sm:p-8'
    case 'md':
    default:
      return 'p-4 sm:p-6'
  }
})
</script>

<template>
  <div
    ref="cardRef"
    :class="[
      'rounded-guaiqui-lg overflow-hidden flex flex-col relative',
      variantClasses,
    ]"
    @mousemove="handleMouseMove"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
  >
    <!-- 21st.dev Spotlight Glow Effect -->
    <div
      v-if="spotlight"
      class="pointer-events-none absolute inset-0 z-0 transition-opacity duration-300 ease-out"
      :style="{
        opacity: isHovered ? 1 : 0,
        background: `radial-gradient(circle 260px at ${mousePos.x}px ${mousePos.y}px, ${spotlightColor}, transparent 80%)`,
      }"
    />
    <div v-if="$slots.image" class="w-full">
      <slot name="image" />
    </div>

    <div
      v-if="$slots.header"
      class="border-b border-guaiqui-border px-2.5 py-2 sm:px-6 sm:py-4 font-display font-semibold text-lg text-guaiqui-text"
    >
      <slot name="header" />
    </div>

    <div :class="['flex-1', paddingClasses]">
      <slot />
    </div>

    <div
      v-if="$slots.footer"
      class="border-t border-guaiqui-border px-2.5 py-2 sm:px-6 sm:py-4 bg-guaiqui-surface"
    >
      <slot name="footer" />
    </div>
  </div>
</template>
