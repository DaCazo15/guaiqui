<script setup lang="ts">
import type { TeamLandingTeam } from '@guaiqui/shared'

const props = defineProps<{
  team: TeamLandingTeam
  followerCount: number
  isFollowing: boolean
  actionLoading: boolean
  heroTitle?: string
  heroSubtitle?: string
  heroImageUrl?: string | null
}>()

const emit = defineEmits<{
  (e: 'toggleFollow'): void
}>()
</script>

<template>
  <section
    class="relative pt-12 pb-16 md:pt-20 md:pb-24 text-white overflow-hidden border-b border-slate-800"
    :style="{
      background: `linear-gradient(180deg, ${team.primary_color || '#005A36'}22 0%, #020617 100%)`
    }"
  >
    <!-- Background team glow -->
    <div
      class="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[300px] blur-[120px] rounded-full pointer-events-none opacity-25"
      :style="{ backgroundColor: team.primary_color || '#005A36' }"
    ></div>

    <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col lg:flex-row items-center justify-between gap-10">
        <!-- Left: Team Identity & Headlines -->
        <div class="space-y-6 text-center lg:text-left max-w-2xl">
          <!-- Team Header Badge -->
          <div class="inline-flex items-center gap-3 px-4 py-1.5 rounded-full bg-slate-900/90 border border-slate-800 shadow-md">
            <span
              class="w-2.5 h-2.5 rounded-full animate-pulse"
              :style="{ backgroundColor: team.secondary_color || '#E31B23' }"
            ></span>
            <span class="text-xs sm:text-sm font-bold tracking-wide uppercase text-slate-300 font-sans">
              Fan Zone Oficial • {{ team.name }}
            </span>
          </div>

          <!-- Hero Titles -->
          <div class="space-y-3">
            <h1 class="text-3xl sm:text-5xl lg:text-6xl font-black font-title tracking-tight text-white leading-tight">
              {{ heroTitle || `Fan Zone Oficial de ${team.name}` }}
            </h1>
            <p class="text-base sm:text-lg text-slate-300 font-sans leading-relaxed">
              {{ heroSubtitle || `Demuestra tu conocimiento de ${team.name}, acumula perlitas exclusivas y canjea premios reales entregados por el club.` }}
            </p>
          </div>

          <!-- Followers & Actions -->
          <div class="flex flex-wrap items-center justify-center lg:justify-start gap-4 pt-2">
            <!-- Follow Button -->
            <button
              type="button"
              :disabled="actionLoading"
              class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-bold text-sm sm:text-base transition-all duration-200 shadow-lg cursor-pointer"
              :class="[
                isFollowing
                  ? 'bg-slate-800 hover:bg-red-900/40 text-emerald-300 hover:text-red-300 border border-emerald-500/40 hover:border-red-500/40'
                  : 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-950/40'
              ]"
              @click="emit('toggleFollow')"
            >
              <i v-if="actionLoading" class="bi bi-arrow-repeat animate-spin"></i>
              <i v-else-if="isFollowing" class="bi bi-check-circle-fill"></i>
              <i v-else class="bi bi-plus-circle-fill"></i>
              <span>{{ isFollowing ? 'Siguiendo a la Franquicia' : 'Seguir a este Club' }}</span>
            </button>

            <!-- Followers Count Pill -->
            <div class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-900/80 border border-slate-800 text-slate-300 text-sm font-semibold">
              <i class="bi bi-people-fill text-emerald-400"></i>
              <span>{{ followerCount }} Fanáticos Activos</span>
            </div>
          </div>
        </div>

        <!-- Right: Team Emblem / Visual Card -->
        <div class="relative w-full max-w-sm flex items-center justify-center">
          <div class="w-64 h-64 sm:w-72 sm:h-72 rounded-3xl bg-slate-900/90 border border-slate-800/90 shadow-2xl p-8 flex items-center justify-center relative overflow-hidden group">
            <div
              class="absolute inset-0 opacity-10 group-hover:opacity-20 transition-opacity"
              :style="{ backgroundColor: team.primary_color || '#005A36' }"
            ></div>

            <img
              v-if="team.logo_url"
              :src="team.logo_url"
              :alt="`Logo oficial ${team.name}`"
              class="w-full h-full object-contain relative z-10 transition-transform duration-300 group-hover:scale-105"
              loading="lazy"
              width="250"
              height="250"
            />
            <i v-else class="bi bi-shield text-7xl text-emerald-400 relative z-10"></i>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
