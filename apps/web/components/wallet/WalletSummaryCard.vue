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
  <div>
    <!-- ================= VISTA MÓVIL (SOLO TELÉFONO < md) ================= -->
    <div class="block md:hidden space-y-3">
      <!-- Tarjeta compacta con 3 columnas de estadísticas -->
      <BaseCard class="p-3.5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm">
        <div class="grid grid-cols-3 divide-x divide-guaiqui-border/60 text-center">
          <!-- Columna 1: Saldo Disponible -->
          <div class="px-1 flex flex-col items-center justify-center">
            <span class="text-[10px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">
              Disponible
            </span>
            <div class="my-1 flex items-center justify-center">
              <PearlAmount :amount="summary.balance" size="md" animated />
            </div>
            <span class="text-[9px] font-bold text-guaiqui-primary uppercase tracking-widest block">
              PUNTOS
            </span>
          </div>

          <!-- Columna 2: Ganadas este mes -->
          <div class="px-1 flex flex-col items-center justify-center">
            <span class="text-[10px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">
              Ganadas
            </span>
            <span class="font-display font-black text-base sm:text-lg text-guaiqui-primary my-1 leading-tight block">
              +{{ summary.earned_month.toLocaleString('es-VE') }}
            </span>
            <span class="text-[9px] text-guaiqui-text-subtle font-medium block">
              Este mes
            </span>
          </div>

          <!-- Columna 3: Canjeadas este mes -->
          <div class="px-1 flex flex-col items-center justify-center">
            <span class="text-[10px] font-bold text-guaiqui-text-muted uppercase tracking-wider block">
              Canjeadas
            </span>
            <span class="font-display font-black text-base sm:text-lg text-guaiqui-accent my-1 leading-tight block">
              -{{ summary.spent_month.toLocaleString('es-VE') }}
            </span>
            <button
              v-if="summary.held_pearls > 0"
              type="button"
              class="text-[9px] font-bold text-amber-600 hover:underline inline-flex items-center gap-0.5 cursor-pointer"
              @click="emit('show-held-info')"
            >
              <i class="bi bi-hourglass-split"></i>
              <span>{{ summary.held_pearls }} rev.</span>
            </button>
            <span v-else class="text-[9px] text-guaiqui-text-subtle font-medium block">
              Este mes
            </span>
          </div>
        </div>

        <!-- Fuente de verdad inmutable (Ledger) -->
        <div class="mt-2.5 pt-2 border-t border-guaiqui-border/60 flex items-center justify-center gap-1.5 text-[10px] text-guaiqui-text-subtle">
          <i class="bi bi-shield-check text-guaiqui-primary text-xs"></i>
          <span>Fuente de verdad inmutable (Ledger)</span>
        </div>
      </BaseCard>

      <!-- Botones de Acción directos para teléfono -->
      <div class="grid grid-cols-2 gap-2.5">
        <NuxtLink to="/app/tienda" class="w-full">
          <button
            type="button"
            class="w-full py-2.5 px-3 rounded-guaiqui-lg bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-1.5 shadow-guaiqui-xs transition-colors cursor-pointer"
          >
            <i class="bi bi-shop text-sm"></i>
            <span>Ir a la Tienda</span>
          </button>
        </NuxtLink>

        <NuxtLink to="/app/canjes" class="w-full">
          <button
            type="button"
            class="w-full py-2.5 px-3 rounded-guaiqui-lg bg-white hover:bg-emerald-50/50 text-guaiqui-primary border border-guaiqui-primary/30 font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-1.5 shadow-guaiqui-xs transition-colors cursor-pointer"
          >
            <i class="bi bi-gift-fill text-sm text-guaiqui-primary"></i>
            <span>Mis Canjes</span>
          </button>
        </NuxtLink>
      </div>
    </div>

    <!-- ================= VISTA TABLET Y ESCRITORIO (md en adelante) ================= -->
    <div class="hidden md:grid md:grid-cols-4 gap-4">
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
  </div>
</template>
