<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import { useCatalog, type Product } from '~/composables/useCatalog'
import { featuredRewards } from '~/data/landingData'

const { products, loading, fetchProducts } = useCatalog()

const currentIndex = ref(0)

onMounted(async () => {
  if (products.value.length === 0) {
    await fetchProducts()
  }
})

// Lista unificada dinámica: productos de la DB o recompensas destacadas del club
const items = computed(() => {
  if (products.value && products.value.length > 0) {
    return products.value.map(p => ({
      id: p.id,
      name: p.name,
      category: p.category === 'physical' ? 'Indumentaria' : p.category === 'experience' ? 'Experiencia' : 'Sorteo',
      cost: p.cost_pearls,
      stock: p.stock,
      image: p.images?.[0] || null,
      icon: p.category === 'experience' ? 'bi-camera-video-fill' : p.category === 'raffle' ? 'bi-ticket-perforated-fill' : 'bi-bag-check-fill'
    }))
  }
  return featuredRewards.map(r => ({
    id: r.id,
    name: r.name,
    category: r.category,
    cost: r.perlitasCost,
    stock: r.stock,
    image: null,
    icon: r.icon
  }))
})

const currentItem = computed(() => {
  if (items.value.length === 0) return null
  return items.value[currentIndex.value % items.value.length]
})

function prevReward() {
  if (items.value.length === 0) return
  currentIndex.value = (currentIndex.value - 1 + items.value.length) % items.value.length
}

function nextReward() {
  if (items.value.length === 0) return
  currentIndex.value = (currentIndex.value + 1) % items.value.length
}
</script>

<template>
  <BaseCard class="p-4 sm:p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Encabezado con Enlace -->
    <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2.5">
        <div class="w-9 h-9 rounded-guaiqui-md bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/20 flex items-center justify-center text-base shrink-0">
          <i class="bi bi-gift-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide leading-tight">
            Premios
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">
            Catálogo
          </p>
        </div>
      </div>

      <NuxtLink to="/app/tienda" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-bold inline-flex items-center gap-1 transition-colors">
        <span>Tienda</span>
        <i class="bi bi-arrow-right"></i>
      </NuxtLink>
    </div>

    <!-- Carrusel de Premios Limpio (Sin tarjeta doble) -->
    <div v-if="currentItem" class="rounded-guaiqui-lg border border-guaiqui-border bg-guaiqui-surface p-3.5 space-y-3">
      <!-- Tarjeta del Producto Actual -->
      <div class="flex items-center gap-3">
        <!-- Thumbnail del producto -->
        <div class="w-14 h-14 rounded-guaiqui-md bg-gradient-to-br from-emerald-800 to-guaiqui-primary-dark text-white flex items-center justify-center text-2xl shadow-sm shrink-0 border border-emerald-600/30 overflow-hidden">
          <img
            v-if="currentItem.image"
            :src="currentItem.image"
            :alt="currentItem.name"
            class="w-full h-full object-cover"
            @error="currentItem.image = null"
          />
          <i v-else :class="['bi', currentItem.icon]"></i>
        </div>

        <div class="space-y-1 min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-wider bg-emerald-100 text-emerald-800">
              Oficial
            </span>
            <span class="text-[10px] text-guaiqui-text-muted uppercase font-semibold truncate">
              {{ currentItem.category }}
            </span>
          </div>

          <h4 class="font-display font-bold text-sm uppercase text-guaiqui-text truncate" :title="currentItem.name">
            {{ currentItem.name }}
          </h4>

          <div class="flex items-center gap-2">
            <PearlAmount :amount="currentItem.cost" size="sm" />
            <span class="text-[10px] text-guaiqui-text-subtle font-medium">
              Stock: {{ currentItem.stock }}
            </span>
          </div>
        </div>
      </div>

      <!-- Controles del Carrusel -->
      <div class="flex items-center justify-between pt-2 border-t border-guaiqui-border/60">
        <!-- Indicadores de puntos -->
        <div class="flex items-center gap-1.5">
          <button
            v-for="(_, idx) in items.slice(0, 6)"
            :key="idx"
            @click="currentIndex = idx"
            class="h-1.5 rounded-full transition-all duration-200"
            :class="idx === (currentIndex % items.length) ? 'w-4 bg-guaiqui-primary' : 'w-1.5 bg-gray-300 hover:bg-gray-400'"
            :aria-label="`Ver premio ${idx + 1}`"
          ></button>
        </div>

        <!-- Flechas de navegación -->
        <div class="flex items-center gap-1.5">
          <button
            @click="prevReward"
            class="w-7 h-7 rounded-full bg-white hover:bg-gray-100 border border-guaiqui-border text-guaiqui-text flex items-center justify-center text-xs transition-colors shadow-2xs"
            aria-label="Premio anterior"
          >
            <i class="bi bi-chevron-left"></i>
          </button>
          <button
            @click="nextReward"
            class="w-7 h-7 rounded-full bg-white hover:bg-gray-100 border border-guaiqui-border text-guaiqui-text flex items-center justify-center text-xs transition-colors shadow-2xs"
            aria-label="Premio siguiente"
          >
            <i class="bi bi-chevron-right"></i>
          </button>
        </div>
      </div>
    </div>

  </BaseCard>
</template>
