<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useWallet } from '~/composables/useWallet'
import { useAdsProgress } from '~/composables/useAdsProgress'
import { usePendingGrants } from '~/composables/usePendingGrants'
import WalletSummaryCard from '~/components/wallet/WalletSummaryCard.vue'
import DashboardPendingGrantsCard from '~/components/app/dashboard/DashboardPendingGrantsCard.vue'
import WalletTeamsBreakdown from '~/components/wallet/WalletTeamsBreakdown.vue'
import WalletLedgerList from '~/components/wallet/WalletLedgerList.vue'
import WalletHeldInfoModal from '~/components/wallet/WalletHeldInfoModal.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()

const {
  summary,
  ledgerEntries,
  loading,
  loadingMore,
  hasMore,
  currentFilter,
  selectedTeamId,
  setTeamFilter,
  fetchSummary,
  fetchLedger,
} = useWallet()

const adsProgress = useAdsProgress()
const pendingGrants = usePendingGrants()
const isHeldModalOpen = ref(false)

type WalletTab = 'balances' | 'movimientos' | 'pendientes'
const activeTab = ref<WalletTab>('balances')

// Sincronizar tab activo con query param
watch(
  () => route.query.tab,
  (newTab) => {
    if (newTab === 'movimientos' || newTab === 'historial') {
      activeTab.value = 'movimientos'
    } else if (newTab === 'pendientes' || newTab === 'asignar') {
      activeTab.value = 'pendientes'
    } else {
      activeTab.value = 'balances'
    }
  },
  { immediate: true }
)

const selectTab = (tab: WalletTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const handleFilterChange = (filter: string) => {
  fetchLedger(filter, false)
}

const handleTeamSelect = (teamId: string | null) => {
  setTeamFilter(teamId)
}

const handleLoadMore = () => {
  fetchLedger(currentFilter.value, true)
}

onMounted(async () => {
  await Promise.all([
    fetchSummary(),
    fetchLedger('all', false),
    adsProgress.fetchProgress(),
    pendingGrants.fetchPendingGrants(),
  ])
})

useSeoMeta({
  title: 'Mi Billetera de Puntos — Fan Zone',
  description: 'Consulta tu saldo total de perlitas, desglose por equipo, movimientos e historial de canjes.',
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Billetera de <span class="text-guaiqui-primary">Puntos</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Historial de transacciones y balance inmutable de fidelización por cada equipo.
      </p>
    </div>

    <!-- Unified Total Summary Card (Siempre visible en el tope) -->
    <WalletSummaryCard
      :summary="summary"
      :loading="loading"
      @show-held-info="isHeldModalOpen = true"
    />

    <!-- Subsecciones de la Billetera (Tabs) -->
    <div class="border-b border-guaiqui-border/80 bg-white rounded-t-guaiqui-xl px-2 sm:px-4 shadow-guaiqui-xs">
      <nav class="-mb-px flex space-x-2 sm:space-x-6 overflow-x-auto" aria-label="Subsecciones de la Billetera">
        <!-- Subsección 1: Balances por Equipo -->
        <button
          type="button"
          :class="[
            activeTab === 'balances'
              ? 'border-guaiqui-primary text-guaiqui-primary font-bold'
              : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text hover:border-slate-300 font-medium',
            'whitespace-nowrap py-3.5 px-3 border-b-2 text-xs sm:text-sm flex items-center gap-2 transition-all cursor-pointer'
          ]"
          @click="selectTab('balances')"
        >
          <i class="bi bi-shield-shaded text-base"></i>
          <span>Balances por Equipo</span>
          <span class="text-[11px] px-2 py-0.5 rounded-full bg-slate-100 text-slate-700 font-semibold">
            {{ summary.teams.length }}
          </span>
        </button>

        <!-- Subsección 2: Historial de Movimientos -->
        <button
          type="button"
          :class="[
            activeTab === 'movimientos'
              ? 'border-guaiqui-primary text-guaiqui-primary font-bold'
              : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text hover:border-slate-300 font-medium',
            'whitespace-nowrap py-3.5 px-3 border-b-2 text-xs sm:text-sm flex items-center gap-2 transition-all cursor-pointer'
          ]"
          @click="selectTab('movimientos')"
        >
          <i class="bi bi-clock-history text-base"></i>
          <span>Historial de Movimientos</span>
        </button>

        <!-- Subsección 3: Perlitas por Asignar -->
        <button
          type="button"
          :class="[
            activeTab === 'pendientes'
              ? 'border-guaiqui-primary text-guaiqui-primary font-bold'
              : 'border-transparent text-guaiqui-text-muted hover:text-guaiqui-text hover:border-slate-300 font-medium',
            'whitespace-nowrap py-3.5 px-3 border-b-2 text-xs sm:text-sm flex items-center gap-2 transition-all cursor-pointer'
          ]"
          @click="selectTab('pendientes')"
        >
          <i class="bi bi-hourglass-split text-base"></i>
          <span>Perlitas por Asignar</span>
          <span
            v-if="pendingGrants.totalPendingPearls.value > 0"
            class="text-[11px] px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 font-bold animate-pulse"
          >
            {{ pendingGrants.totalPendingPearls.value }}
          </span>
        </button>
      </nav>
    </div>

    <!-- Contenido dinámico por Subsección -->
    <div class="pt-1">
      <!-- 1. Subsección: Balances por Equipo -->
      <div v-show="activeTab === 'balances'" class="space-y-6">
        <WalletTeamsBreakdown
          :teams="summary.teams"
          :selected-team-id="selectedTeamId"
          :loading="loading"
          @select-team="handleTeamSelect"
        />

        <!-- Banner Sumar Puntos con Anuncios -->
        <div
          v-if="adsProgress.isAdsEnabled.value"
          class="bg-guaiqui-primary-soft border border-guaiqui-primary/20 rounded-guaiqui-lg p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-guaiqui-xs"
        >
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-lg shrink-0">
              <i class="bi bi-play-btn-fill"></i>
            </div>
            <div>
              <h2 class="text-sm font-bold text-guaiqui-text">¿Quieres sumar más puntos a tu saldo?</h2>
              <p class="text-xs text-guaiqui-text-muted">Mira videos de marcas patrocinadoras y gana recompensas directas a tu billetera.</p>
            </div>
          </div>
          <NuxtLink to="/app/anuncios" class="shrink-0 w-full sm:w-auto">
            <button
              type="button"
              class="w-full sm:w-auto px-4 py-2 bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white text-xs font-bold uppercase tracking-wider rounded-guaiqui-md transition-colors flex items-center justify-center gap-1.5 cursor-pointer shadow-guaiqui-xs"
            >
              <span>Ver Videos</span>
            </button>
          </NuxtLink>
        </div>
      </div>

      <!-- 2. Subsección: Historial de Movimientos -->
      <div v-show="activeTab === 'movimientos'">
        <WalletLedgerList
          :entries="ledgerEntries"
          :loading="loading"
          :loading-more="loadingMore"
          :hasMore="hasMore"
          :current-filter="currentFilter"
          @filter-change="handleFilterChange"
          @load-more="handleLoadMore"
        />
      </div>

      <!-- 3. Subsección: Perlitas por Asignar -->
      <div v-show="activeTab === 'pendientes'">
        <DashboardPendingGrantsCard hide-footer-link />
      </div>
    </div>

    <!-- Held Modal -->
    <WalletHeldInfoModal
      :is-open="isHeldModalOpen"
      :held-amount="summary.held_pearls"
      @close="isHeldModalOpen = false"
    />
  </div>
</template>
