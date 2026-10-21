<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'
import { useAdsProgress } from '~/composables/useAdsProgress'

// Subcomponentes modulares del Dashboard
import DashboardCompactHeader from '~/components/app/dashboard/DashboardCompactHeader.vue'
import DashboardTriviaHero from '~/components/app/dashboard/DashboardTriviaHero.vue'
import DashboardScoreboardWidget from '~/components/app/dashboard/DashboardScoreboardWidget.vue'
import DashboardVideoPromo from '~/components/app/dashboard/DashboardVideoPromo.vue'
import DashboardStreakXpWidget from '~/components/app/dashboard/DashboardStreakXpWidget.vue'
import DashboardPodiumWidget from '~/components/app/dashboard/DashboardPodiumWidget.vue'

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
    <!-- 1. Header Compacto de Bienvenida con Rango de Usuario -->
    <DashboardCompactHeader />

    <!-- 2. Grid Responsivo de 2 Columnas (67% Principal / 33% Lateral) -->
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
      <!-- Columna Principal (lg:col-span-8) -->
      <main class="lg:col-span-8 space-y-6 min-w-0">
        <!-- Hero Card de la Trivia del Día -->
        <DashboardTriviaHero />

        <!-- Jerarquía Deportiva: Marcador SPB, Escudos y Cuenta Regresiva -->
        <DashboardScoreboardWidget />

        <!-- Banner de Videos Publicitarios con Recompensa en Puntos -->
        <DashboardVideoPromo />
      </main>

      <!-- Columna Lateral (lg:col-span-4) -->
      <aside class="lg:col-span-4 space-y-6 min-w-0">
        <!-- Racha de 7 Días & Barra de Progreso XP / Nivel de Fidelidad -->
        <DashboardStreakXpWidget />

        <!-- Ranking de Fanáticos en Formato Lista con Posición del Fanático -->
        <DashboardPodiumWidget />
      </aside>
    </div>
  </div>
</template>
