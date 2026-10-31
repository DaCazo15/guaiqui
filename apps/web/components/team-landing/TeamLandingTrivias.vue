<script setup lang="ts">
import type { TeamLandingProfile } from '@guaiqui/shared'
import { BaseCard, BaseButton, PearlIcon } from '@guaiqui/ui'

defineProps<{
  team: TeamLandingProfile
  trivias: Array<{
    id: string
    title: string
    description?: string | null
    category?: string | null
    reward_pearls: number
    time_limit_seconds?: number | null
  }>
}>()
</script>

<template>
  <section id="trivias" class="py-16 sm:py-24 bg-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Section Header -->
      <div class="flex flex-col md:flex-row md:items-end justify-between mb-12 gap-6">
        <div class="max-w-2xl">
          <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-yellow-100 text-yellow-800 mb-3">
            <i class="bi bi-question-circle-fill" aria-hidden="true"></i>
            Zona de Retos
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-5xl text-gray-900 uppercase tracking-tight">
            Demuestra tu pasión
          </h2>
          <p class="mt-3 text-base sm:text-lg text-gray-600">
            Responde preguntas oficiales de {{ team.name }}, gana perlitas virtuales y canjéalas por premios reales.
          </p>
        </div>
        <NuxtLink :to="`/registro?team=${team.slug}`">
          <BaseButton variant="outline" size="md">
            Ver todas las trivias
            <i class="bi bi-arrow-right ml-2" aria-hidden="true"></i>
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Trivias Grid -->
      <div v-if="trivias.length > 0" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <BaseCard
          v-for="trivia in trivias"
          :key="trivia.id"
          class="p-6 rounded-2xl border border-gray-200/90 hover:border-guaiqui-primary hover:shadow-lg transition-all duration-300 flex flex-col justify-between"
        >
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold uppercase tracking-wider px-2.5 py-1 rounded-md bg-gray-100 text-gray-700">
                {{ trivia.category || 'Trivia' }}
              </span>
              <div class="flex items-center gap-1.5 text-xs font-bold text-guaiqui-primary">
                <PearlIcon size="xs" animated />
                +{{ trivia.reward_pearls }}
              </div>
            </div>

            <h3 class="font-display font-bold text-lg text-gray-900 line-clamp-2 leading-snug">
              {{ trivia.title }}
            </h3>
            <p v-if="trivia.description" class="text-sm text-gray-500 line-clamp-2">
              {{ trivia.description }}
            </p>
          </div>

          <div class="pt-5 mt-4 border-t border-gray-100 flex items-center justify-between">
            <span v-if="trivia.time_limit_seconds" class="text-xs text-gray-500 flex items-center gap-1">
              <i class="bi bi-stopwatch" aria-hidden="true"></i>
              {{ trivia.time_limit_seconds }}s
            </span>
            <span v-else class="text-xs text-gray-400">Sin límite</span>

            <NuxtLink :to="`/registro?team=${team.slug}&redirect=/app/e/${team.slug}/trivias`">
              <BaseButton variant="primary" size="sm">
                Jugar
                <i class="bi bi-play-fill ml-1" aria-hidden="true"></i>
              </BaseButton>
            </NuxtLink>
          </div>
        </BaseCard>
      </div>

      <!-- Empty State -->
      <div v-else class="text-center py-12 px-4 bg-gray-50 rounded-2xl border border-dashed border-gray-200 max-w-xl mx-auto space-y-3">
        <div class="w-14 h-14 rounded-full bg-yellow-50 text-yellow-600 flex items-center justify-center mx-auto text-2xl">
          <i class="bi bi-patch-question" aria-hidden="true"></i>
        </div>
        <h3 class="font-bold text-gray-800 text-lg">Nuevas trivias muy pronto</h3>
        <p class="text-sm text-gray-500">
          El equipo editorial de {{ team.name }} está preparando nuevos retos para la afición.
        </p>
      </div>
    </div>
  </section>
</template>
