<script setup lang="ts">
import { onMounted } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { formatCaracas } from '@guaiqui/shared'
import { useTriviaStore } from '~/stores/trivias'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const triviaStore = useTriviaStore()

onMounted(async () => {
  await triviaStore.fetchTrivias()
})

function getStatusBadge(trivia: any) {
  if (trivia.is_won) {
    return { label: 'Ganada', class: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30' }
  }

  const now = new Date().getTime()
  const start = new Date(trivia.starts_at).getTime()
  const end = new Date(trivia.ends_at).getTime()

  if (trivia.status !== 'published') {
    return { label: 'Borrador', class: 'bg-gray-500/10 text-gray-400 border-gray-500/30' }
  }

  if (now < start) {
    return { label: 'Próxima', class: 'bg-blue-500/10 text-blue-400 border-blue-500/30' }
  }

  if (now > end) {
    return { label: 'Cerrada', class: 'bg-red-500/10 text-red-400 border-red-500/30' }
  }

  return { label: 'Disponible', class: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' }
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between">
      <div class="space-y-1">
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Trivias <span class="text-guaiqui-primary">Guaiqueríes</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Demuestra tu pasión baloncestística y gana perlitas para canjear en la tienda oficial.
        </p>
      </div>
    </div>

    <!-- Trivia Cards List -->
    <div v-if="triviaStore.isLoading" class="space-y-4">
      <BaseCard v-for="i in 3" :key="i" class="p-6 bg-guaiqui-surface border-guaiqui-border animate-pulse h-32" />
    </div>

    <div v-else-if="triviaStore.activeTrivias.length > 0" class="grid gap-4">
      <BaseCard
        v-for="t in triviaStore.activeTrivias"
        :key="t.id"
        class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl hover:border-guaiqui-primary transition-all duration-200 shadow-guaiqui-sm"
      >
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div class="space-y-2">
            <div class="flex items-center gap-3">
              <h2 class="font-display text-xl font-bold text-guaiqui-text">
                {{ t.title }}
              </h2>
              <span
                class="px-2.5 py-0.5 text-xs rounded-full border font-medium"
                :class="getStatusBadge(t).class"
              >
                {{ getStatusBadge(t).label }}
              </span>
            </div>

            <p class="text-sm text-guaiqui-text-muted">
              {{ t.description || 'Pone a prueba tus conocimientos sobre la historia y plantilla del equipo.' }}
            </p>

            <div class="flex flex-wrap items-center gap-4 text-xs text-guaiqui-text-muted pt-1">
              <span class="flex items-center gap-1">
                <i class="bi bi-calendar-event text-guaiqui-primary"></i>
                Inicio: {{ formatCaracas(t.starts_at) }}
              </span>
              <span class="flex items-center gap-1">
                <i class="bi bi-stopwatch text-guaiqui-primary"></i>
                Tiempo: {{ t.time_limit_seconds }}s
              </span>
              <span class="flex items-center gap-1">
                <i class="bi bi-bullseye text-guaiqui-primary"></i>
                Máx. Intentos: {{ t.max_attempts }}
              </span>
              <span class="flex items-center gap-1">
                Recompensa estimada: <PearlAmount :amount="150" size="sm" />
              </span>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <template v-if="t.is_won">
              <BaseButton variant="secondary" size="md" :disabled="true" class="opacity-60 cursor-not-allowed">
                <span>Trivia Ganada</span>
                <i class="bi bi-check-circle-fill ml-1.5 text-emerald-600"></i>
              </BaseButton>
            </template>
            <template v-else>
              <NuxtLink :to="`/app/trivias/${t.id}`">
                <BaseButton variant="primary" size="md">
                  <span>Ver Detalles & Jugar</span>
                  <i class="bi bi-arrow-right ml-1.5"></i>
                </BaseButton>
              </NuxtLink>
            </template>
          </div>
        </div>
      </BaseCard>
    </div>

    <BaseCard v-else class="p-12 text-center bg-white border-guaiqui-border rounded-guaiqui-xl space-y-3 shadow-guaiqui-sm">
      <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
        <i class="bi bi-dribbble"></i>
      </div>
      <h3 class="text-lg font-bold text-guaiqui-text">No hay trivias publicadas</h3>
      <p class="text-sm text-guaiqui-text-muted max-w-sm mx-auto">
        Pronto publicaremos nuevas trivias para que sumes perlitas. ¡Mantente atento a los anuncios!
      </p>
    </BaseCard>
  </div>
</template>
