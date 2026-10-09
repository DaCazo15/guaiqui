<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseTabs, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const triviaStore = useTriviaStore()
const currentPeriod = ref<'monthly' | 'weekly'>('monthly')

const tabs = [
  { id: 'monthly', label: 'Ranking Mensual' },
  { id: 'weekly', label: 'Ranking Semanal' },
]

onMounted(async () => {
  await triviaStore.fetchLeaderboard(currentPeriod.value)
})

async function handleTabChange(tabId: string) {
  currentPeriod.value = tabId as 'monthly' | 'weekly'
  await triviaStore.fetchLeaderboard(currentPeriod.value)
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Tabla de <span class="text-guaiqui-primary">Posiciones</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Los fanáticos con más perlitas acumuladas demostrando su lealtad por los Guaiqueríes.
      </p>
    </div>

    <!-- Tabs -->
    <BaseTabs :tabs="tabs" :model-value="currentPeriod" @update:model-value="handleTabChange" />

    <!-- Leaderboard Table Card -->
    <BaseCard class="bg-white border-guaiqui-border rounded-guaiqui-xl p-6 space-y-4 shadow-guaiqui-sm">
      <div v-if="triviaStore.isLoading" class="space-y-3">
        <div v-for="i in 5" :key="i" class="h-12 bg-guaiqui-surface rounded-guaiqui-md animate-pulse" />
      </div>

      <div v-else-if="triviaStore.leaderboard.length > 0" class="space-y-2">
        <div
          v-for="item in triviaStore.leaderboard"
          :key="item.user_id"
          class="flex items-center justify-between p-3.5 rounded-guaiqui-lg border transition-all duration-150"
          :class="[
            item.is_current_user
              ? 'bg-guaiqui-primary-soft border-guaiqui-primary shadow-guaiqui-sm'
              : 'bg-guaiqui-surface border-guaiqui-border hover:bg-white',
          ]"
        >
          <!-- Rank & Avatar/Name -->
          <div class="flex items-center gap-3">
            <span
              class="w-8 h-8 rounded-full flex items-center justify-center font-bold font-display text-sm"
              :class="[
                item.rank === 1
                  ? 'bg-amber-500 text-white shadow-md'
                  : item.rank === 2
                  ? 'bg-slate-400 text-white'
                  : item.rank === 3
                  ? 'bg-amber-700 text-white'
                  : 'bg-gray-200 text-guaiqui-text-muted',
              ]"
            >
              {{ item.rank }}
            </span>

            <div class="flex items-center gap-2.5">
              <div class="w-9 h-9 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 flex items-center justify-center font-bold text-xs text-guaiqui-primary overflow-hidden">
                <img v-if="item.avatar_url" :src="item.avatar_url" class="w-full h-full object-cover" alt="Avatar" />
                <span v-else>{{ item.display_name?.slice(0, 2).toUpperCase() || 'FA' }}</span>
              </div>

              <div>
                <p class="text-sm font-bold text-guaiqui-text flex items-center gap-2">
                  {{ item.display_name }}
                  <span v-if="item.is_current_user" class="text-xs font-normal px-2 py-0.5 rounded-full bg-guaiqui-primary text-white font-medium">
                    Tú
                  </span>
                </p>
              </div>
            </div>
          </div>

          <!-- Pearls Earned -->
          <div class="flex items-center gap-1">
            <PearlAmount :amount="item.pearls_earned" size="sm" />
          </div>
        </div>
      </div>

      <div v-else class="text-center py-10 text-guaiqui-text-muted text-sm space-y-2">
        <div class="w-12 h-12 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-2xl mx-auto">
          <i class="bi bi-trophy"></i>
        </div>
        <p>No hay datos registrados en la tabla para este período aún.</p>
      </div>
    </BaseCard>
  </div>
</template>
