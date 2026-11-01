<script setup lang="ts">
import type { TeamLandingTopRankingUser } from '@guaiqui/shared'

defineProps<{
  ranking: TeamLandingTopRankingUser[]
  teamName: string
}>()
</script>

<template>
  <section class="py-14 sm:py-20 bg-slate-950 border-b border-slate-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-10">
        <div>
          <span class="text-xs sm:text-sm font-bold uppercase tracking-wider text-emerald-400 font-sans">
            Cuadro de Honor
          </span>
          <h2 class="text-2xl sm:text-4xl font-black font-title text-white mt-1">
            Top Fanáticos de {{ teamName }}
          </h2>
        </div>
        <p class="text-xs sm:text-sm text-slate-400 max-w-md">
          Los miembros de la comunidad que lideran la tabla de posiciones con mayor cantidad de perlitas acumuladas en este club.
        </p>
      </div>

      <!-- Empty state -->
      <div
        v-if="ranking.length === 0"
        class="text-center py-12 bg-slate-900/40 border border-slate-800 rounded-2xl p-6 max-w-md mx-auto space-y-3"
      >
        <div class="w-12 h-12 mx-auto rounded-full bg-slate-800 flex items-center justify-center text-slate-400 text-xl">
          <i class="bi bi-trophy"></i>
        </div>
        <h3 class="text-base font-bold text-white">Sé el primer fanático en liderar</h3>
        <p class="text-xs text-slate-400">
          Aún no hay puntuaciones registradas en esta franquicia. ¡Regístrate, responde una trivia y encabeza la tabla!
        </p>
      </div>

      <!-- Top Ranking List -->
      <div v-else class="max-w-3xl mx-auto bg-slate-900/60 border border-slate-800 rounded-2xl divide-y divide-slate-800/80 overflow-hidden shadow-xl">
        <div
          v-for="fan in ranking"
          :key="fan.rank"
          class="flex items-center justify-between p-4 sm:px-6 hover:bg-slate-900 transition-colors"
        >
          <div class="flex items-center gap-3 sm:gap-4 min-w-0">
            <!-- Rank Badge -->
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-black shrink-0 font-title"
              :class="[
                fan.rank === 1 ? 'bg-amber-400 text-slate-950 ring-2 ring-amber-300' :
                fan.rank === 2 ? 'bg-slate-300 text-slate-950 ring-2 ring-slate-200' :
                fan.rank === 3 ? 'bg-amber-700 text-white ring-2 ring-amber-600' :
                'bg-slate-800 text-slate-400'
              ]"
            >
              <i v-if="fan.rank === 1" class="bi bi-award-fill"></i>
              <span v-else>{{ fan.rank }}</span>
            </div>

            <!-- Avatar -->
            <div class="w-10 h-10 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center overflow-hidden shrink-0">
              <img
                v-if="fan.avatar_url"
                :src="fan.avatar_url"
                :alt="fan.display_name"
                class="w-full h-full object-cover"
                loading="lazy"
                width="40"
                height="40"
              />
              <i v-else class="bi bi-person-fill text-slate-400 text-lg"></i>
            </div>

            <!-- Name -->
            <div class="min-w-0">
              <p class="text-sm font-bold text-white truncate font-sans">
                {{ fan.display_name }}
              </p>
              <p class="text-[11px] text-slate-400">
                Puesto #{{ fan.rank }}
              </p>
            </div>
          </div>

          <!-- Points Badge -->
          <div class="text-right shrink-0">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs sm:text-sm font-black font-title">
              <i class="bi bi-gem"></i>
              {{ fan.points }} perlitas
            </span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
