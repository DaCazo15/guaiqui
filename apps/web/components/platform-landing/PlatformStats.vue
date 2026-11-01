<script setup lang="ts">
import type { PlatformLandingTotals } from '@guaiqui/shared'

defineProps<{
  totals?: PlatformLandingTotals
}>()
</script>

<template>
  <section class="py-12 bg-emerald-950/40 border-b border-emerald-900/40 text-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-6 text-center">
        <div class="p-4 rounded-xl bg-slate-900/50 border border-emerald-800/20">
          <p class="text-3xl sm:text-4xl font-black font-title text-emerald-400">
            {{ totals?.total_teams ?? 1 }}
          </p>
          <p class="text-xs sm:text-sm text-slate-300 font-medium mt-1">
            Clubes Oficiales
          </p>
        </div>

        <div class="p-4 rounded-xl bg-slate-900/50 border border-emerald-800/20">
          <p class="text-3xl sm:text-4xl font-black font-title text-emerald-400">
            {{ totals?.total_fans ?? 0 }}
          </p>
          <p class="text-xs sm:text-sm text-slate-300 font-medium mt-1">
            Fanáticos Registrados
          </p>
        </div>

        <div class="p-4 rounded-xl bg-slate-900/50 border border-emerald-800/20">
          <p class="text-3xl sm:text-4xl font-black font-title text-emerald-400">
            {{ totals?.total_trivias_played ?? 0 }}
          </p>
          <p class="text-xs sm:text-sm text-slate-300 font-medium mt-1">
            Trivias Respondidas
          </p>
        </div>

        <div class="p-4 rounded-xl bg-slate-900/50 border border-emerald-800/20">
          <p class="text-3xl sm:text-4xl font-black font-title text-emerald-400">
            {{ totals?.total_rewards_claimed ?? 0 }}
          </p>
          <p class="text-xs sm:text-sm text-slate-300 font-medium mt-1">
            Recompensas Entregadas
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
