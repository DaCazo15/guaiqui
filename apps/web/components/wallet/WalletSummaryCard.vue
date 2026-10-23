<script setup lang="ts">
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import type { WalletSummary } from '~/composables/useWallet'

defineProps<{
  summary: WalletSummary
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'show-held-info'): void
}>()
</script>

<template>
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    <!-- Saldo Principal -->
    <BaseCard class="md:col-span-2 p-6 bg-gradient-to-br from-guaiqui-primary-soft/30 via-white to-white border-guaiqui-primary/20 rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between relative overflow-hidden">
      <div class="space-y-2 relative z-10">
        <div class="flex items-center justify-between">
          <span class="text-xs font-bold text-guaiqui-primary uppercase tracking-wider bg-guaiqui-primary-soft px-2.5 py-1 rounded-full">
            Saldo de Puntos
          </span>
          <NuxtLink to="/app/canjes">
            <BaseButton variant="outline" size="sm" class="text-xs font-medium">
              <i class="bi bi-gift mr-1.5 text-guaiqui-primary"></i>
              Mis Canjes
            </BaseButton>
          </NuxtLink>
        </div>

        <div class="pt-2">
          <p class="text-xs text-guaiqui-text-muted">Balance Disponible</p>
          <div class="mt-1 flex items-baseline">
            <PearlAmount :amount="summary.balance" size="xl" show-label animated />
          </div>
        </div>
      </div>

      <div class="mt-4 pt-3 border-t border-guaiqui-border/60 flex items-center justify-between text-xs text-guaiqui-text-muted">
        <span>Fuente de verdad inmutable (Ledger)</span>
        <NuxtLink to="/app/tienda" class="text-guaiqui-primary font-semibold hover:underline inline-flex items-center">
          Ir a la Tienda <i class="bi bi-arrow-right ml-1"></i>
        </NuxtLink>
      </div>
    </BaseCard>

    <!-- Ganadas del Mes -->
    <BaseCard class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between">
      <div class="space-y-2">
        <div class="w-9 h-9 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-lg">
          <i class="bi bi-arrow-up-right-circle-fill"></i>
        </div>
        <p class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text-muted">Ganadas este mes</p>
        <p class="text-2xl font-bold font-display text-guaiqui-primary">
          +{{ summary.earned_month.toLocaleString('es-VE') }}
        </p>
      </div>
      <p class="text-[11px] text-guaiqui-text-muted mt-2">Por trivias y actividades</p>
    </BaseCard>

    <!-- Gastadas del Mes / Retenidas -->
    <BaseCard class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm flex flex-col justify-between">
      <div class="space-y-2">
        <div class="w-9 h-9 rounded-full bg-red-50 text-guaiqui-accent flex items-center justify-center text-lg">
          <i class="bi bi-arrow-down-left-circle-fill"></i>
        </div>
        <p class="text-xs font-semibold uppercase tracking-wider text-guaiqui-text-muted">Canjeadas este mes</p>
        <p class="text-2xl font-bold font-display text-guaiqui-accent">
          -{{ summary.spent_month.toLocaleString('es-VE') }}
        </p>
      </div>

      <div v-if="summary.held_pearls > 0" class="mt-2 pt-2 border-t border-guaiqui-border flex items-center justify-between text-xs">
        <button
          type="button"
          class="text-amber-600 hover:text-amber-700 font-medium inline-flex items-center gap-1 cursor-pointer"
          @click="emit('show-held-info')"
        >
          <i class="bi bi-hourglass-split"></i>
          <span>{{ summary.held_pearls }} en revisión</span>
        </button>
      </div>
      <p v-else class="text-[11px] text-guaiqui-text-muted mt-2">En premios canjeados</p>
    </BaseCard>
  </div>
</template>
