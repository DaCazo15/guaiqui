<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseTabs } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import LeaderboardTeamFilter from '~/components/ranking/LeaderboardTeamFilter.vue'
import LeaderboardUserRankCard from '~/components/ranking/LeaderboardUserRankCard.vue'
import LeaderboardPodium from '~/components/ranking/LeaderboardPodium.vue'
import LeaderboardTable from '~/components/ranking/LeaderboardTable.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Tabla de Posiciones — Fan Zone Oficial',
  description: 'Ranking de los fanáticos con más perlitas acumuladas por equipo y a nivel nacional.',
})

const triviaStore = useTriviaStore()
const currentPeriod = ref<'all_time' | 'monthly' | 'weekly'>('all_time')
const selectedTeamId = ref<string | null>(null)

const tabs = [
  { id: 'all_time', label: 'Ranking General' },
  { id: 'monthly', label: 'Ranking Mensual' },
  { id: 'weekly', label: 'Ranking Semanal' },
]

onMounted(async () => {
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value)
})

async function handleTabChange(tabId: string) {
  currentPeriod.value = tabId as 'all_time' | 'monthly' | 'weekly'
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value)
}

async function handleTeamSelect(teamId: string | null) {
  selectedTeamId.value = teamId
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value)
}

const restOfLeaderboard = computed(() => {
  return triviaStore.leaderboard.filter((i) => i.rank > 3)
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Tabla de <span class="text-guaiqui-primary">Posiciones</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Los fanáticos con más puntos acumulados demostrando su lealtad por su equipo en el tabloncillo.
      </p>
    </div>

    <!-- Filtro Multi-Equipo -->
    <LeaderboardTeamFilter
      :selected-team-id="selectedTeamId"
      @select="handleTeamSelect"
    />

    <!-- Tabs de Período -->
    <BaseTabs
      :tabs="tabs"
      :model-value="currentPeriod"
      @update:model-value="handleTabChange"
    />

    <!-- Tarjeta de Posición del Usuario Actual -->
    <LeaderboardUserRankCard
      :my-rank="triviaStore.myRank"
      :team-name="triviaStore.currentLeaderboardTeam?.name"
    />

    <!-- Skeleton de Carga -->
    <div v-if="triviaStore.isLoading" class="space-y-4">
      <div class="h-64 bg-white border border-guaiqui-border rounded-guaiqui-xl animate-pulse p-6"></div>
      <div v-for="i in 4" :key="i" class="h-14 bg-white border border-guaiqui-border rounded-guaiqui-lg animate-pulse"></div>
    </div>

    <!-- Estado Vacío -->
    <BaseCard
      v-else-if="triviaStore.leaderboard.length === 0"
      class="bg-white border-guaiqui-border rounded-guaiqui-xl p-10 text-center text-guaiqui-text-muted space-y-3 shadow-guaiqui-sm max-w-xl mx-auto"
    >
      <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-trophy" aria-hidden="true"></i>
      </div>
      <h2 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        Tabla en Preparación
      </h2>
      <p class="text-sm">
        No hay datos registrados en la tabla para este período o equipo aún. ¡Responde trivias oficiales y sé el primero en sumar puntos!
      </p>
    </BaseCard>

    <!-- Contenido del Ranking -->
    <div v-else class="space-y-6">
      <LeaderboardPodium :items="triviaStore.leaderboard" />
      <LeaderboardTable :items="restOfLeaderboard" />
    </div>
  </div>
</template>
