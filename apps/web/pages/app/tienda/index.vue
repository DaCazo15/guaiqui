<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseButton, PearlAmount } from '@guaiqui/ui'
import { useCatalog } from '~/composables/useCatalog'
import { useWallet } from '~/composables/useWallet'
import { useCurrentTeam } from '~/composables/useCurrentTeam'
import StoreProductCard from '~/components/store/StoreProductCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

const { products, loading, fetchProducts } = useCatalog()
const { summary, fetchSummary } = useWallet()
const { openPicker, fetchFollowedTeams } = useCurrentTeam()

const selectedCategory = ref<string>('all')
const onlyAffordable = ref<boolean>(false)
const searchQuery = ref<string>('')

const categories = [
  { id: 'all', label: 'Todos' },
  { id: 'physical', label: 'Indumentaria & Accesorios' },
  { id: 'experience', label: 'Experiencias' },
  { id: 'raffle', label: 'Sorteos' },
]

const filteredProducts = computed(() => {
  return products.value.filter((p) => {
    // Categoría
    if (selectedCategory.value !== 'all' && p.category !== selectedCategory.value) {
      return false
    }
    // Lo que me alcanza
    if (onlyAffordable.value && p.cost_pearls > summary.value.balance) {
      return false
    }
    // Búsqueda por texto
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase()
      const matchName = p.name.toLowerCase().includes(q)
      const matchDesc = p.description?.toLowerCase().includes(q)
      if (!matchName && !matchDesc) return false
    }
    return true
  })
})

const router = useRouter()
const handleSelectProduct = (product: Product) => {
  if (product.category === 'raffle') return
  router.push(`/app/tienda/${product.id}`)
}

onMounted(async () => {
  const teams = await fetchFollowedTeams()
  if (!teams || teams.length === 0) {
    openPicker('tienda')
    return
  }

  try {
    const storedSlug = typeof window !== 'undefined' ? window.localStorage?.getItem('guaiqui_active_team_slug') : null
    const targetTeam = teams.find(t => t.slug === storedSlug) || teams[0]
    if (targetTeam) {
      await navigateTo(`/app/e/${targetTeam.slug}/tienda`)
      return
    }
  } catch {
    // Non-blocking
  }

  await Promise.all([
    fetchProducts(),
    fetchSummary(),
  ])
})

useSeoMeta({
  title: 'Tienda de Canje — Guaiqueríes de Margarita',
  description: 'Canjea tus puntos por camisas, merchandising oficial y experiencias de la Tribu.',
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="space-y-1">
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Tienda de <span class="text-guaiqui-primary">Canje</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted">
          Canjea tus puntos acumulados por premios oficiales y experiencias exclusivas.
        </p>
      </div>

      <!-- Saldo Badge -->
      <div class="bg-white border border-guaiqui-border rounded-guaiqui-xl px-4 py-2.5 shadow-guaiqui-sm flex items-center gap-3">
        <div class="text-right">
          <span class="text-[11px] text-guaiqui-text-muted font-semibold block uppercase">Tu Saldo</span>
          <PearlAmount :amount="summary.balance" size="md" />
        </div>
        <NuxtLink to="/app/canjes">
          <BaseButton variant="outline" size="sm" class="text-xs">
            <i class="bi bi-clock-history mr-1"></i>
            Mis Canjes
          </BaseButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Filters & Search Bar -->
    <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
      <!-- Category Tabs -->
      <div class="flex flex-wrap gap-1.5 bg-guaiqui-surface p-1 rounded-guaiqui-lg border border-guaiqui-border">
        <button
          v-for="c in categories"
          :key="c.id"
          type="button"
          :class="[
            'px-3.5 py-1.5 text-xs font-semibold rounded-guaiqui-md transition-all cursor-pointer',
            selectedCategory === c.id
              ? 'bg-white text-guaiqui-primary shadow-xs font-bold'
              : 'text-guaiqui-text-muted hover:text-guaiqui-text',
          ]"
          @click="selectedCategory = c.id"
        >
          {{ c.label }}
        </button>
      </div>

      <!-- Toggle "Lo que me alcanza" -->
      <div class="flex items-center gap-2">
        <label class="flex items-center gap-2 text-xs font-semibold text-guaiqui-text cursor-pointer select-none bg-white px-3 py-2 rounded-guaiqui-lg border border-guaiqui-border hover:border-guaiqui-primary/50 transition-colors shadow-xs">
          <input
            v-model="onlyAffordable"
            type="checkbox"
            class="rounded text-guaiqui-primary focus:ring-guaiqui-primary border-guaiqui-border"
          />
          <span>Solo lo que me alcanza</span>
        </label>
      </div>
    </div>

    <!-- Products Grid -->
    <div>
      <!-- Loading State -->
      <div v-if="loading" class="py-16 text-center text-guaiqui-text-muted space-y-3">
        <div class="inline-block animate-spin text-3xl text-guaiqui-primary">
          <i class="bi bi-arrow-repeat"></i>
        </div>
        <p class="text-sm font-medium">Cargando catálogo de premios...</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="filteredProducts.length === 0" class="py-16 text-center space-y-4 max-w-md mx-auto">
        <div class="w-16 h-16 rounded-full bg-guaiqui-surface text-guaiqui-text-subtle flex items-center justify-center text-3xl mx-auto">
          <i class="bi bi-bag-x"></i>
        </div>
        <div class="space-y-1">
          <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
            No se encontraron premios
          </h3>
          <p class="text-xs text-guaiqui-text-muted">
            {{ onlyAffordable ? 'Aún no tienes suficientes puntos para estos premios. ¡Sigue participando en trivias!' : 'Pronto agregaremos más premios a esta categoría.' }}
          </p>
        </div>
        <NuxtLink v-if="onlyAffordable" to="/app/trivias">
          <BaseButton variant="primary" size="sm">
            <i class="bi bi-play-circle-fill mr-1.5"></i>
            Jugar Trivias
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <StoreProductCard
          v-for="product in filteredProducts"
          :key="product.id"
          :product="product"
          :user-balance="summary.balance"
          @select="handleSelectProduct"
        />
      </div>
    </div>
  </div>
</template>
