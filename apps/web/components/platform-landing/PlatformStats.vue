<script setup lang="ts">
import type { PlatformLandingTotals } from '@guaiqui/shared'

defineProps<{
  totals?: PlatformLandingTotals
}>()
</script>

<template>
  <section class="py-10 bg-[#08181f] border-b border-cyan-950 text-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6 text-center">
        <!-- 1. Clubes Oficiales -->
        <div class="p-5 rounded-2xl bg-[#0c1f26]/80 border border-cyan-900/40 hover:border-cyan-500/30 transition-all shadow-md">
          <div class="flex items-center justify-center gap-2 mb-1">
            <i class="bi bi-shield-shaded text-cyan-400 text-lg"></i>
            <p class="text-3xl sm:text-4xl font-black font-title text-cyan-300">
              {{ totals?.total_teams ?? 1 }}
            </p>
          </div>
          <p class="text-xs sm:text-sm text-slate-300 font-medium">
            Clubes Oficiales
          </p>
        </div>

        <!-- 2. Fanáticos Registrados -->
        <div class="p-5 rounded-2xl bg-[#0c1f26]/80 border border-cyan-900/40 hover:border-orange-500/30 transition-all shadow-md">
          <div class="flex items-center justify-center gap-2 mb-1">
            <i class="bi bi-people-fill text-orange-400 text-lg"></i>
            <p class="text-3xl sm:text-4xl font-black font-title text-orange-400">
              {{ totals?.total_fans ?? 0 }}
            </p>
          </div>
          <p class="text-xs sm:text-sm text-slate-300 font-medium">
            Fanáticos Registrados
          </p>
        </div>

        <!-- 3. Trivias Respondidas -->
        <div class="p-5 rounded-2xl bg-[#0c1f26]/80 border border-cyan-900/40 hover:border-cyan-500/30 transition-all shadow-md">
          <div class="flex items-center justify-center gap-2 mb-1">
            <i class="bi bi-patch-question-fill text-cyan-400 text-lg"></i>
            <p class="text-3xl sm:text-4xl font-black font-title text-cyan-300">
              {{ totals?.total_trivias_played ?? 0 }}
            </p>
          </div>
          <p class="text-xs sm:text-sm text-slate-300 font-medium">
            Trivias Respondidas
          </p>
        </div>

        <!-- 4. Recompensas Entregadas -->
        <div class="p-5 rounded-2xl bg-[#0c1f26]/80 border border-cyan-900/40 hover:border-orange-500/30 transition-all shadow-md">
          <div class="flex items-center justify-center gap-2 mb-1">
            <i class="bi bi-gift-fill text-orange-400 text-lg"></i>
            <p class="text-3xl sm:text-4xl font-black font-title text-orange-400">
              {{ totals?.total_rewards_claimed ?? 0 }}
            </p>
          </div>
          <p class="text-xs sm:text-sm text-slate-300 font-medium">
            Recompensas Entregadas
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
