<script setup lang="ts">
import type { TeamLandingProfile } from '@guaiqui/shared'
import { BaseButton, PearlIcon } from '@guaiqui/ui'

const props = defineProps<{
  team: TeamLandingProfile
}>()

const tagline = computed(() => {
  return props.team.landing_config?.hero_tagline || `La Fan Zone oficial de ${props.team.name}`
})

const ctaText = computed(() => {
  return props.team.landing_config?.hero_cta_text || `Unirme a ${props.team.short_name || 'La Tribu'}`
})
</script>

<template>
  <section id="hero" class="relative overflow-hidden bg-gradient-to-b from-gray-900 via-gray-900 to-gray-950 text-white py-16 lg:py-24">
    <!-- Background Cover & Gradient -->
    <div
      v-if="team.cover_url"
      class="absolute inset-0 bg-cover bg-center opacity-25 mix-blend-luminosity filter blur-xs"
      :style="{ backgroundImage: `url(${team.cover_url})` }"
      aria-hidden="true"
    ></div>
    <div class="absolute inset-0 bg-gradient-to-t from-gray-950 via-gray-900/80 to-transparent"></div>

    <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
        <!-- Text & Action Column -->
        <div class="lg:col-span-8 space-y-6 text-center lg:text-left">
          <!-- Team Badges / Metadata -->
          <div class="flex flex-wrap items-center justify-center lg:justify-start gap-2.5">
            <span
              v-if="team.sport"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-white/10 text-white backdrop-blur-sm border border-white/15"
            >
              <i class="bi bi-trophy-fill text-yellow-400" aria-hidden="true"></i>
              {{ team.sport }}
            </span>
            <span
              v-if="team.city"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-white/10 text-gray-200 backdrop-blur-sm"
            >
              <i class="bi bi-geo-alt-fill text-guaiqui-red" aria-hidden="true"></i>
              {{ team.city }}
            </span>
            <span
              v-if="team.founded_year"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-white/10 text-gray-200 backdrop-blur-sm"
            >
              <i class="bi bi-calendar-event-fill text-gray-300" aria-hidden="true"></i>
              Fundado en {{ team.founded_year }}
            </span>
          </div>

          <!-- Main Title -->
          <h1 class="font-display font-extrabold text-4xl sm:text-6xl lg:text-7xl tracking-tight uppercase leading-none text-white">
            {{ team.name }}
          </h1>

          <!-- Tagline & Bio -->
          <p class="text-xl sm:text-2xl font-medium text-emerald-400">
            {{ tagline }}
          </p>
          <p v-if="team.bio" class="text-base sm:text-lg text-gray-300 max-w-2xl leading-relaxed">
            {{ team.bio }}
          </p>

          <!-- CTAs -->
          <div class="pt-4 flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-4">
            <NuxtLink :to="`/registro?team=${team.slug}`">
              <BaseButton variant="primary" size="lg" class="w-full sm:w-auto px-8 shadow-lg shadow-emerald-900/40">
                <i class="bi bi-fire mr-2" aria-hidden="true"></i>
                {{ ctaText }}
              </BaseButton>
            </NuxtLink>
            <a href="#trivias">
              <BaseButton variant="outline" size="lg" class="w-full sm:w-auto text-white border-white/30 hover:bg-white/10">
                <PearlIcon size="sm" animated class="mr-2" />
                Jugar Trivias y Ganar
              </BaseButton>
            </a>
          </div>

          <!-- Quick Arena / Championships Highlight -->
          <div v-if="team.arena_name || team.championships_summary" class="pt-6 border-t border-white/10 grid grid-cols-1 sm:grid-cols-2 gap-4 text-left">
            <div v-if="team.arena_name" class="flex items-start gap-3">
              <div class="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                <i class="bi bi-building text-emerald-400 text-lg" aria-hidden="true"></i>
              </div>
              <div>
                <p class="text-xs uppercase font-bold text-gray-400 tracking-wider">Sede Oficial</p>
                <p class="text-sm font-semibold text-white">{{ team.arena_name }}</p>
              </div>
            </div>
            <div v-if="team.championships_summary" class="flex items-start gap-3">
              <div class="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                <i class="bi bi-award-fill text-yellow-400 text-lg" aria-hidden="true"></i>
              </div>
              <div>
                <p class="text-xs uppercase font-bold text-gray-400 tracking-wider">Palmarés</p>
                <p class="text-sm font-semibold text-white">{{ team.championships_summary }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Logo Column -->
        <div class="lg:col-span-4 flex items-center justify-center">
          <div class="relative w-56 h-56 sm:w-72 sm:h-72 p-6 rounded-3xl bg-white/5 backdrop-blur-md border border-white/15 flex items-center justify-center shadow-2xl">
            <img
              v-if="team.logo_url"
              :src="team.logo_url"
              :alt="`Escudo oficial de ${team.name}`"
              class="w-full h-full object-contain filter drop-shadow-xl transition-transform hover:scale-105 duration-300"
            />
            <div v-else class="text-7xl font-display font-extrabold text-white">
              {{ team.name.charAt(0) }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
