<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseBadge, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useRedemptions, type Redemption } from '~/composables/useRedemptions'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const { redemptions, loading, fetchMyRedemptions } = useRedemptions()
const statusFilter = ref<string>('all')

const getStatusConfig = (status: Redemption['status']) => {
  switch (status) {
    case 'pending':
      return {
        label: 'Pendiente de Aprobación',
        variant: 'warning' as const,
        icon: 'bi-hourglass-split',
        textClass: 'text-amber-800',
      }
    case 'approved':
      return {
        label: 'Aprobado — Listo para Retiro',
        variant: 'success' as const,
        icon: 'bi-qr-code-scan',
        textClass: 'text-emerald-800',
      }
    case 'scheduled':
      return {
        label: 'Agendado para Retiro',
        variant: 'info' as const,
        icon: 'bi-calendar-check-fill',
        textClass: 'text-blue-800',
      }
    case 'delivered':
    case 'completed':
      return {
        label: 'Entregado',
        variant: 'primary' as const,
        icon: 'bi-check-circle-fill',
        textClass: 'text-guaiqui-primary',
      }
    case 'cancelled':
      return {
        label: 'Cancelado (Reembolsado)',
        variant: 'neutral' as const,
        icon: 'bi-x-circle',
        textClass: 'text-guaiqui-text-muted',
      }
    case 'rejected':
      return {
        label: 'Rechazado (Reembolsado)',
        variant: 'danger' as const,
        icon: 'bi-slash-circle-fill',
        textClass: 'text-guaiqui-status-danger',
      }
    case 'issue':
      return {
        label: 'Con Incidencia en Revisión',
        variant: 'danger' as const,
        icon: 'bi-exclamation-octagon-fill',
        textClass: 'text-guaiqui-status-danger',
      }
    case 'expired':
      return {
        label: 'Vencido',
        variant: 'neutral' as const,
        icon: 'bi-clock-history',
        textClass: 'text-guaiqui-text-subtle',
      }
    default:
      return {
        label: status,
        variant: 'neutral' as const,
        icon: 'bi-info-circle',
        textClass: 'text-guaiqui-text',
      }
  }
}

const formatDate = (dateStr: string) => {
  try {
    const d = new Date(dateStr)
    return d.toLocaleDateString('es-VE', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return dateStr
  }
}

const filteredRedemptions = computed(() => {
  if (statusFilter.value === 'all') return redemptions.value
  if (statusFilter.value === 'active') {
    return redemptions.value.filter((r) => ['pending', 'approved', 'scheduled'].includes(r.status))
  }
  if (statusFilter.value === 'completed') {
    return redemptions.value.filter((r) => ['delivered', 'completed'].includes(r.status))
  }
  if (statusFilter.value === 'cancelled') {
    return redemptions.value.filter((r) => ['cancelled', 'rejected', 'expired'].includes(r.status))
  }
  return redemptions.value
})

onMounted(async () => {
  await fetchMyRedemptions()
})

useSeoMeta({
  title: 'Mis Canjes — Guaiqueríes de Margarita',
  description: 'Consulta tus premios canjeados, códigos QR y estado de entrega.',
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div class="space-y-1">
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Mis <span class="text-guaiqui-primary">Canjes</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Revisa el estado de tus solicitudes, códigos QR y premios retirados.
        </p>
      </div>

      <NuxtLink to="/app/tienda">
        <BaseButton variant="primary" size="sm">
          <i class="bi bi-shop mr-1.5"></i>
          Ir a la Tienda
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Filtros de Estado -->
    <div class="flex flex-wrap gap-2">
      <button
        v-for="tab in [
          { id: 'all', label: 'Todos' },
          { id: 'active', label: 'Activos / Por Retirar' },
          { id: 'completed', label: 'Entregados' },
          { id: 'cancelled', label: 'Cancelados / Reembolsados' },
        ]"
        :key="tab.id"
        type="button"
        :class="[
          'px-3.5 py-1.5 text-xs font-semibold rounded-guaiqui-md border transition-all cursor-pointer',
          statusFilter === tab.id
            ? 'bg-guaiqui-primary text-white border-guaiqui-primary shadow-xs'
            : 'bg-white text-guaiqui-text-muted border-guaiqui-border hover:text-guaiqui-text',
        ]"
        @click="statusFilter = tab.id"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- Lista de Canjes -->
    <div>
      <!-- Loading State -->
      <div v-if="loading" class="py-16 text-center text-guaiqui-text-muted space-y-3">
        <div class="inline-block animate-spin text-3xl text-guaiqui-primary">
          <i class="bi bi-arrow-repeat"></i>
        </div>
        <p class="text-sm font-medium">Cargando tus canjes...</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="filteredRedemptions.length === 0" class="py-16 text-center space-y-4 max-w-md mx-auto">
        <div class="w-16 h-16 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-3xl mx-auto">
          <i class="bi bi-gift"></i>
        </div>
        <div class="space-y-1">
          <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
            No tienes canjes en esta sección
          </h3>
          <p class="text-xs text-guaiqui-text-muted">
            Acumula perlitas jugando trivias y canjéalas por indumentaria y experiencias exclusivas.
          </p>
        </div>
        <NuxtLink to="/app/tienda">
          <BaseButton variant="primary" size="sm">
            Ver Catálogo de Premios
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Redemptions List Cards -->
      <div v-else class="space-y-4">
        <BaseCard
          v-for="redemption in filteredRedemptions"
          :key="redemption.id"
          class="p-5 bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm hover:border-guaiqui-primary/40 transition-all"
        >
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <!-- Left: Product & Status -->
            <div class="space-y-2">
              <div class="flex items-center gap-2 flex-wrap">
                <span :class="['inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider', getStatusConfig(redemption.status).textClass, 'bg-guaiqui-surface border border-guaiqui-border']">
                  <i :class="['bi', getStatusConfig(redemption.status).icon]"></i>
                  {{ getStatusConfig(redemption.status).label }}
                </span>
                <span v-if="redemption.variant" class="text-xs text-guaiqui-text-muted bg-guaiqui-surface px-2 py-0.5 rounded-guaiqui-sm border border-guaiqui-border">
                  Variante: <strong class="text-guaiqui-text uppercase">{{ redemption.variant }}</strong>
                </span>
              </div>

              <div>
                <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
                  {{ redemption.products?.name || 'Premio de la Tribu' }}
                </h3>
                <p class="text-xs text-guaiqui-text-muted mt-0.5">
                  Solicitado el {{ formatDate(redemption.created_at) }}
                </p>
              </div>
            </div>

            <!-- Right: Cost & Action Button -->
            <div class="flex items-center justify-between sm:justify-end gap-4 shrink-0 pt-3 sm:pt-0 border-t sm:border-t-0 border-guaiqui-border">
              <PearlAmount :amount="redemption.cost_pearls" size="md" />

              <NuxtLink :to="`/app/canjes/${redemption.id}`">
                <BaseButton
                  :variant="['approved', 'scheduled'].includes(redemption.status) ? 'primary' : 'outline'"
                  size="sm"
                >
                  <i v-if="['approved', 'scheduled'].includes(redemption.status)" class="bi bi-qr-code mr-1.5"></i>
                  <span>Ver Detalle & Seguimiento</span>
                  <i class="bi bi-chevron-right ml-1"></i>
                </BaseButton>
              </NuxtLink>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </div>
</template>
