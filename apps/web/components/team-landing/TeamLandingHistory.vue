<script setup lang="ts">
import type { TeamLandingProfile } from '@guaiqui/shared'

defineProps<{
  team: TeamLandingProfile
  milestones: Array<{
    id: string
    year: number
    title: string
    description: string
    image_url?: string | null
  }>
}>()
</script>

<template>
  <section id="historia" class="py-16 sm:py-24 bg-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Section Header -->
      <div class="text-center max-w-3xl mx-auto mb-16">
        <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-gray-100 text-gray-800 mb-3">
          <i class="bi bi-clock-history" aria-hidden="true"></i>
          Legado y Gloria
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-5xl text-gray-900 uppercase tracking-tight">
          La Historia de {{ team.name }}
        </h2>
        <p class="mt-3 text-base sm:text-lg text-gray-600">
          Décadas de pasión, esfuerzo y triunfos que forjaron la identidad insular y nacional.
        </p>
      </div>

      <!-- Timeline of Milestones -->
      <div v-if="milestones.length > 0" class="relative max-w-4xl mx-auto">
        <!-- Center line -->
        <div class="absolute left-4 sm:left-1/2 -ml-px w-0.5 h-full bg-gray-200" aria-hidden="true"></div>

        <div class="space-y-8">
          <div
            v-for="(milestone, idx) in milestones"
            :key="milestone.id"
            class="relative flex flex-col sm:flex-row items-start sm:items-center gap-6"
            :class="idx % 2 === 0 ? 'sm:flex-row-reverse' : ''"
          >
            <!-- Content Card -->
            <div class="w-full sm:w-1/2 pl-12 sm:pl-0 sm:px-8">
              <div class="bg-gray-50 p-6 rounded-2xl border border-gray-200 hover:shadow-md transition-shadow">
                <span class="font-display font-extrabold text-2xl text-guaiqui-primary">
                  {{ milestone.year }}
                </span>
                <h3 class="font-display font-bold text-lg text-gray-900 mt-1">
                  {{ milestone.title }}
                </h3>
                <p class="text-sm text-gray-600 mt-2 leading-relaxed">
                  {{ milestone.description }}
                </p>
              </div>
            </div>

            <!-- Dot Marker -->
            <div class="absolute left-4 sm:left-1/2 -translate-x-1/2 w-8 h-8 rounded-full bg-white border-4 border-guaiqui-primary flex items-center justify-center shadow-md">
              <div class="w-2 h-2 rounded-full bg-guaiqui-primary"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Fallback / Arena Info if no milestones -->
      <div v-else class="max-w-2xl mx-auto bg-gray-50 rounded-2xl p-8 text-center border border-gray-200 space-y-4">
        <div class="w-16 h-16 rounded-full bg-emerald-50 text-emerald-700 flex items-center justify-center mx-auto text-3xl">
          <i class="bi bi-trophy" aria-hidden="true"></i>
        </div>
        <h3 class="font-display font-extrabold text-2xl text-gray-900 uppercase">
          {{ team.championships_summary || 'Tradición del Deporte Nacional' }}
        </h3>
        <p class="text-gray-600 text-sm sm:text-base leading-relaxed">
          {{ team.bio || `${team.name} es un equipo con rica trayectoria en el baloncesto profesional.` }}
        </p>
        <p v-if="team.arena_name" class="text-xs font-semibold text-gray-500 uppercase tracking-wider">
          Sede: {{ team.arena_name }} ({{ team.city }})
        </p>
      </div>
    </div>
  </section>
</template>
