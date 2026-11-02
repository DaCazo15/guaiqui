<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard, BaseBadge, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import TriviaPlayButton from './TriviaPlayButton.vue'

const triviaStore = useTriviaStore()
const { activeTeam } = useCurrentTeam()

const activeTrivia = computed(() => triviaStore.homeSummary?.active_trivia)

// Estimación de perlitas de recompensa (default 100 si no especifica)
const estimatedReward = computed(() => {
  return (activeTrivia.value as any)?.points || 100
})
</script>

<template>
  <BaseCard class="relative overflow-hidden p-6 rounded-guaiqui-xl bg-white border border-guaiqui-border shadow-guaiqui-sm hover:border-orange-500/40 transition-all duration-300">
    <!-- Ribete superior deportivo con los colores de FanActivo (Naranja, Ámbar y Cian) -->
    <div class="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-orange-500 via-amber-400 to-cyan-500"></div>

    <div v-if="activeTrivia" class="space-y-5">
      <!-- Fila Superior: Badges y Estado -->
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-orange-50 text-orange-700 border border-orange-200/80">
            <i class="bi bi-patch-question-fill text-sm"></i>
            <span>Trivia</span>
          </span>
        </div>

        <!-- Indicador de recompensa en perlitas -->
        <div class="flex items-center gap-1.5 text-xs font-bold bg-amber-50 text-amber-900 border border-amber-200 px-3 py-1 rounded-full shadow-xs">
          <span>Gana hasta:</span>
          <PearlAmount :amount="estimatedReward" size="sm" />
        </div>
      </div>

      <!-- Título y Descripción -->
      <div class="space-y-2">
        <h2 class="font-display font-extrabold text-2xl sm:text-3xl uppercase tracking-tight text-guaiqui-text hover:text-orange-600 transition-colors">
          {{ activeTrivia.title }}
        </h2>
        <p class="text-sm text-guaiqui-text-muted leading-relaxed max-w-2xl">
          {{ activeTrivia.description || 'Pon a prueba tu pasión deportiva' }}
        </p>
      </div>

      <!-- Barra de Acción y Botón Interactivo -->
      <div class="pt-2 flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-t border-guaiqui-border/60">
        <!-- Métricas informativas -->
        <div class="flex items-center gap-4 text-xs text-guaiqui-text-muted">
          <span class="flex items-center gap-1 font-medium">
            <i class="bi bi-clock-history text-orange-500 text-sm"></i>
            Disponible hoy
          </span>
          <span class="flex items-center gap-1 font-medium">
            <i class="bi bi-shield-check text-cyan-600 text-sm"></i>
            Respuestas en servidor
          </span>
        </div>

        <!-- Botón interactivo con micro-interacción -->
        <div class="flex items-center gap-3">
          <!-- Si ya fue jugada -->
          <template v-if="activeTrivia.played">
            <div class="flex items-center gap-3">
              <span class="inline-flex items-center gap-1.5 px-4 py-2 rounded-guaiqui-lg bg-cyan-50 text-cyan-800 border border-cyan-300 font-bold text-xs uppercase tracking-wider">
                <i class="bi bi-check-circle-fill text-cyan-600 text-sm"></i>
                Completada
              </span>
              <NuxtLink :to="activeTeam ? `/app/e/${activeTeam.slug}/trivias` : '/app/trivias'">
                <button class="px-4 py-2 rounded-guaiqui-lg bg-guaiqui-surface hover:bg-slate-200 text-guaiqui-text font-bold text-xs uppercase tracking-wider border border-guaiqui-border transition-colors cursor-pointer">
                  Historial
                </button>
              </NuxtLink>
            </div>
          </template>

          <!-- Si está disponible para jugar -->
          <template v-else>
            <div class="flex items-center gap-2">
              <span class="hidden md:inline text-[11px] font-semibold text-guaiqui-text-subtle uppercase tracking-wider">
                (Mantén presionado para encestar)
              </span>
              <TriviaPlayButton
                :trivia-id="activeTrivia.id"
                :team-slug="activeTeam?.slug"
                label="Jugar Trivia Ahora"
              />
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- Empty State cuando no hay trivia activa -->
    <div v-else class="py-8 text-center space-y-3">
      <div class="w-14 h-14 rounded-full bg-orange-50 flex items-center justify-center text-2xl text-orange-600 mx-auto border border-orange-200 shadow-inner">
        <i class="bi bi-calendar-event"></i>
      </div>
      <div class="space-y-1">
        <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
          Próxima Trivia en Preparación
        </h3>
        <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto">
          Los árbitros están afinando las preguntas. Vuelve en unas horas para sumar más puntos a tu cuenta.
        </p>
      </div>
      <NuxtLink :to="activeTeam ? `/app/e/${activeTeam.slug}/trivias` : '/app/trivias'">
        <button class="mt-2 px-5 py-2.5 rounded-guaiqui-xl bg-orange-50 hover:bg-orange-500 hover:text-white text-orange-700 text-xs font-bold uppercase tracking-wider transition-all duration-200 shadow-xs border border-orange-200 cursor-pointer">
          Explorar Trivias Anteriores
        </button>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
