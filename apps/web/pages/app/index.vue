<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'

// Subcomponentes modulares del Dashboard
import DashboardCompactHeader from '~/components/app/dashboard/DashboardCompactHeader.vue'
import DashboardStreakXpWidget from '~/components/app/dashboard/DashboardStreakXpWidget.vue'
import DashboardVideoPromo from '~/components/app/dashboard/DashboardVideoPromo.vue'

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
  <div class="space-y-6 max-w-4xl mx-auto">
    <!-- 1. Header Compacto de Bienvenida con Rango de Usuario -->
    <DashboardCompactHeader />

    <!-- 2. Racha de 7 Días & Barra de Progreso XP / Nivel de Fidelidad -->
    <DashboardStreakXpWidget />

    <!-- 3. Banner de Videos Publicitarios con Recompensa en Puntos -->
    <DashboardVideoPromo />
  </div>
</template>
