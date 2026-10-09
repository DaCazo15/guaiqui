<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useWallet } from '~/composables/useWallet'
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
  ])
})

useSeoMeta({
  title: 'Mi Billetera de Perlitas — Guaiqueríes de Margarita',
  description: 'Consulta tu saldo disponible, movimientos de perlitas e historial de canjes.',
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Billetera de <span class="text-guaiqui-primary">Perlitas</span>
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
