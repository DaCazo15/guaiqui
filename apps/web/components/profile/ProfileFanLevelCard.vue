<script setup lang="ts">
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import type { FanProfileLevel, FanProfileStats } from '~/composables/useFanProfile'

defineProps<{
  level: FanProfileLevel
  stats: FanProfileStats
}>()
</script>

<template>
  <BaseCard class="p-6 bg-gradient-to-br from-slate-900 via-gray-900 to-emerald-950 text-white rounded-guaiqui-2xl border border-emerald-500/20 shadow-guaiqui-md overflow-hidden relative">
    <div class="absolute -right-8 -bottom-8 w-48 h-48 bg-emerald-500/10 rounded-full blur-2xl pointer-events-none"></div>

    <div class="relative z-10 space-y-6">
      <!-- Top Row: Tier Name & XP -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div class="flex items-center gap-3.5">
          <div class="w-12 h-12 rounded-2xl bg-white/10 backdrop-blur-sm border border-white/15 flex items-center justify-center text-2xl text-amber-400 shadow-inner">
            <i :class="`bi ${level.tier_icon}`" aria-hidden="true"></i>
          </div>
          <div>
            <span class="text-[11px] font-extrabold uppercase tracking-widest text-emerald-400">
              Nivel de Fanático
            </span>
            <h2 class="font-display font-black text-2xl uppercase tracking-wider text-white">
              {{ level.tier_name }}
            </h2>
          </div>
        </div>

        <div class="text-left sm:text-right">
          <span class="text-[11px] font-semibold text-gray-400 uppercase tracking-wider">
            Perlitas Históricas
          </span>
          <div class="flex items-center sm:justify-end gap-1.5 font-display font-extrabold text-xl text-emerald-400">
            <PearlAmount :amount="level.current_xp" size="md" />
          </div>
        </div>
      </div>

      <!-- Progress Bar to Next Level -->
      <div class="space-y-2">
        <div class="flex items-center justify-between text-xs font-semibold text-gray-300">
          <span>Progreso de Lealtad</span>
          <span v-if="level.next_threshold">
            {{ level.current_xp }} / {{ level.next_threshold }} pts ({{ level.progress_percent }}%)
          </span>
          <span v-else class="text-amber-400 font-bold uppercase tracking-wider">
            ¡Rango Máximo Alcanzado!
          </span>
        </div>
        <div class="w-full h-3 bg-white/10 rounded-full overflow-hidden p-0.5 border border-white/10">
          <div
            class="h-full bg-gradient-to-r from-emerald-500 to-teal-400 rounded-full transition-all duration-500"
            :style="{ width: `${level.progress_percent}%` }"
          ></div>
        </div>
      </div>

      <!-- Bottom Stats Row -->
      <div class="pt-4 border-t border-white/10 grid grid-cols-3 gap-2 text-center text-xs">
        <div class="p-2.5 rounded-xl bg-white/5 border border-white/5">
          <p class="text-gray-400 text-[11px] uppercase tracking-wider">Trivias Ganadas</p>
          <p class="font-display font-bold text-lg text-white mt-0.5">{{ stats.trivias_count }}</p>
        </div>
        <div class="p-2.5 rounded-xl bg-white/5 border border-white/5">
          <p class="text-gray-400 text-[11px] uppercase tracking-wider">Premios Canjeados</p>
          <p class="font-display font-bold text-lg text-emerald-300 mt-0.5">{{ stats.redemptions_count }}</p>
        </div>
        <div class="p-2.5 rounded-xl bg-white/5 border border-white/5">
          <p class="text-gray-400 text-[11px] uppercase tracking-wider">Racha Activa</p>
          <p class="font-display font-bold text-lg text-amber-300 mt-0.5">{{ stats.streak_days }} días</p>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
