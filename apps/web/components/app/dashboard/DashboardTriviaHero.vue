<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard, BaseBadge, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import TriviaPlayButton from './TriviaPlayButton.vue'

const triviaStore = useTriviaStore()

const activeTrivia = computed(() => triviaStore.homeSummary?.active_trivia)

// Estimación de perlitas de recompensa (default 100 si no especifica)
const estimatedReward = computed(() => {
  return (activeTrivia.value as any)?.points || 100
})
</script>

<template>
  <BaseCard class="relative overflow-hidden p-6 rounded-guaiqui-xl bg-white border border-guaiqui-border shadow-guaiqui-sm hover:border-guaiqui-primary/40 transition-all duration-300">
    <!-- Ribete superior deportivo con los colores Guaiquerí y acento rojo bandana -->
    <div class="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-guaiqui-primary via-emerald-500 to-guaiqui-accent"></div>

    <div v-if="activeTrivia" class="space-y-5">
      <!-- Fila Superior: Badges y Estado -->
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/20">
            <i class="bi bi-patch-question-fill text-sm"></i>
            <span>Trivia Oficial del Día</span>
          </span>
          <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-rose-50 text-guaiqui-accent border border-rose-200">
            <span class="w-1.5 h-1.5 rounded-full bg-guaiqui-accent animate-ping"></span>
            ¡En Juego!
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
        <h2 class="font-display font-extrabold text-2xl sm:text-3xl uppercase tracking-tight text-guaiqui-text hover:text-guaiqui-primary transition-colors">
          {{ activeTrivia.title }}
        </h2>
        <p class="text-sm text-guaiqui-text-muted leading-relaxed max-w-2xl">
          {{ activeTrivia.description || 'Pone a prueba tu pasión por la Tribu Insular, acierta las preguntas y gana perlitas directas para tu billetera.' }}
        </p>
      </div>

      <!-- Barra de Acción y Botón Interactivo -->
      <div class="pt-2 flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-t border-guaiqui-border/60">
        <!-- Métricas informativas -->
        <div class="flex items-center gap-4 text-xs text-guaiqui-text-muted">
          <span class="flex items-center gap-1 font-medium">
            <i class="bi bi-clock-history text-guaiqui-primary text-sm"></i>
            Disponible hoy
          </span>
          <span class="flex items-center gap-1 font-medium">
            <i class="bi bi-shield-check text-emerald-600 text-sm"></i>
            Respuestas en servidor
          </span>
        </div>

        <!-- Botón interactivo con micro-interacción -->
        <div class="flex items-center gap-3">
          <!-- Si ya fue jugada -->
          <template v-if="activeTrivia.played">
            <div class="flex items-center gap-3">
              <span class="inline-flex items-center gap-1.5 px-4 py-2 rounded-guaiqui-lg bg-emerald-50 text-emerald-800 border border-emerald-300 font-bold text-xs uppercase tracking-wider">
                <i class="bi bi-check-circle-fill text-emerald-600 text-sm"></i>
                Completada
              </span>
              <NuxtLink to="/app/trivias">
                <button class="px-4 py-2 rounded-guaiqui-lg bg-guaiqui-surface hover:bg-gray-200 text-guaiqui-text font-bold text-xs uppercase tracking-wider border border-guaiqui-border transition-colors">
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
                label="Jugar Trivia Ahora"
              />
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- Empty State cuando no hay trivia activa -->
    <div v-else class="py-8 text-center space-y-3">
      <div class="w-14 h-14 rounded-full bg-guaiqui-surface flex items-center justify-center text-2xl text-guaiqui-primary mx-auto border border-guaiqui-border shadow-inner">
        <i class="bi bi-calendar-event"></i>
      </div>
      <div class="space-y-1">
        <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase">
          Próxima Trivia en Preparación
        </h3>
        <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto">
          Los árbitros están afinando las preguntas. Vuelve en unas horas para sumar más perlitas a tu cuenta.
        </p>
      </div>
      <NuxtLink to="/app/trivias">
        <button class="mt-2 px-4 py-2 rounded-guaiqui-md bg-guaiqui-primary-soft hover:bg-emerald-100 text-guaiqui-primary text-xs font-bold uppercase tracking-wider transition-colors">
          Explorar Trivias Anteriores
        </button>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
