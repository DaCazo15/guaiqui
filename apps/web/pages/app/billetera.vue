<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useWallet } from '~/composables/useWallet'
import { useAdsProgress } from '~/composables/useAdsProgress'
import WalletSummaryCard from '~/components/wallet/WalletSummaryCard.vue'
import WalletLedgerList from '~/components/wallet/WalletLedgerList.vue'
import WalletHeldInfoModal from '~/components/wallet/WalletHeldInfoModal.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const {
  summary,
  ledgerEntries,
  loading,
  loadingMore,
  hasMore,
  currentFilter,
  fetchSummary,
  fetchLedger,
} = useWallet()

const adsProgress = useAdsProgress()
const isHeldModalOpen = ref(false)

const handleFilterChange = (filter: string) => {
  fetchLedger(filter, false)
}

const handleLoadMore = () => {
  fetchLedger(currentFilter.value, true)
}

onMounted(async () => {
  await Promise.all([
    fetchSummary(),
    fetchLedger('all', false),
    adsProgress.fetchProgress(),
  ])
})

useSeoMeta({
  title: 'Mi Billetera de Puntos — Guaiqueríes de Margarita',
  description: 'Consulta tu saldo disponible, movimientos de puntos e historial de canjes.',
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Billetera de <span class="text-guaiqui-primary">Puntos</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Historial de transacciones y balance inmutable de fidelización de la Tribu Verde.
      </p>
    </div>

    <!-- Summary Cards -->
    <WalletSummaryCard
      :summary="summary"
      :loading="loading"
      @show-held-info="isHeldModalOpen = true"
    />

    <!-- Banner Sumar Puntos con Anuncios (Asíncrono y Reactivo) -->
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
          <i class="bi bi-arrow-right"></i>
        </button>
      </NuxtLink>
    </div>

    <!-- Ledger List -->
    <WalletLedgerList
      :entries="ledgerEntries"
      :loading="loading"
      :loading-more="loadingMore"
      :hasMore="hasMore"
      :current-filter="currentFilter"
      @filter-change="handleFilterChange"
      @load-more="handleLoadMore"
    />

    <!-- Held Modal -->
    <WalletHeldInfoModal
      :is-open="isHeldModalOpen"
      :held-amount="summary.held_pearls"
      @close="isHeldModalOpen = false"
    />
  </div>
</template>
