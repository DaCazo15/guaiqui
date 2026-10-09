<script setup lang="ts">
import { onMounted } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const authStore = useAuthStore()
const triviaStore = useTriviaStore()

onMounted(async () => {
  await Promise.all([
    authStore.fetchProfile(),
    triviaStore.fetchHomeSummary(),
  ])
})
</script>

<template>
  <div class="space-y-6">
    <!-- Welcome & Balance Banner -->
    <BaseCard class="bg-gradient-to-r from-guaiqui-primary-soft to-white border-guaiqui-primary/30 p-6 rounded-guaiqui-xl relative overflow-hidden shadow-guaiqui-md">
      <div class="space-y-3 max-w-lg">
        <span class="text-xs uppercase tracking-widest text-guaiqui-primary font-bold">
          ¡Bienvenido a la Tribu!
        </span>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text">
          Hola, {{ authStore.profile?.display_name || 'Fanático' }}
        </h1>
        <div class="flex items-center gap-3 pt-1">
          <span class="text-sm text-guaiqui-text-muted font-medium">Tu Saldo:</span>
          <PearlAmount :amount="triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0" size="lg" animated />
        </div>
        <div class="pt-2 flex flex-wrap gap-3">
          <NuxtLink to="/app/trivias">
            <BaseButton variant="primary" size="md">
              <i class="bi bi-patch-question-fill mr-1.5"></i>
              Jugar Trivia del Día
            </BaseButton>
          </NuxtLink>
          <NuxtLink to="/app/tienda">
            <BaseButton variant="outline" size="md">
              <i class="bi bi-bag-heart-fill mr-1.5"></i>
              Tienda de Canje
            </BaseButton>
          </NuxtLink>
        </div>
      </div>
    </BaseCard>

    <!-- Metrics Grid -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <BaseCard class="p-4 bg-white border-guaiqui-border rounded-guaiqui-lg space-y-1 shadow-guaiqui-sm">
        <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-medium">Saldo Total</p>
        <PearlAmount :amount="triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0" size="md" />
      </BaseCard>

      <BaseCard class="p-4 bg-white border-guaiqui-border rounded-guaiqui-lg space-y-1 shadow-guaiqui-sm">
        <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-medium">Racha Diaria</p>
        <p class="text-xl font-bold text-guaiqui-perlita font-display flex items-center gap-1.5">
          <span>{{ triviaStore.homeSummary?.streak?.streak_days || 0 }} días</span>
          <i class="bi bi-fire text-amber-500"></i>
        </p>
      </BaseCard>

      <BaseCard class="p-4 bg-white border-guaiqui-border rounded-guaiqui-lg space-y-1 shadow-guaiqui-sm">
        <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-medium">Mi Posición</p>
        <p class="text-xl font-bold text-guaiqui-primary font-display flex items-center gap-1.5">
          <span>#{{ triviaStore.homeSummary?.my_rank || '-' }}</span>
          <i class="bi bi-trophy-fill text-amber-500 text-base"></i>
        </p>
      </BaseCard>

      <BaseCard class="p-4 bg-white border-guaiqui-border rounded-guaiqui-lg space-y-1 shadow-guaiqui-sm">
        <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-medium">Próximo Partido</p>
        <p class="text-sm font-bold text-guaiqui-text font-display truncate">
          {{ triviaStore.homeSummary?.next_game?.opponent || 'Por anunciar' }}
        </p>
      </BaseCard>
    </div>

    <!-- Active Trivia & Next Game Row -->
    <div class="grid md:grid-cols-2 gap-6">
      <!-- Trivia del Día -->
      <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl space-y-4 shadow-guaiqui-sm">
        <div class="flex items-center justify-between">
          <h2 class="font-display text-lg font-bold text-guaiqui-text uppercase tracking-wide flex items-center gap-2">
            <i class="bi bi-patch-question-fill text-guaiqui-primary"></i>
            <span>Trivia del Día</span>
          </h2>
          <span
            v-if="triviaStore.homeSummary?.active_trivia?.played"
            class="px-2.5 py-1 text-xs rounded-full bg-guaiqui-status-success-soft text-guaiqui-status-success border border-guaiqui-status-success/30 font-semibold flex items-center gap-1"
          >
            <i class="bi bi-check-lg"></i>
            <span>Jugada</span>
          </span>
          <span
            v-else-if="triviaStore.homeSummary?.active_trivia"
            class="px-2.5 py-1 text-xs rounded-full bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/30 font-semibold animate-pulse"
          >
            Disponible
          </span>
        </div>

        <div v-if="triviaStore.homeSummary?.active_trivia" class="space-y-2">
          <h3 class="text-guaiqui-text font-semibold text-base">
            {{ triviaStore.homeSummary.active_trivia.title }}
          </h3>
          <p class="text-sm text-guaiqui-text-muted line-clamp-2">
            {{ triviaStore.homeSummary.active_trivia.description || 'Demuestra tus conocimientos sobre los Guaiqueríes de Margarita y gana perlitas.' }}
          </p>

          <div class="pt-2">
            <NuxtLink
              v-if="!triviaStore.homeSummary.active_trivia.played"
              :to="`/app/trivias/${triviaStore.homeSummary.active_trivia.id}`"
            >
              <BaseButton variant="primary" block>
                <span>Jugar Ahora</span>
                <i class="bi bi-arrow-right ml-1.5"></i>
              </BaseButton>
            </NuxtLink>
            <NuxtLink v-else to="/app/trivias">
              <BaseButton variant="outline" block>
                Ver Historial de Trivias
              </BaseButton>
            </NuxtLink>
          </div>
        </div>

        <div v-else class="text-center py-6 text-guaiqui-text-muted text-sm flex flex-col items-center gap-2">
          <i class="bi bi-calendar-x text-3xl text-guaiqui-text-subtle"></i>
          <span>No hay trivias activas en este momento. ¡Vuelve pronto!</span>
        </div>
      </BaseCard>

      <!-- Ranking Preview -->
      <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl space-y-4 shadow-guaiqui-sm">
        <div class="flex items-center justify-between">
          <h2 class="font-display text-lg font-bold text-guaiqui-text uppercase tracking-wide flex items-center gap-2">
            <i class="bi bi-trophy-fill text-amber-500"></i>
            <span>Leaderboard Tribu</span>
          </h2>
          <NuxtLink to="/app/ranking" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark underline font-medium inline-flex items-center gap-1">
            <span>Ver Todo</span>
            <i class="bi bi-arrow-right"></i>
          </NuxtLink>
        </div>

        <p class="text-sm text-guaiqui-text-muted">
          Compite cada mes con la fanaticada y escala posiciones ganando perlitas.
        </p>

        <NuxtLink to="/app/ranking">
          <BaseButton variant="outline" block>
            <i class="bi bi-trophy mr-1.5"></i>
            Explorar Ranking Completo
          </BaseButton>
        </NuxtLink>
      </BaseCard>
    </div>
  </div>
</template>
