<script setup lang="ts">
import { PearlAmount } from '@guaiqui/ui'
import type { UserRankInfo } from '~/stores/trivias'

defineProps<{
  myRank?: UserRankInfo | null
  teamName?: string | null
}>()
</script>

<template>
  <div
    v-if="myRank"
    class="bg-gradient-to-r from-emerald-900 via-gray-900 to-slate-900 text-white rounded-guaiqui-xl p-4 sm:p-5 border border-emerald-500/30 shadow-guaiqui-sm flex flex-col sm:flex-row items-center justify-between gap-4"
  >
    <div class="flex items-center gap-3.5 w-full sm:w-auto">
      <div class="w-12 h-12 rounded-xl bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center font-display font-black text-xl text-emerald-400 shrink-0">
        #{{ myRank.rank }}
      </div>
      <div>
        <p class="text-[11px] font-bold text-emerald-400 uppercase tracking-widest">
          Tu Posición Oficial {{ teamName ? `(${teamName})` : '' }}
        </p>
        <p class="font-display font-bold text-base text-white">
          Estás en el puesto <span class="text-emerald-300">#{{ myRank.rank }}</span> de la tabla de posiciones
        </p>
      </div>
    </div>

    <div class="flex items-center justify-between sm:justify-end gap-4 w-full sm:w-auto pt-2 sm:pt-0 border-t sm:border-t-0 border-white/10">
      <span class="px-2.5 py-1 rounded-md text-xs font-bold uppercase tracking-wider bg-white/10 text-gray-200">
        {{ myRank.tier_name }}
      </span>

      <div class="flex items-center gap-1.5 font-display font-extrabold text-lg text-emerald-400">
        <PearlAmount :amount="myRank.pearls_earned" size="sm" />
      </div>
    </div>
  </div>
</template>
