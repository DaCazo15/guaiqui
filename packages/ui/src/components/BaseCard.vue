<script setup lang="ts">
import { computed } from 'vue'

export type CardVariant = 'default' | 'flat' | 'outline' | 'interactive'
export type CardPadding = 'none' | 'sm' | 'md' | 'lg'

interface Props {
  variant?: CardVariant
  padding?: CardPadding
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'default',
  padding: 'md',
})

const variantClasses = computed(() => {
  switch (props.variant) {
    case 'flat':
      return 'bg-guaiqui-surface border-none'
    case 'outline':
      return 'bg-white border border-guaiqui-border'
    case 'interactive':
      return 'bg-white border border-guaiqui-border hover:border-guaiqui-primary hover:shadow-guaiqui-md cursor-pointer transition-all duration-200'
    case 'default':
    default:
      return 'bg-white border border-guaiqui-border shadow-guaiqui-sm'
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
    :class="[
      'rounded-guaiqui-lg overflow-hidden flex flex-col',
      variantClasses,
    ]"
  >
    <div v-if="$slots.image" class="w-full">
      <slot name="image" />
    </div>

    <div
      v-if="$slots.header"
      class="border-b border-guaiqui-border px-4 py-3 sm:px-6 sm:py-4 font-display font-semibold text-lg text-guaiqui-text"
    >
      <slot name="header" />
    </div>

    <div :class="['flex-1', paddingClasses]">
      <slot />
    </div>

    <div
      v-if="$slots.footer"
      class="border-t border-guaiqui-border px-4 py-3 sm:px-6 sm:py-4 bg-guaiqui-surface"
    >
      <slot name="footer" />
    </div>
  </div>
</template>
