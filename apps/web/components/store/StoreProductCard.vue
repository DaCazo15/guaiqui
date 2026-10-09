<script setup lang="ts">
import { BaseCard, BaseBadge, BaseButton, PearlAmount } from '@guaiqui/ui'
import type { Product } from '~/composables/useCatalog'

const props = defineProps<{
  product: Product
  userBalance: number
}>()

const emit = defineEmits<{
  (e: 'select', product: Product): void
}>()

const getCategoryLabel = (category: string) => {
  switch (category) {
    case 'physical':
      return 'Indumentaria & Souvenirs'
    case 'experience':
      return 'Experiencias VIP'
    case 'raffle':
      return 'Sorteo Exclusivo'
    default:
      return category
  }
}

const getCategoryIcon = (category: string) => {
  switch (category) {
    case 'physical':
      return 'bi-bag-check-fill'
    case 'experience':
      return 'bi-star-fill'
    case 'raffle':
      return 'bi-ticket-detailed-fill'
    default:
      return 'bi-gift-fill'
  }
}

const getGradient = (category: string) => {
  switch (category) {
    case 'experience':
      return 'from-amber-600 via-amber-700 to-amber-950'
    case 'raffle':
      return 'from-purple-700 via-purple-800 to-indigo-950'
    default:
      return 'from-emerald-700 via-green-800 to-emerald-950'
  }
}

const isAffordable = computed(() => props.userBalance >= props.product.cost_pearls)
const isOutOfStock = computed(() => props.product.stock <= 0)
const isRaffle = computed(() => props.product.category === 'raffle')
</script>

<template>
  <BaseCard
    variant="interactive"
    padding="md"
    class="flex flex-col justify-between h-full group"
    @click="emit('select', product)"
  >
    <template #image>
      <div :class="['w-full h-44 bg-gradient-to-br flex items-center justify-center p-4 relative overflow-hidden', getGradient(product.category)]">
        <!-- Glow decorativo -->
        <div class="absolute -right-6 -bottom-6 w-28 h-28 rounded-full bg-white/10 blur-xl pointer-events-none"></div>

        <!-- Badges superiores -->
        <BaseBadge variant="perlita" size="sm" class="absolute top-3 left-3 shadow-xs z-10">
          {{ getCategoryLabel(product.category) }}
        </BaseBadge>

        <span v-if="isRaffle" class="absolute top-3 right-3 z-10">
          <BaseBadge variant="warning" size="sm">Próximamente</BaseBadge>
        </span>
        <span v-else-if="isOutOfStock" class="absolute top-3 right-3 z-10">
          <BaseBadge variant="danger" size="sm">Agotado</BaseBadge>
        </span>
        <span v-else-if="product.stock <= 5" class="absolute top-3 right-3 z-10">
          <BaseBadge variant="accent" size="sm">¡Últimas {{ product.stock }}!</BaseBadge>
        </span>

        <!-- Icono central -->
        <div class="w-16 h-16 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center text-white text-3xl font-bold border border-white/30 shadow-md group-hover:scale-105 transition-transform duration-200">
          <i :class="['bi', getCategoryIcon(product.category)]"></i>
        </div>
      </div>
    </template>

    <div class="space-y-3 pt-2 flex-1 flex flex-col justify-between">
      <div>
        <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase leading-snug group-hover:text-guaiqui-primary transition-colors">
          {{ product.name }}
        </h3>
        <p v-if="product.description" class="text-xs text-guaiqui-text-muted mt-1 line-clamp-2">
          {{ product.description }}
        </p>
        <p class="text-xs text-guaiqui-text-muted mt-2">
          Disponibles: <strong :class="isOutOfStock ? 'text-guaiqui-status-danger' : 'text-guaiqui-text'">
            {{ isOutOfStock ? 'Agotado' : `${product.stock} unidades` }}
          </strong>
        </p>
      </div>

      <div class="flex items-center justify-between pt-3 border-t border-guaiqui-border mt-auto">
        <PearlAmount :amount="product.cost_pearls" size="md" show-label />
        
        <div>
          <span v-if="isRaffle" class="text-xs font-semibold text-guaiqui-text-muted bg-guaiqui-surface px-2.5 py-1 rounded-full">
            Próximamente
          </span>
          <BaseButton
            v-else
            :variant="isAffordable && !isOutOfStock ? 'primary' : 'outline'"
            size="sm"
            :disabled="isOutOfStock"
          >
            {{ isOutOfStock ? 'Agotado' : 'Ver detalle' }}
          </BaseButton>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
