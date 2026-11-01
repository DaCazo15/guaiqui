<script setup lang="ts">
import type { TeamLandingFeaturedProduct } from '@guaiqui/shared'

defineProps<{
  products: TeamLandingFeaturedProduct[]
  teamName: string
}>()
</script>

<template>
  <section class="py-14 sm:py-20 bg-slate-900/60 border-b border-slate-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-10">
        <div>
          <span class="text-xs sm:text-sm font-bold uppercase tracking-wider text-emerald-400 font-sans">
            Catálogo Oficial
          </span>
          <h2 class="text-2xl sm:text-4xl font-black font-title text-white mt-1">
            Premios Canjeables de {{ teamName }}
          </h2>
        </div>
        <p class="text-xs sm:text-sm text-slate-400 max-w-md">
          Recompensas exclusivas que puedes obtener acumulando perlitas en las dinámicas oficiales de este club.
        </p>
      </div>

      <!-- Empty state -->
      <div
        v-if="products.length === 0"
        class="text-center py-12 bg-slate-950/60 border border-slate-800 rounded-2xl p-6 max-w-md mx-auto space-y-3"
      >
        <div class="w-12 h-12 mx-auto rounded-full bg-slate-800 flex items-center justify-center text-slate-400 text-xl">
          <i class="bi bi-gift"></i>
        </div>
        <h3 class="text-base font-bold text-white">Nuevos premios próximamente</h3>
        <p class="text-xs text-slate-400">
          La tienda oficial de {{ teamName }} se actualizará con nuevo inventario de indumentaria y accesos.
        </p>
      </div>

      <!-- Products Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="product in products"
          :key="product.id"
          class="bg-slate-950/80 border border-slate-800 hover:border-emerald-500/40 rounded-2xl p-5 transition-all duration-300 flex flex-col justify-between group overflow-hidden"
        >
          <div>
            <!-- Image Container -->
            <div class="relative w-full h-44 rounded-xl bg-slate-900 border border-slate-800 overflow-hidden mb-4 flex items-center justify-center">
              <img
                v-if="product.image_url"
                :src="product.image_url"
                :alt="product.name"
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                loading="lazy"
                width="300"
                height="176"
              />
              <div v-else class="text-slate-600 text-4xl">
                <i class="bi bi-gift"></i>
              </div>

              <!-- Stock Tag -->
              <span class="absolute top-2.5 right-2.5 px-2.5 py-1 rounded-lg bg-slate-900/90 border border-slate-700/80 text-[11px] font-bold text-emerald-400">
                Disponibles: {{ product.stock }}
              </span>
            </div>

            <!-- Product info -->
            <span class="text-[11px] font-bold uppercase tracking-wider text-slate-400">
              {{ product.category === 'experience' ? 'Experiencia VIP' : product.category === 'raffle' ? 'Sorteo Oficial' : 'Producto Físico' }}
            </span>
            <h3 class="text-base font-bold text-white group-hover:text-emerald-300 transition-colors font-title mt-0.5 mb-1.5">
              {{ product.name }}
            </h3>
            <p v-if="product.description" class="text-xs text-slate-400 line-clamp-2 font-sans mb-4">
              {{ product.description }}
            </p>
          </div>

          <!-- Price & CTA -->
          <div class="pt-3 border-t border-slate-900 flex items-center justify-between gap-3">
            <span class="inline-flex items-center gap-1.5 text-sm font-black text-amber-400 font-title">
              <i class="bi bi-gem"></i>
              {{ product.cost_pearls }} perlitas
            </span>

            <NuxtLink
              to="/login"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-900 hover:bg-emerald-600 text-slate-200 hover:text-white border border-slate-700 hover:border-emerald-500 transition-all"
            >
              <span>Canjear</span>
              <i class="bi bi-arrow-right text-[10px]"></i>
            </NuxtLink>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
