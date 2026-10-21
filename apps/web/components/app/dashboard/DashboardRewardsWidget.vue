<script setup lang="ts">
import { ref } from 'vue'
import { BaseCard, PearlAmount } from '@guaiqui/ui'

const rewards = [
  {
    id: 'prod-1',
    name: 'Camiseta Oficial 2026',
    category: 'Indumentaria',
    cost: 4500,
    badge: 'Popular',
    icon: 'bi-bag-check-fill',
    gradient: 'from-emerald-800 to-guaiqui-primary-dark',
  },
  {
    id: 'prod-2',
    name: 'Bandana Verde y Roja',
    category: 'Accesorios',
    cost: 1200,
    badge: 'Oficial',
    icon: 'bi-patch-check-fill',
    gradient: 'from-rose-800 to-amber-900',
  },
  {
    id: 'prod-3',
    name: 'Gorra Oficial de la Tribu',
    category: 'Accesorios',
    cost: 1800,
    badge: 'Destacado',
    icon: 'bi-award-fill',
    gradient: 'from-emerald-950 to-slate-900',
  },
  {
    id: 'prod-4',
    name: 'Balón Autografiado SPB',
    category: 'Colección',
    cost: 8000,
    badge: 'Exclusivo',
    icon: 'bi-star-fill',
    gradient: 'from-amber-700 to-amber-950',
  },
]

const currentIndex = ref(0)

function prevReward() {
  currentIndex.value = (currentIndex.value - 1 + rewards.length) % rewards.length
}

function nextReward() {
  currentIndex.value = (currentIndex.value + 1) % rewards.length
}
</script>

<template>
  <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Encabezado con Enlace -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-lg bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/20 flex items-center justify-center text-base">
          <i class="bi bi-gift-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Premios
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">
            Catálogo Oficial de Fidelidad
          </p>
        </div>
      </div>

      <NuxtLink to="/app/tienda" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-bold inline-flex items-center gap-1 transition-colors">
        <span>Tienda</span>
        <i class="bi bi-arrow-right"></i>
      </NuxtLink>
    </div>

    <!-- Mini-Carrusel Interactivo de Premios -->
    <div class="relative overflow-hidden rounded-guaiqui-lg border border-guaiqui-border bg-guaiqui-surface p-4 space-y-3">
      <!-- Tarjeta del Producto Actual -->
      <div class="flex items-center gap-3">
        <!-- Thumbnail con gradiente temático e icono deportivo -->
        <div
          class="w-14 h-14 rounded-guaiqui-md bg-gradient-to-br text-white flex items-center justify-center text-2xl shadow-sm shrink-0 border border-white/20"
          :class="rewards[currentIndex].gradient"
        >
          <i :class="['bi', rewards[currentIndex].icon]"></i>
        </div>

        <div class="space-y-1 min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-wider bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/20">
              {{ rewards[currentIndex].badge }}
            </span>
            <span class="text-[10px] text-guaiqui-text-muted uppercase font-semibold">
              {{ rewards[currentIndex].category }}
            </span>
          </div>

          <h4 class="font-display font-bold text-sm uppercase text-guaiqui-text truncate">
            {{ rewards[currentIndex].name }}
          </h4>

          <div class="flex items-center gap-1">
            <PearlAmount :amount="rewards[currentIndex].cost" size="sm" />
          </div>
        </div>
      </div>

      <!-- Controles del Mini-Carrusel y Botón Canjear -->
      <div class="flex items-center justify-between pt-2 border-t border-guaiqui-border/60">
        <!-- Indicadores de posición de puntos -->
        <div class="flex items-center gap-1.5">
          <button
            v-for="(_, idx) in rewards"
            :key="idx"
            @click="currentIndex = idx"
            class="w-2 h-2 rounded-full transition-all duration-200"
            :class="idx === currentIndex ? 'w-5 bg-guaiqui-primary' : 'bg-gray-300 hover:bg-gray-400'"
            :aria-label="`Ver premio ${idx + 1}`"
          ></button>
        </div>

        <!-- Flechas de navegación -->
        <div class="flex items-center gap-1">
          <button
            @click="prevReward"
            class="w-7 h-7 rounded-full bg-white hover:bg-gray-100 border border-guaiqui-border text-guaiqui-text flex items-center justify-center text-xs transition-colors"
            aria-label="Premio anterior"
          >
            <i class="bi bi-chevron-left"></i>
          </button>
          <button
            @click="nextReward"
            class="w-7 h-7 rounded-full bg-white hover:bg-gray-100 border border-guaiqui-border text-guaiqui-text flex items-center justify-center text-xs transition-colors"
            aria-label="Premio siguiente"
          >
            <i class="bi bi-chevron-right"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Micro-Incentivo a la Conversión -->
    <NuxtLink to="/app/tienda" class="block">
      <button class="w-full py-2.5 rounded-guaiqui-lg bg-guaiqui-surface hover:bg-guaiqui-primary-soft text-guaiqui-primary border border-guaiqui-primary/30 font-display font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all duration-150">
        <i class="bi bi-bag-heart-fill"></i>
        <span>Canjear Premios en la Tienda</span>
      </button>
    </NuxtLink>
  </BaseCard>
</template>
