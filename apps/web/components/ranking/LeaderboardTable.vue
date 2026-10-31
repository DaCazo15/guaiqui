<script setup lang="ts">
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import type { LeaderboardItem } from '~/stores/trivias'

defineProps<{
  items: LeaderboardItem[]
}>()
</script>

<template>
  <BaseCard class="bg-white border border-guaiqui-border rounded-guaiqui-xl p-5 sm:p-6 space-y-4 shadow-guaiqui-sm">
    <div class="flex items-center justify-between pb-2 border-b border-guaiqui-border">
      <div class="flex items-center gap-2">
        <i class="bi bi-list-ol text-guaiqui-primary text-lg" aria-hidden="true"></i>
        <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
          Clasificación General (Puestos 4° en adelante)
        </h3>
      </div>
      <span class="text-xs text-guaiqui-text-muted font-medium">
        {{ items.length }} fanáticos
      </span>
    </div>

    <div v-if="items.length > 0" class="space-y-2">
      <div
        v-for="item in items"
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
          <span class="w-8 h-8 rounded-full flex items-center justify-center font-bold font-display text-sm bg-gray-200 text-guaiqui-text-muted">
            {{ item.rank }}
          </span>

          <div class="flex items-center gap-2.5">
            <div class="w-9 h-9 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 flex items-center justify-center font-bold text-xs text-guaiqui-primary overflow-hidden">
              <img
                v-if="item.avatar_url"
                :src="item.avatar_url"
                referrerpolicy="no-referrer"
                class="w-full h-full object-cover"
                :alt="item.display_name"
              />
              <span v-else>{{ item.display_name?.slice(0, 2).toUpperCase() || 'FA' }}</span>
            </div>

            <div>
              <p class="text-sm font-bold text-guaiqui-text flex items-center gap-2">
                {{ item.display_name }}
                <span v-if="item.is_current_user" class="text-xs px-2 py-0.2 rounded-full bg-guaiqui-primary text-white font-medium">
                  Tú
                </span>
                <span v-if="item.tier_name" class="text-[10px] font-semibold text-gray-400 uppercase">
                  • {{ item.tier_name }}
                </span>
              </p>
            </div>
          </div>
        </div>

        <!-- Points Earned -->
        <div class="flex items-center gap-1 font-display font-bold">
          <PearlAmount :amount="item.pearls_earned" size="sm" show-label label="pts" />
        </div>
      </div>
    </div>

    <div v-else class="text-center py-6 text-guaiqui-text-muted text-xs">
      No hay fanáticos adicionales clasificados a partir del 4° puesto en este período.
    </div>
  </BaseCard>
</template>
