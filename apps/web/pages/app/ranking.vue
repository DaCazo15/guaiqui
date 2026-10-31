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
const friendsOnly = ref(false)

const tabs = [
  { id: 'all_time', label: 'Ranking General' },
  { id: 'monthly', label: 'Ranking Mensual' },
  { id: 'weekly', label: 'Ranking Semanal' },
]

onMounted(async () => {
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value, friendsOnly.value)
})

async function handleTabChange(tabId: string) {
  currentPeriod.value = tabId as 'all_time' | 'monthly' | 'weekly'
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value, friendsOnly.value)
}

async function handleTeamSelect(teamId: string | null) {
  selectedTeamId.value = teamId
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value, friendsOnly.value)
}

async function toggleFriendsOnly() {
  friendsOnly.value = !friendsOnly.value
  await triviaStore.fetchLeaderboard(currentPeriod.value, selectedTeamId.value, friendsOnly.value)
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

    <!-- Tabs de Período y Switch Solo Amigos -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <BaseTabs
        :tabs="tabs"
        :model-value="currentPeriod"
        class="flex-1"
        @update:model-value="handleTabChange"
      />

      <button
        type="button"
        class="px-3.5 py-2 rounded-guaiqui-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer shrink-0 border"
        :class="friendsOnly ? 'bg-emerald-600 text-white border-emerald-600 shadow-guaiqui-xs' : 'bg-white text-guaiqui-text border-guaiqui-border hover:bg-slate-50'"
        @click="toggleFriendsOnly"
      >
        <i :class="friendsOnly ? 'bi bi-people-fill' : 'bi bi-people'"></i>
        <span>{{ friendsOnly ? 'Solo Amigos (Activo)' : 'Filtrar por Amigos' }}</span>
      </button>
    </div>

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
        <i :class="friendsOnly ? 'bi bi-people' : 'bi bi-trophy'" aria-hidden="true"></i>
      </div>
      <h2 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        {{ friendsOnly ? 'Sin Amigos en la Tabla' : 'Tabla en Preparación' }}
      </h2>
      <p class="text-sm">
        <span v-if="friendsOnly">
          Ninguno de tus amigos tiene puntos registrados en este período o equipo. ¡Invita o agrega a tus amigos para competir en este ranking!
        </span>
        <span v-else>
          No hay datos registrados en la tabla para este período o equipo aún. ¡Responde trivias oficiales y sé el primero en sumar puntos!
        </span>
      </p>
      <div v-if="friendsOnly" class="pt-2">
        <NuxtLink to="/app/amigos">
          <button
            type="button"
            class="px-4 py-2 bg-guaiqui-primary text-white text-xs font-bold uppercase tracking-wider rounded-guaiqui-md hover:bg-guaiqui-primary-dark transition-colors cursor-pointer"
          >
            Ir a Mis Amigos
          </button>
        </NuxtLink>
      </div>
    </BaseCard>

    <!-- Contenido del Ranking -->
    <div v-else class="space-y-6">
      <LeaderboardPodium :items="triviaStore.leaderboard" />
      <LeaderboardTable :items="restOfLeaderboard" />
    </div>
  </div>
</template>
