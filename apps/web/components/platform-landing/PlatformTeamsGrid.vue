<script setup lang="ts">
import type { PlatformLandingTeamItem } from '@guaiqui/shared'

defineProps<{
  teams: PlatformLandingTeamItem[]
  loading: boolean
  searchQuery?: string
}>()
</script>

<template>
  <section id="equipos" class="py-14 sm:py-20 bg-[#071318] border-b border-cyan-950/80">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-10">
        <div>
          <span class="text-xs sm:text-sm font-bold uppercase tracking-wider text-orange-400 font-sans">
            Equipos Oficiales
          </span>
          <h2 class="text-2xl sm:text-4xl font-black font-title text-white mt-1">
            Clubes Activos en FanActivo
          </h2>
        </div>
        <p class="text-xs sm:text-sm text-slate-400 max-w-md">
          Selecciona tu franquicia para acceder a su Fan Zone personalizada, responder sus trivias y canjear premios de su tienda.
        </p>
      </div>

      <!-- Loading skeleton -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="i in 3"
          :key="i"
          class="h-64 rounded-2xl bg-[#0c1f26]/60 animate-pulse border border-cyan-950 p-6 flex flex-col justify-between"
        >
          <div class="flex items-center gap-4">
            <div class="w-16 h-16 rounded-xl bg-cyan-950/60"></div>
            <div class="space-y-2 flex-1">
              <div class="h-4 bg-cyan-950/60 rounded w-3/4"></div>
              <div class="h-3 bg-cyan-950/60 rounded w-1/2"></div>
            </div>
          </div>
          <div class="h-10 bg-cyan-950/60 rounded-xl"></div>
        </div>
      </div>

      <!-- Empty search state -->
      <div
        v-else-if="teams.length === 0"
        class="text-center py-16 bg-[#0c1f26]/50 border border-cyan-950 rounded-3xl p-8 max-w-lg mx-auto space-y-4"
      >
        <div class="w-16 h-16 mx-auto rounded-full bg-cyan-950 flex items-center justify-center text-cyan-400 text-2xl">
          <i class="bi bi-search"></i>
        </div>
        <h3 class="text-lg font-bold text-white">No se encontraron equipos</h3>
        <p class="text-xs sm:text-sm text-slate-400">
          No encontramos ningún club activo que coincida con tu búsqueda. Prueba con otro nombre o revisa el catálogo completo.
        </p>
      </div>

      <!-- Teams Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="team in teams"
          :key="team.id"
          class="group relative bg-[#0a1820] border border-cyan-950 hover:border-orange-500/50 rounded-2xl p-6 transition-all duration-300 hover:shadow-xl hover:shadow-orange-950/20 flex flex-col justify-between overflow-hidden"
        >
          <!-- Team Accent Top Bar (keeps team's primary color) -->
          <div
            class="absolute top-0 left-0 right-0 h-1.5 transition-all duration-300 group-hover:h-2"
            :style="{ backgroundColor: team.primary_color || '#F97316' }"
          ></div>

          <div>
            <!-- Header: Logo & Name -->
            <div class="flex items-start gap-4 mb-4 pt-1">
              <div class="w-16 h-16 rounded-2xl bg-[#061217] border border-cyan-950 flex items-center justify-center p-2 shrink-0 group-hover:scale-105 transition-transform">
                <img
                  v-if="team.logo_url"
                  :src="team.logo_url"
                  :alt="team.name"
                  class="w-full h-full object-contain"
                  loading="lazy"
                  width="64"
                  height="64"
                />
                <i v-else class="bi bi-shield text-3xl text-orange-400"></i>
              </div>

              <div class="min-w-0 flex-1">
                <h3 class="text-lg font-bold text-white truncate font-title tracking-tight group-hover:text-orange-300 transition-colors">
                  {{ team.name }}
                </h3>
                <p v-if="team.short_name" class="text-xs text-slate-400 font-sans truncate">
                  {{ team.short_name }}
                </p>
                <div class="inline-flex items-center gap-1.5 text-xs text-cyan-400 font-medium mt-1">
                  <i class="bi bi-people-fill text-[11px]"></i>
                  <span>{{ team.follower_count }} fanáticos</span>
                </div>
              </div>
            </div>

            <!-- Features Highlights -->
            <div class="space-y-1.5 text-xs text-slate-400 border-t border-cyan-950/80 pt-3 mb-5">
              <div class="flex items-center gap-2">
                <i class="bi bi-check2 text-orange-400"></i>
                <span>Trivias y dinámicas oficiales</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="bi bi-check2 text-cyan-400"></i>
                <span>Tienda de canje de perlitas del club</span>
              </div>
            </div>
          </div>

          <!-- Action Button -->
          <NuxtLink
            :to="`/e/${team.slug}`"
            class="inline-flex items-center justify-center gap-2 w-full py-2.5 px-4 rounded-xl text-sm font-bold transition-all bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white shadow-md shadow-orange-950/30"
          >
            <span>Ver Fan Zone</span>
            <i class="bi bi-arrow-right text-xs"></i>
          </NuxtLink>
        </div>
      </div>
    </div>
  </section>
</template>
