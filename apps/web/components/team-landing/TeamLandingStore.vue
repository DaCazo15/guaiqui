<script setup lang="ts">
import { type TeamLandingProfile, formatPerlitas } from '@guaiqui/shared'
import { BaseCard, BaseButton, PearlIcon } from '@guaiqui/ui'

defineProps<{
  team: TeamLandingProfile
  products: Array<{
    id: string
    name: string
    description?: string | null
    category?: string | null
    price_pearls: number
    image_url?: string | null
    stock: number
  }>
}>()
</script>

<template>
  <section id="tienda" class="py-16 sm:py-24 bg-gray-50 border-t border-gray-100">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Section Header -->
      <div class="flex flex-col md:flex-row md:items-end justify-between mb-12 gap-6">
        <div class="max-w-2xl">
          <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-rose-100 text-rose-800 mb-3">
            <i class="bi bi-gift-fill" aria-hidden="true"></i>
            Tienda de Canjes
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-5xl text-gray-900 uppercase tracking-tight">
            Canjea tus Perlitas
          </h2>
          <p class="mt-3 text-base sm:text-lg text-gray-600">
            Premios 100% reales sin dinero en efectivo. Camisetas, gorras y experiencias oficiales de {{ team.name }}.
          </p>
        </div>
        <NuxtLink :to="`/registro?team=${team.slug}`">
          <BaseButton variant="outline" size="md">
            Ver catálogo completo
            <i class="bi bi-arrow-right ml-2" aria-hidden="true"></i>
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Products Grid -->
      <div v-if="products.length > 0" class="grid grid-cols-2 md:grid-cols-4 gap-6">
        <BaseCard
          v-for="product in products"
          :key="product.id"
          class="rounded-2xl border border-gray-200 overflow-hidden bg-white hover:border-guaiqui-primary hover:shadow-lg transition-all duration-300 flex flex-col justify-between"
        >
          <div class="relative aspect-square bg-gray-100 flex items-center justify-center p-4">
            <img
              v-if="product.image_url"
              :src="product.image_url"
              :alt="product.name"
              class="w-full h-full object-contain"
              loading="lazy"
            />
            <div v-else class="text-gray-300 flex items-center justify-center">
              <i class="bi bi-bag-check text-4xl" aria-hidden="true"></i>
            </div>
            <span class="absolute top-2.5 right-2.5 bg-gray-900/80 text-white text-[11px] font-bold px-2 py-0.5 rounded backdrop-blur-xs">
              {{ product.category || 'Oficial' }}
            </span>
          </div>

          <div class="p-4 flex-1 flex flex-col justify-between">
            <div>
              <h3 class="font-display font-bold text-base text-gray-900 line-clamp-2 leading-snug">
                {{ product.name }}
              </h3>
              <p v-if="product.description" class="text-xs text-gray-500 line-clamp-2 mt-1">
                {{ product.description }}
              </p>
            </div>

            <div class="mt-4 pt-3 border-t border-gray-100 flex items-center justify-between">
              <div class="flex items-center gap-1.5 font-bold text-guaiqui-primary text-sm">
                <PearlIcon size="xs" animated />
                <span>{{ formatPerlitas(product.price_pearls) }}</span>
              </div>
              <span class="text-xs text-gray-400">
                {{ product.stock }} disponibles
              </span>
            </div>
          </div>
        </BaseCard>
      </div>

      <!-- Empty State -->
      <div v-else class="text-center py-12 px-4 bg-white rounded-2xl border border-dashed border-gray-200 max-w-xl mx-auto space-y-3">
        <div class="w-14 h-14 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto text-2xl">
          <i class="bi bi-box2-heart" aria-hidden="true"></i>
        </div>
        <h3 class="font-bold text-gray-800 text-lg">Catálogo en preparación</h3>
        <p class="text-sm text-gray-500">
          Nuevos premios oficiales para fanáticos de {{ team.name }} serán activados próximamente.
        </p>
      </div>
    </div>
  </section>
</template>
