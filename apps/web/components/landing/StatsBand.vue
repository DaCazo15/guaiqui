<script setup lang="ts">
import { teamStats } from '~/data/landingData'
</script>

<template>
  <section class="py-16 bg-gradient-to-r from-guaiqui-primary-dark via-guaiqui-primary to-emerald-950 text-white px-4 sm:px-8 shadow-inner">
    <div class="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center divide-y md:divide-y-0 md:divide-x divide-emerald-700/60">
      <div v-for="(stat, idx) in teamStats" :key="idx" class="pt-4 md:pt-0 px-2 space-y-1">
        <div class="font-display font-extrabold text-4xl sm:text-5xl text-amber-400 tabular-nums">
          {{ stat.value }}
        </div>
        <div class="font-display font-bold text-lg text-white uppercase tracking-tight">
          {{ stat.label }}
        </div>
        <div class="text-xs text-emerald-200/80">
          {{ stat.note }}
        </div>
      </div>
    </div>
  </section>
</template>
