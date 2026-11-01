<script setup lang="ts">
import type { TeamLandingActiveTrivia } from '@guaiqui/shared'

defineProps<{
  trivias: TeamLandingActiveTrivia[]
  teamSlug: string
}>()
</script>

<template>
  <section class="py-14 sm:py-20 bg-slate-900/50 border-b border-slate-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-10">
        <div>
          <span class="text-xs sm:text-sm font-bold uppercase tracking-wider text-emerald-400 font-sans">
            Desafíos & Conocimiento
          </span>
          <h2 class="text-2xl sm:text-4xl font-black font-title text-white mt-1">
            Trivias Activas de la Franquicia
          </h2>
        </div>
        <p class="text-xs sm:text-sm text-slate-400 max-w-md">
          Participa en las dinámicas oficiales para responder preguntas de historia, jugadores y partidos recientes, y acumula perlitas.
        </p>
      </div>

      <!-- Empty state -->
      <div
        v-if="trivias.length === 0"
        class="text-center py-12 bg-slate-950/60 border border-slate-800 rounded-2xl p-6 max-w-md mx-auto space-y-3"
      >
        <div class="w-12 h-12 mx-auto rounded-full bg-slate-800 flex items-center justify-center text-slate-400 text-xl">
          <i class="bi bi-clock-history"></i>
        </div>
        <h3 class="text-base font-bold text-white">No hay trivias activas en este momento</h3>
        <p class="text-xs text-slate-400">
          El equipo publicará nuevos desafíos muy pronto. ¡Mantente atento a los días de partido!
        </p>
      </div>

      <!-- Trivias Grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="trivia in trivias"
          :key="trivia.id"
          class="bg-slate-950/80 border border-slate-800 hover:border-emerald-500/40 rounded-2xl p-6 transition-all duration-300 flex flex-col justify-between group"
        >
          <div>
            <div class="flex items-center justify-between gap-2 mb-3">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-400 text-xs font-bold uppercase tracking-wider">
                <i class="bi bi-tag-fill text-[10px]"></i>
                {{ trivia.category || 'Trivia Club' }}
              </span>
              <span class="text-xs font-bold text-amber-400 flex items-center gap-1">
                <i class="bi bi-gem"></i>
                +{{ trivia.reward_pearls }} perlitas
              </span>
            </div>

            <h3 class="text-lg font-bold text-white group-hover:text-emerald-300 transition-colors font-title mb-2">
              {{ trivia.title }}
            </h3>

            <p v-if="trivia.description" class="text-xs sm:text-sm text-slate-400 line-clamp-2 font-sans mb-4">
              {{ trivia.description }}
            </p>
          </div>

          <!-- Play CTA button -->
          <NuxtLink
            :to="`/app/trivias/${trivia.id}`"
            class="inline-flex items-center justify-center gap-2 w-full py-2.5 px-4 rounded-xl text-xs sm:text-sm font-bold transition-all bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-950/30"
          >
            <span>Responder Trivia</span>
            <i class="bi bi-play-fill text-base"></i>
          </NuxtLink>
        </div>
      </div>
    </div>
  </section>
</template>
