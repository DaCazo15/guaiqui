<script setup lang="ts">
import { BaseCard } from '@guaiqui/ui'
import type { PublicProfileRanking, PublicProfileLastReward } from '@guaiqui/shared'

defineProps<{
  followersCount: number
  followingCount: number
  ranking?: PublicProfileRanking | null
  redemptionsCount?: number | null
  lastReward?: PublicProfileLastReward | null
  totalPearls?: number | null
}>()

const emit = defineEmits<{
  (e: 'open-followers'): void
  (e: 'open-following'): void
}>()
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3.5">
    <!-- Seguidores -->
    <button
      type="button"
      @click="emit('open-followers')"
      class="text-left group transition-transform active:scale-95 focus:outline-hidden"
    >
      <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs hover:border-guaiqui-primary/50 transition-colors h-full flex flex-col justify-between">
        <div class="flex items-center justify-between text-guaiqui-text-muted mb-2">
          <span class="text-xs font-semibold uppercase tracking-wider">Seguidores</span>
          <i class="bi bi-people-fill text-guaiqui-primary group-hover:scale-110 transition-transform"></i>
        </div>
        <div>
          <span class="font-display font-black text-2xl text-guaiqui-text">{{ followersCount }}</span>
          <p class="text-[11px] text-guaiqui-text-muted mt-0.5">Ver lista</p>
        </div>
      </BaseCard>
    </button>

    <!-- Seguidos -->
    <button
      type="button"
      @click="emit('open-following')"
      class="text-left group transition-transform active:scale-95 focus:outline-hidden"
    >
      <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs hover:border-guaiqui-primary/50 transition-colors h-full flex flex-col justify-between">
        <div class="flex items-center justify-between text-guaiqui-text-muted mb-2">
          <span class="text-xs font-semibold uppercase tracking-wider">Seguidos</span>
          <i class="bi bi-person-check-fill text-guaiqui-primary group-hover:scale-110 transition-transform"></i>
        </div>
        <div>
          <span class="font-display font-black text-2xl text-guaiqui-text">{{ followingCount }}</span>
          <p class="text-[11px] text-guaiqui-text-muted mt-0.5">Ver lista</p>
        </div>
      </BaseCard>
    </button>

    <!-- Ranking Fanático -->
    <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs h-full flex flex-col justify-between">
      <div class="flex items-center justify-between text-guaiqui-text-muted mb-2">
        <span class="text-xs font-semibold uppercase tracking-wider">Ranking</span>
        <i class="bi bi-trophy-fill text-amber-500"></i>
      </div>
      <div>
        <span class="font-display font-black text-2xl text-guaiqui-text">
          {{ ranking ? `#${ranking.rank}` : '—' }}
        </span>
        <p class="text-[11px] text-guaiqui-text-muted mt-0.5">
          {{ ranking ? `${ranking.points} pts acumulados` : 'Sin puntuación' }}
        </p>
      </div>
    </BaseCard>

    <!-- Canjes Realizados -->
    <BaseCard class="bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs h-full flex flex-col justify-between">
      <div class="flex items-center justify-between text-guaiqui-text-muted mb-2">
        <span class="text-xs font-semibold uppercase tracking-wider">Canjes</span>
        <i class="bi bi-gift-fill text-guaiqui-secondary"></i>
      </div>
      <div>
        <span class="font-display font-black text-2xl text-guaiqui-text">
          {{ redemptionsCount !== null && redemptionsCount !== undefined ? redemptionsCount : '0' }}
        </span>
        <p class="text-[11px] text-guaiqui-text-muted mt-0.5">Premios canjeados</p>
      </div>
    </BaseCard>

    <!-- Último Premio Canjeado -->
    <BaseCard class="col-span-2 sm:col-span-1 bg-white border-guaiqui-border p-4 rounded-guaiqui-xl shadow-xs h-full flex flex-col justify-between">
      <div class="flex items-center justify-between text-guaiqui-text-muted mb-2">
        <span class="text-xs font-semibold uppercase tracking-wider">Último Premio</span>
        <i class="bi bi-bag-check-fill text-emerald-600"></i>
      </div>
      <div>
        <span class="font-display font-bold text-sm text-guaiqui-text line-clamp-1">
          {{ lastReward?.product_name || 'Ninguno aún' }}
        </span>
        <p class="text-[11px] text-guaiqui-text-muted mt-0.5">
          {{ lastReward?.redeemed_at ? new Date(lastReward.redeemed_at).toLocaleDateString('es-VE') : 'Explora la tienda' }}
        </p>
      </div>
    </BaseCard>
  </div>
</template>
