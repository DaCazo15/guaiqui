<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from '#imports'
import { BaseCard, BaseBadge, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useCatalog, type Product } from '~/composables/useCatalog'
import { useWallet } from '~/composables/useWallet'
import StoreRedeemModal from '~/components/store/StoreRedeemModal.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const route = useRoute()
const router = useRouter()
const productId = route.params.id as string

const { currentProduct, loading, fetchProductById } = useCatalog()
const { summary, fetchSummary } = useWallet()

const selectedVariant = ref<string>('')
const isRedeemModalOpen = ref(false)

const productVariants = computed(() => {
  if (!currentProduct.value) return []
  const v = currentProduct.value.variants
  if (Array.isArray(v)) return v
  if (typeof v === 'object' && v !== null) return Object.values(v)
  return ['Única']
})

const isAffordable = computed(() => {
  if (!currentProduct.value) return false
  return summary.value.balance >= currentProduct.value.cost_pearls
})

const missingPearls = computed(() => {
  if (!currentProduct.value) return 0
  return Math.max(0, currentProduct.value.cost_pearls - summary.value.balance)
})

const isOutOfStock = computed(() => {
  if (!currentProduct.value) return true
  return currentProduct.value.stock <= 0
})

const getCategoryLabel = (category: string) => {
  switch (category) {
    case 'physical':
      return 'Indumentaria & Souvenirs'
    case 'experience':
      return 'Experiencia VIP'
    case 'raffle':
      return 'Sorteo Exclusivo'
    default:
      return category
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

const handleRedeemed = (redemptionId: string) => {
  isRedeemModalOpen.value = false
  router.push(`/app/canjes/${redemptionId}`)
}

onMounted(async () => {
  await Promise.all([
    fetchProductById(productId),
    fetchSummary(),
  ])
  if (productVariants.value.length > 0) {
    selectedVariant.value = productVariants.value[0]
  }
})

useSeoMeta({
  title: computed(() => currentProduct.value ? `${currentProduct.value.name} — Canje Guaiqueríes` : 'Detalle de Premio'),
})
</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <!-- Breadcrumb / Back Link -->
    <NuxtLink
      to="/app/tienda"
      class="inline-flex items-center text-xs font-semibold text-guaiqui-text-muted hover:text-guaiqui-primary transition-colors"
    >
      <i class="bi bi-arrow-left mr-1.5"></i>
      Volver a la Tienda
    </NuxtLink>

    <!-- Loading State -->
    <div v-if="loading" class="py-20 text-center text-guaiqui-text-muted space-y-3">
      <div class="inline-block animate-spin text-3xl text-guaiqui-primary">
        <i class="bi bi-arrow-repeat"></i>
      </div>
      <p class="text-sm font-medium">Cargando detalles del producto...</p>
    </div>

    <!-- Product Not Found -->
    <div v-else-if="!currentProduct" class="py-20 text-center space-y-4">
      <div class="w-16 h-16 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-exclamation-circle"></i>
      </div>
      <h2 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
        Producto no encontrado
      </h2>
      <NuxtLink to="/app/tienda">
        <BaseButton variant="primary" size="sm">Regresar a la Tienda</BaseButton>
      </NuxtLink>
    </div>

    <!-- Product Detail Layout -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-12 gap-8">
      <!-- Image / Visual Section -->
      <div class="lg:col-span-6">
        <BaseCard class="p-0 overflow-hidden border-guaiqui-border rounded-guaiqui-2xl shadow-guaiqui-md sticky top-6">
          <div :class="['w-full h-80 sm:h-96 bg-gradient-to-br flex items-center justify-center p-8 relative overflow-hidden', getGradient(currentProduct.category)]">
            <div class="absolute -right-12 -bottom-12 w-48 h-48 rounded-full bg-white/10 blur-2xl pointer-events-none"></div>

            <BaseBadge variant="perlita" size="md" class="absolute top-4 left-4 shadow-sm z-10">
              {{ getCategoryLabel(currentProduct.category) }}
            </BaseBadge>

            <span v-if="isOutOfStock" class="absolute top-4 right-4 z-10">
              <BaseBadge variant="danger" size="md">Agotado</BaseBadge>
            </span>
            <span v-else-if="currentProduct.stock <= 5" class="absolute top-4 right-4 z-10">
              <BaseBadge variant="accent" size="md">¡Últimas {{ currentProduct.stock }} disponibles!</BaseBadge>
            </span>

            <div class="w-28 h-28 rounded-3xl bg-white/20 backdrop-blur-md flex items-center justify-center text-white text-5xl font-bold border border-white/30 shadow-xl">
              <i class="bi bi-gift-fill"></i>
            </div>
          </div>
        </BaseCard>
      </div>

      <!-- Information & Action Section -->
      <div class="lg:col-span-6 space-y-6">
        <div class="space-y-2">
          <h1 class="font-display font-bold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight leading-tight">
            {{ currentProduct.name }}
          </h1>
          <p class="text-sm text-guaiqui-text-muted leading-relaxed">
            {{ currentProduct.description || 'Premio oficial disponible para canje de la Tribu Guaiquerí.' }}
          </p>
        </div>

        <!-- Costo & Comparativa de Saldo -->
        <BaseCard class="p-5 bg-guaiqui-surface border-guaiqui-border rounded-guaiqui-xl space-y-4">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase text-guaiqui-text-muted tracking-wider">Costo de Canje</span>
            <PearlAmount :amount="currentProduct.cost_pearls" size="xl" show-label />
          </div>

          <div class="pt-3 border-t border-guaiqui-border/70 space-y-2 text-xs">
            <div class="flex justify-between text-guaiqui-text-muted">
              <span>Tu saldo disponible:</span>
              <strong class="text-guaiqui-text font-semibold">{{ summary.balance.toLocaleString('es-VE') }} perlitas</strong>
            </div>

            <div v-if="!isAffordable" class="flex justify-between text-guaiqui-accent font-semibold">
              <span>Te faltan para canjear:</span>
              <span>{{ missingPearls.toLocaleString('es-VE') }} perlitas</span>
            </div>
            <div v-else class="flex justify-between text-guaiqui-primary font-semibold">
              <span>Saldo restante estimado:</span>
              <span>{{ (summary.balance - currentProduct.cost_pearls).toLocaleString('es-VE') }} perlitas</span>
            </div>
          </div>
        </BaseCard>

        <!-- Selector de Variantes (Tallas) -->
        <div v-if="productVariants.length > 1 || (productVariants.length === 1 && productVariants[0] !== 'Única')" class="space-y-2">
          <label class="text-xs font-bold uppercase tracking-wider text-guaiqui-text block">
            Selecciona Variante / Talla
          </label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="v in productVariants"
              :key="v"
              type="button"
              :class="[
                'px-4 py-2 text-xs font-bold uppercase rounded-guaiqui-md border transition-all cursor-pointer select-none',
                selectedVariant === v
                  ? 'bg-guaiqui-primary text-white border-guaiqui-primary shadow-xs'
                  : 'bg-white text-guaiqui-text border-guaiqui-border hover:border-guaiqui-primary/60',
              ]"
              @click="selectedVariant = v"
            >
              {{ v }}
            </button>
          </div>
        </div>

        <!-- Condiciones de Retiro -->
        <div class="p-4 bg-white border border-guaiqui-border rounded-guaiqui-lg text-xs space-y-1.5 text-guaiqui-text-muted">
          <p class="font-bold text-guaiqui-text flex items-center gap-1.5">
            <i class="bi bi-geo-alt-fill text-guaiqui-primary"></i>
            Retiro Presencial
          </p>
          <p>
            Gimnasio Ciudad de La Asunción, Isla de Margarita. Presenta el código QR generado en la app al momento del retiro.
          </p>
        </div>

        <!-- Botón de Canje Principal -->
        <div class="space-y-3 pt-2">
          <BaseButton
            v-if="!isOutOfStock && isAffordable"
            variant="primary"
            size="lg"
            block
            @click="isRedeemModalOpen = true"
          >
            <i class="bi bi-gift-fill mr-2"></i>
            Canjear Ahora
          </BaseButton>

          <NuxtLink v-else-if="!isAffordable" to="/app/trivias" class="block">
            <BaseButton variant="outline" size="lg" block>
              <i class="bi bi-patch-question-fill mr-2 text-guaiqui-primary"></i>
              Ganar Perlitas en Trivias
            </BaseButton>
          </NuxtLink>

          <BaseButton
            v-else
            variant="secondary"
            size="lg"
            block
            disabled
          >
            Producto Agotado
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Modal de Canje -->
    <StoreRedeemModal
      :is-open="isRedeemModalOpen"
      :product="currentProduct"
      :variant="selectedVariant"
      :user-balance="summary.balance"
      @close="isRedeemModalOpen = false"
      @redeemed="handleRedeemed"
    />
  </div>
</template>
