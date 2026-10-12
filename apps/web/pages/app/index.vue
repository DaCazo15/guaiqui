<script setup lang="ts">
import { onMounted } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'
import { useAdsProgress } from '~/composables/useAdsProgress'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const authStore = useAuthStore()
const triviaStore = useTriviaStore()
const adsProgress = useAdsProgress()

onMounted(async () => {
  await Promise.all([
    authStore.fetchProfile(),
    triviaStore.fetchHomeSummary(),
    adsProgress.fetchProgress(),
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
          <NuxtLink v-if="adsProgress.isAdsEnabled.value" to="/app/anuncios">
            <BaseButton variant="outline" size="md">
              <i class="bi bi-play-btn-fill mr-1.5"></i>
              Ver Anuncios
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

      <NuxtLink to="/app/partidos" class="block group">
        <BaseCard class="p-4 bg-white border-guaiqui-border group-hover:border-guaiqui-primary rounded-guaiqui-lg space-y-1 shadow-guaiqui-sm transition-all duration-200">
          <div class="flex items-center justify-between">
            <p class="text-xs text-guaiqui-text-muted uppercase tracking-wider font-medium">Próximo Partido</p>
            <i class="bi bi-chevron-right text-xs text-guaiqui-text-subtle group-hover:text-guaiqui-primary transition-colors"></i>
          </div>
          <p class="text-sm font-bold text-guaiqui-text font-display truncate group-hover:text-guaiqui-primary transition-colors">
            {{ triviaStore.homeSummary?.next_game?.opponent || 'Marinos de Anzoátegui' }}
          </p>
        </BaseCard>
      </NuxtLink>
    </div>

    <!-- Rewarded Ads Promo Card (Asynchronous & Reactive) -->
    <BaseCard
      v-if="adsProgress.isAdsEnabled.value"
      class="bg-gradient-to-r from-emerald-900 to-slate-900 text-white p-5 rounded-guaiqui-xl shadow-guaiqui-md border border-emerald-500/30 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
    >
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-400 text-2xl shrink-0">
          <i class="bi bi-play-btn-fill"></i>
        </div>
        <div>
          <div class="flex items-center gap-2">
            <span class="text-xs uppercase tracking-wider text-emerald-400 font-bold font-mono">¡Gana Perlitas!</span>
            <span v-if="adsProgress.progress.value" class="text-xs text-slate-300">
              ({{ adsProgress.progress.value.completed_today }} / {{ adsProgress.progress.value.daily_limit }} completados hoy)
            </span>
          </div>
          <h3 class="font-display text-lg font-bold uppercase tracking-wide text-white">
            Videos Publicitarios Recompensados
          </h3>
          <p class="text-xs text-slate-300 max-w-xl">
            Apoya al equipo viendo videos publicitarios cortos y acumula perlitas automáticas para canjear en la tienda oficial.
          </p>
        </div>
      </div>
      <NuxtLink to="/app/anuncios" class="shrink-0 w-full sm:w-auto">
        <BaseButton variant="primary" size="md" block>
          <span>Ver Anuncios</span>
          <i class="bi bi-arrow-right ml-1.5"></i>
        </BaseButton>
      </NuxtLink>
    </BaseCard>

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

    <!-- Sofascore Games Quick Widget -->
    <BaseCard class="p-6 bg-white border-guaiqui-border rounded-guaiqui-xl space-y-4 shadow-guaiqui-sm">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <div class="w-9 h-9 rounded-lg bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-lg">
            <i class="bi bi-calendar-event-fill"></i>
          </div>
          <div>
            <h2 class="font-display text-lg font-bold text-guaiqui-text uppercase tracking-wide">
              Gran Final SPB & Calendario
            </h2>
            <p class="text-xs text-guaiqui-text-muted">
              Resultados oficiales sincronizados con Sofascore · Team ID: 248672
            </p>
          </div>
        </div>

        <NuxtLink to="/app/partidos">
          <BaseButton variant="secondary" size="sm">
            <i class="bi bi-calendar-check mr-1.5"></i> Ver Calendario Completo
          </BaseButton>
        </NuxtLink>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 pt-2">
        <!-- Game 4 -->
        <div class="p-3.5 bg-guaiqui-surface rounded-guaiqui-lg border border-guaiqui-border space-y-2">
          <div class="flex items-center justify-between text-[11px] font-semibold text-guaiqui-text-muted">
            <span>Final SPB · Juego 4</span>
            <span class="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold uppercase text-[10px]">Victoria</span>
          </div>
          <div class="flex items-center justify-between font-display font-bold text-sm">
            <span>Guaiqueríes</span>
            <span class="text-guaiqui-primary font-black text-base">81</span>
          </div>
          <div class="flex items-center justify-between font-display font-bold text-sm text-guaiqui-text-muted">
            <span>Marinos</span>
            <span class="font-black text-base">78</span>
          </div>
        </div>

        <!-- Game 3 -->
        <div class="p-3.5 bg-guaiqui-surface rounded-guaiqui-lg border border-guaiqui-border space-y-2">
          <div class="flex items-center justify-between text-[11px] font-semibold text-guaiqui-text-muted">
            <span>Final SPB · Juego 3</span>
            <span class="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold uppercase text-[10px]">Victoria</span>
          </div>
          <div class="flex items-center justify-between font-display font-bold text-sm">
            <span>Guaiqueríes</span>
            <span class="text-guaiqui-primary font-black text-base">75</span>
          </div>
          <div class="flex items-center justify-between font-display font-bold text-sm text-guaiqui-text-muted">
            <span>Marinos</span>
            <span class="font-black text-base">72</span>
          </div>
        </div>

        <!-- Próximo Juego 5 -->
        <div class="p-3.5 bg-gradient-to-br from-emerald-950 to-slate-900 text-white rounded-guaiqui-lg border border-emerald-500/30 space-y-2 flex flex-col justify-between">
          <div class="flex items-center justify-between text-[11px] font-bold text-emerald-400">
            <span>Final SPB · Juego 5</span>
            <span class="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-400/30 uppercase text-[10px]">Programado</span>
          </div>
          <div>
            <p class="font-display font-black text-base uppercase">Guaiqueríes vs Marinos</p>
            <p class="text-[11px] text-slate-300">Gimnasio Luis Ramos · Pto. La Cruz</p>
          </div>
        </div>
      </div>
    </BaseCard>
  </div>
</template>
