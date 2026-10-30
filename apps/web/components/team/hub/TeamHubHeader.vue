<script setup lang="ts">
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'
import type { TeamSummary } from '~/composables/useCurrentTeam'

defineProps<{
  team: TeamSummary
  toggling?: boolean
}>()

const emit = defineEmits<{
  (e: 'toggleFollow'): void
  (e: 'switchTeam'): void
}>()
</script>

<template>
  <div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900 border border-emerald-500/30 p-5 sm:p-7 shadow-2xl">
    <!-- Background glow -->
    <div
      class="absolute top-0 right-0 w-80 h-80 rounded-full blur-3xl opacity-20 pointer-events-none -mr-20 -mt-20"
      :style="{ backgroundColor: team.primary_color || '#10b981' }"
    ></div>

    <div class="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-5">
      <!-- Team Brand Info -->
      <div class="flex items-center gap-4 min-w-0">
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-slate-950 border border-slate-700/60 p-2 shrink-0 flex items-center justify-center shadow-lg">
          <img
            v-if="team.logo_url"
            :src="team.logo_url"
            :alt="team.name"
            class="w-full h-full object-contain"
          />
          <i v-else class="bi bi-shield-fill text-3xl text-emerald-400"></i>
        </div>

        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="font-display text-2xl sm:text-3xl font-black uppercase text-white tracking-wider leading-tight truncate">
              {{ team.name }}
            </h1>
            <span
              v-if="team.status === 'inactive'"
              class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-rose-950/60 border border-rose-800/50 text-rose-300"
            >
              Inactivo
            </span>
          </div>

          <p class="text-xs sm:text-sm text-slate-400 font-medium mt-0.5">
            {{ team.short_name || 'Equipo de la liga' }}
          </p>

          <button
            type="button"
            @click="emit('switchTeam')"
            class="mt-2 text-xs font-semibold text-emerald-400 hover:text-emerald-300 inline-flex items-center gap-1.5 transition-colors cursor-pointer"
          >
            <i class="bi bi-arrow-repeat text-xs"></i>
            <span>Cambiar de equipo</span>
          </button>
        </div>
      </div>

      <!-- Balance & Actions -->
      <div class="flex flex-wrap items-center gap-3 pt-3 md:pt-0 border-t md:border-t-0 border-slate-800/80">
        <!-- Pearls in this team -->
        <div class="flex items-center gap-2 px-3.5 py-2 rounded-2xl bg-slate-950/80 border border-amber-400/40 shadow-inner">
          <div class="text-left">
            <span class="block text-[10px] uppercase font-bold text-slate-400 tracking-wider">
              Tus perlitas en {{ team.short_name || team.name }}
            </span>
            <div class="flex items-center gap-1.5 text-base font-black text-amber-300">
              <PearlIcon size="sm" animated />
              <span>{{ formatPerlitas(team.balance || 0) }}</span>
            </div>
          </div>
        </div>

        <!-- Follow / Unfollow Button -->
        <button
          v-if="team.status === 'active'"
          type="button"
          :disabled="toggling"
          @click="emit('toggleFollow')"
          class="px-4 py-2.5 rounded-2xl text-xs font-bold uppercase tracking-wider transition-all duration-200 inline-flex items-center gap-2 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400"
          :class="[
            team.is_following
              ? 'bg-slate-800/90 hover:bg-rose-950/40 text-slate-300 hover:text-rose-300 border border-slate-700/80 hover:border-rose-800/50'
              : 'bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black shadow-lg shadow-emerald-950/40'
          ]"
        >
          <i
            class="bi"
            :class="[
              toggling
                ? 'bi-arrow-repeat animate-spin'
                : team.is_following
                  ? 'bi-check2'
                  : 'bi-plus-lg'
            ]"
          ></i>
          <span>{{ team.is_following ? 'Siguiendo' : 'Seguir' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
