<script setup lang="ts">
import type { TeamLandingProfile } from '@guaiqui/shared'
import { BaseCard, BaseBadge } from '@guaiqui/ui'

defineProps<{
  team: TeamLandingProfile
  roster: Array<{
    id: string
    first_name: string
    last_name: string
    display_name?: string | null
    jersey_number: number
    position: string
    photo_url?: string | null
    height_cm?: number | null
    is_captain?: boolean
  }>
}>()
</script>

<template>
  <section id="plantilla" class="py-16 sm:py-24 bg-gray-50 border-y border-gray-100">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Section Header -->
      <div class="text-center max-w-3xl mx-auto mb-12">
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-emerald-100 text-emerald-800 mb-3">
          <i class="bi bi-people-fill" aria-hidden="true"></i>
          Plantilla Oficial
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-5xl text-gray-900 uppercase tracking-tight">
          Nuestros Guerreros
        </h2>
        <p class="mt-3 text-base sm:text-lg text-gray-600">
          Los jugadores que defienden la camiseta de {{ team.name }} en el tabloncillo.
        </p>
      </div>

      <!-- Roster Grid -->
      <div v-if="roster.length > 0" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
        <BaseCard
          v-for="player in roster"
          :key="player.id"
          class="group overflow-hidden rounded-2xl border border-gray-200/80 hover:border-guaiqui-primary hover:shadow-lg transition-all duration-300 bg-white flex flex-col"
        >
          <!-- Player Photo / Fallback -->
          <div class="relative aspect-square bg-gray-100 overflow-hidden flex items-center justify-center">
            <img
              v-if="player.photo_url"
              :src="player.photo_url"
              :alt="player.display_name || `${player.first_name} ${player.last_name}`"
              class="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
              loading="lazy"
            />
            <div v-else class="text-gray-300 flex flex-col items-center justify-center">
              <i class="bi bi-person-bounding-box text-5xl" aria-hidden="true"></i>
            </div>

            <!-- Jersey Number Badge -->
            <div class="absolute top-3 left-3 bg-gray-900/90 text-white font-display font-black text-lg px-2.5 py-0.5 rounded-lg shadow-md backdrop-blur-sm">
              #{{ player.jersey_number ?? '--' }}
            </div>

            <!-- Captain Badge -->
            <div v-if="player.is_captain" class="absolute top-3 right-3 bg-yellow-500 text-gray-950 font-bold text-xs px-2 py-0.5 rounded-md shadow-sm">
              Capitán
            </div>
          </div>

          <!-- Player Info -->
          <div class="p-4 flex-1 flex flex-col justify-between">
            <div>
              <p class="text-xs uppercase font-semibold text-emerald-700 tracking-wider">
                {{ player.position || 'Jugador' }}
              </p>
              <h3 class="font-display font-bold text-lg text-gray-900 leading-snug group-hover:text-guaiqui-primary transition-colors">
                {{ player.display_name || `${player.first_name} ${player.last_name}` }}
              </h3>
            </div>
            <div v-if="player.height_cm" class="mt-2 pt-2 border-t border-gray-100 text-xs text-gray-500 flex justify-between">
              <span>Altura</span>
              <span class="font-medium text-gray-700">{{ player.height_cm }} cm</span>
            </div>
          </div>
        </BaseCard>
      </div>

      <!-- Empty State -->
      <div v-else class="text-center py-12 px-4 bg-white rounded-2xl border border-gray-200 max-w-xl mx-auto space-y-3">
        <div class="w-14 h-14 rounded-full bg-gray-100 text-gray-400 flex items-center justify-center mx-auto text-2xl">
          <i class="bi bi-shield-slash" aria-hidden="true"></i>
        </div>
        <h3 class="font-bold text-gray-800 text-lg">Plantilla en actualización</h3>
        <p class="text-sm text-gray-500">
          La lista de jugadores activos de {{ team.name }} se publicará al abrirse la temporada oficial.
        </p>
      </div>
    </div>
  </section>
</template>
