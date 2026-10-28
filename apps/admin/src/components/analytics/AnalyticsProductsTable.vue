<script setup lang="ts">
import { BaseButton, BaseTable, BaseBadge } from '@guaiqui/ui'
import type { AnalyticsProductSummary } from '@guaiqui/shared'
import { exportToCsv } from '../../lib/exportCsv'

const props = defineProps<{
  productSummary: AnalyticsProductSummary | null
  loading: boolean
}>()

const topColumns = [
  { key: 'name', label: 'Producto' },
  { key: 'cost_pearls', label: 'Costo', align: 'center' as const },
  { key: 'redemptions_count', label: 'Canjes Realizados', align: 'center' as const },
  { key: 'total_pearls_spent', label: 'Total Perlitas Gastadas', align: 'right' as const }
]

const stockColumns = [
  { key: 'name', label: 'Producto' },
  { key: 'stock', label: 'Stock Restante', align: 'center' as const },
  { key: 'status', label: 'Estado Alerta', align: 'right' as const }
]

type TopProduct = NonNullable<AnalyticsProductSummary['top_products']>[number]
type LowStockAlert = NonNullable<AnalyticsProductSummary['low_stock_alerts']>[number]

const asTop = (r: unknown): TopProduct => r as TopProduct
const asStock = (r: unknown): LowStockAlert => r as LowStockAlert

const downloadProductsCsv = () => {
  if (!props.productSummary) return
  exportToCsv('productos_mas_canjeados', props.productSummary.top_products, {
    name: 'Nombre Producto',
    cost_pearls: 'Costo Perlitas',
    redemptions_count: 'Canjes Totales',
    total_pearls_spent: 'Perlitas Gastadas'
  })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Top Products -->
    <div class="p-6 bg-slate-900 border border-slate-800 rounded-2xl space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-box-seam text-sky-400"></i>
            Demanda de Productos en Catálogo
          </h3>
          <p class="text-xs text-slate-400">Productos más canjeados y volumen acumulado de perlitas por ítem.</p>
        </div>
        <BaseButton variant="secondary" size="sm" @click="downloadProductsCsv">
          <i class="bi bi-download mr-1"></i> CSV
        </BaseButton>
      </div>

      <BaseTable
        :columns="topColumns"
        :data="productSummary?.top_products || []"
        :loading="loading"
        empty-text="Sin datos de productos canjeados"
      >
        <template #cell-name="{ row }">
          <span class="font-semibold text-slate-100">{{ asTop(row).name }}</span>
        </template>
        <template #cell-cost_pearls="{ row }">
          <span class="font-mono tabular-nums text-amber-400 font-bold">{{ asTop(row).cost_pearls }}</span>
        </template>
        <template #cell-redemptions_count="{ row }">
          <span class="font-mono tabular-nums text-slate-300 font-bold">{{ asTop(row).redemptions_count }}</span>
        </template>
        <template #cell-total_pearls_spent="{ row }">
          <span class="font-mono tabular-nums text-rose-400 font-bold">{{ asTop(row).total_pearls_spent.toLocaleString() }}</span>
        </template>
      </BaseTable>
    </div>

    <!-- Low Stock Alerts -->
    <div v-if="productSummary?.low_stock_alerts?.length" class="p-6 bg-amber-950/40 border border-amber-800/60 rounded-2xl space-y-4">
      <div>
        <h3 class="text-lg font-bold text-amber-300 flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill text-amber-400"></i>
          Alertas de Quiebre de Stock (Stock ≤ 3)
        </h3>
        <p class="text-xs text-amber-200/80">Reponer inventario antes del próximo partido local.</p>
      </div>

      <BaseTable
        :columns="stockColumns"
        :data="productSummary.low_stock_alerts"
        :loading="loading"
        empty-text="No hay alertas de stock"
      >
        <template #cell-name="{ row }">
          <span class="font-semibold text-white">{{ asStock(row).name }}</span>
        </template>
        <template #cell-stock="{ row }">
          <span class="font-mono tabular-nums font-bold text-red-400 text-sm">{{ asStock(row).stock }} unidades</span>
        </template>
        <template #cell-status="{ row }">
          <BaseBadge variant="danger">
            {{ asStock(row).stock === 0 ? 'Agotado' : 'Crítico' }}
          </BaseBadge>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
