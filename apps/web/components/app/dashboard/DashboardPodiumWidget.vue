<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import { useAuthStore } from '~/stores/auth'

const triviaStore = useTriviaStore()
const authStore = useAuthStore()

onMounted(async () => {
  if (triviaStore.leaderboard.length === 0) {
    await triviaStore.fetchLeaderboard('monthly')
  }
})

const topFans = computed(() => triviaStore.leaderboard.slice(0, 5))

const myRank = computed(() => {
  if (triviaStore.homeSummary?.my_rank) return triviaStore.homeSummary.my_rank
  const currentUserId = authStore.user?.id
  if (currentUserId && triviaStore.leaderboard.length > 0) {
    const idx = triviaStore.leaderboard.findIndex(
      (item) => item.user_id === currentUserId || item.is_current_user
    )
    if (idx !== -1) return idx + 1
  }
  return null
})

const myBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})
</script>

<template>
  <BaseCard class="p-2.5 flex flex-col gap-2 sm:p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Header -->
    <div class="mb-1 flex items-center justify-between pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2.5">
        <div class="w-9 h-9 rounded-guaiqui-md bg-amber-50 text-amber-500 border border-amber-200 flex items-center justify-center text-base shrink-0">
          <i class="bi bi-trophy-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide leading-tight">
            Ranking
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">Fans del momento</p>
        </div>
      </div>
    </div>

    <!-- Ranking en Formato Lista -->
    <div v-if="topFans.length > 0" class="space-y-2">
      <div
        v-for="(item, idx) in topFans"
        :key="item.user_id || idx"
        class="flex items-center justify-between p-2.5 rounded-guaiqui-lg border transition-all duration-150"
        :class="[
          item.is_current_user
            ? 'bg-guaiqui-primary-soft/50 border-guaiqui-primary/40'
            : 'bg-guaiqui-surface/70 border-guaiqui-border/60 hover:bg-white',
        ]"
      >
        <div class="flex items-center gap-2.5 min-w-0">
          <!-- Rank Badge -->
          <span
            class="w-6 h-6 rounded-full flex items-center justify-center font-bold font-display text-xs shrink-0"
            :class="[
              item.rank === 1
                ? 'bg-amber-500 text-white shadow-xs'
                : item.rank === 2
                ? 'bg-slate-400 text-white'
                : item.rank === 3
                ? 'bg-amber-700 text-white'
                : 'bg-slate-200 text-slate-700',
            ]"
          >
            {{ item.rank }}
          </span>

          <!-- Avatar & Name -->
          <div class="w-7 h-7 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 flex items-center justify-center font-bold text-[10px] text-guaiqui-primary overflow-hidden shrink-0">
            <img
              v-if="item.avatar_url"
              :src="item.avatar_url"
              :alt="item.display_name"
              referrerpolicy="no-referrer"
              class="w-full h-full object-cover"
            />
            <span v-else>{{ item.display_name?.slice(0, 2).toUpperCase() || 'FA' }}</span>
          </div>

          <div class="truncate">
            <p class="text-xs font-bold text-guaiqui-text truncate flex items-center gap-1.5">
              <span>{{ item.display_name }}</span>
              <span v-if="item.is_current_user" class="text-[9px] font-semibold px-1.5 py-0.2 rounded-full bg-guaiqui-primary text-white">
                Tú
              </span>
            </p>
          </div>
        </div>

        <!-- Points -->
        <div class="shrink-0 pl-2">
          <PearlAmount :amount="item.pearls_earned" size="sm" />
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="text-center py-6 text-guaiqui-text-muted text-xs space-y-1.5">
      <i class="bi bi-trophy text-2xl text-slate-400 block"></i>
      <p class="font-medium">Sé el primero en responder trivias y liderar el ranking de puntos.</p>
    </div>

    <!-- Franja Destacada: Tu Posición Actual Calculada -->
    <div class="mt-1 flex items-center justify-between p-3 rounded-guaiqui-lg bg-guaiqui-primary-soft border border-guaiqui-primary/20 text-xs font-semibold">
      <div class="flex items-center gap-2">
        <div class="w-6 h-6 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-[11px] font-bold font-mono shrink-0">
          {{ myRank ? `#${myRank}` : '—' }}
        </div>
        <span class="text-guaiqui-primary-dark font-bold">Tu Posición</span>
      </div>
      <div class="flex items-center gap-1 font-mono text-guaiqui-primary font-bold">
        <span>{{ myBalance }}</span>
        <span class="text-[10px] uppercase font-sans text-guaiqui-text-muted">Puntos</span>
      </div>
    </div>
  </BaseCard>
</template>
