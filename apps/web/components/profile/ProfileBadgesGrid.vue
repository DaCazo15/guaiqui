<script setup lang="ts">
import { BaseCard } from '@guaiqui/ui'
import type { FanBadgeItem } from '~/composables/useFanProfile'

defineProps<{
  badges: FanBadgeItem[]
  unlockedCount: number
}>()
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-sm space-y-5">
    <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center shrink-0 text-xl font-bold">
          <i class="bi bi-award-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide">
            Insignias y Logros
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Reconocimientos oficiales desbloqueados por tu fidelidad.
          </p>
        </div>
      </div>

      <span class="px-3 py-1 bg-guaiqui-primary-soft text-guaiqui-primary font-display font-bold text-xs uppercase tracking-wider rounded-full">
        {{ unlockedCount }} / {{ badges.length }} Desbloqueadas
      </span>
    </div>

    <!-- Grid de Insignias -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="badge in badges"
        :key="badge.id"
        class="p-4 rounded-guaiqui-xl border transition-all duration-200 flex items-start gap-3.5"
        :class="badge.is_unlocked
          ? 'bg-emerald-50/50 border-emerald-200 shadow-xs'
          : 'bg-gray-50/60 border-gray-200 opacity-70 grayscale'"
      >
        <!-- Icono -->
        <div
          class="w-11 h-11 rounded-xl flex items-center justify-center text-xl shrink-0 shadow-xs"
          :class="badge.is_unlocked
            ? 'bg-emerald-500 text-white shadow-emerald-200'
            : 'bg-gray-200 text-gray-500'"
        >
          <i :class="`bi ${badge.icon_name}`" aria-hidden="true"></i>
        </div>

        <!-- Info -->
        <div class="space-y-1 flex-1 min-w-0">
          <div class="flex items-center justify-between gap-1">
            <h3 class="font-display font-bold text-sm text-guaiqui-text truncate">
              {{ badge.name }}
            </h3>
            <span
              v-if="badge.is_unlocked"
              class="text-[10px] font-bold text-emerald-700 bg-emerald-100 px-1.5 py-0.2 rounded"
            >
              Obtenida
            </span>
          </div>

          <p class="text-xs text-guaiqui-text-muted line-clamp-2 leading-relaxed">
            {{ badge.is_unlocked ? badge.description : badge.criteria_summary }}
          </p>

          <p v-if="badge.is_unlocked && badge.awarded_at" class="text-[10px] text-emerald-600 font-medium pt-1">
            Desbloqueada el {{ new Date(badge.awarded_at).toLocaleDateString('es-VE') }}
          </p>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
