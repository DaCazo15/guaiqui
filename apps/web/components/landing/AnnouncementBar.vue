<script setup lang="ts">
import { ref } from 'vue'
import { BaseBadge, PearlIcon } from '@guaiqui/ui'
import { nextMatchData } from '~/data/landingData'

const isVisible = ref(true)

const dismiss = () => {
  isVisible.value = false
}
</script>

<template>
  <div
    v-if="isVisible"
    class="bg-guaiqui-primary-dark text-white text-xs sm:text-sm py-2 px-4 flex items-center justify-between border-b border-emerald-800 relative z-50 select-none"
  >
    <div class="max-w-6xl mx-auto flex items-center justify-center gap-2 text-center flex-1 pr-6">
      <BaseBadge variant="accent" size="sm" class="hidden sm:inline-flex">HOY</BaseBadge>
      <span class="font-medium text-emerald-100 flex items-center gap-1.5 flex-wrap justify-center">
        <span class="flex items-center gap-1">
          <i class="bi bi-dribbble text-emerald-400"></i>
          <span>{{ nextMatchData.opponent }}</span>
        </span>
        <span class="hidden md:inline">• {{ nextMatchData.time }}</span>
        <span class="bg-emerald-800/80 px-2 py-0.5 rounded text-xs font-semibold text-amber-300 flex items-center gap-1">
          <PearlIcon size="xs" /> Trivia activa a las 6:45 PM
        </span>
      </span>
    </div>

    <button
      type="button"
      class="text-emerald-300 hover:text-white p-1 rounded-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-white"
      aria-label="Cerrar anuncio"
      @click="dismiss"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  </div>
</template>
