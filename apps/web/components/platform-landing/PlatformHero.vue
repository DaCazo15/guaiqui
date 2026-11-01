<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  totalTeams: number
  totalFans: number
}>()

const emit = defineEmits<{
  (e: 'search', query: string): void
}>()

const searchQuery = ref('')

const onInput = () => {
  emit('search', searchQuery.value)
}

const clearSearch = () => {
  searchQuery.value = ''
  emit('search', '')
}
</script>

<template>
  <section class="relative pt-12 pb-16 md:pt-20 md:pb-24 overflow-hidden bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 text-white border-b border-slate-800">
    <!-- Background glow accents -->
    <div class="absolute inset-0 pointer-events-none">
      <div class="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[300px] bg-emerald-500/10 blur-[120px] rounded-full"></div>
      <div class="absolute -bottom-10 right-10 w-[350px] h-[200px] bg-emerald-600/10 blur-[100px] rounded-full"></div>
    </div>

    <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-8">
      <!-- Badge pill -->
      <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs sm:text-sm font-semibold tracking-wide uppercase shadow-sm">
        <i class="bi bi-shield-check text-base"></i>
        <span>Plataforma Oficial Multi-Equipo • Baloncesto Profesional</span>
      </div>

      <!-- Main Headline -->
      <div class="space-y-4 max-w-3xl mx-auto">
        <h1 class="text-3xl sm:text-5xl lg:text-6xl font-black font-title tracking-tight text-white leading-tight">
          La Pasión de tu Club, <br class="hidden sm:inline" />
          <span class="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 via-teal-300 to-emerald-500">
            Recompensada en Cada Jugada
          </span>
        </h1>
        <p class="text-base sm:text-lg lg:text-xl text-slate-300 max-w-2xl mx-auto font-sans leading-relaxed">
          Elige a tu equipo favorito, responde trivias oficiales, gana perlitas virtuales exclusivas y canjea premios reales sin costo.
        </p>
      </div>

      <!-- Live Search Bar -->
      <div class="max-w-xl mx-auto">
        <div class="relative flex items-center bg-slate-900/90 border border-slate-700/80 rounded-2xl p-2 shadow-2xl focus-within:border-emerald-500 focus-within:ring-2 focus-within:ring-emerald-500/30 transition-all">
          <div class="pl-3 pr-2 text-slate-400">
            <i class="bi bi-search text-lg"></i>
          </div>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Busca tu equipo por nombre (ej. Guaiqueríes, Marinos)..."
            class="w-full bg-transparent text-sm sm:text-base text-white placeholder-slate-400 focus:outline-none py-1.5"
            @input="onInput"
          />
          <button
            v-if="searchQuery"
            type="button"
            class="p-1.5 text-slate-400 hover:text-white transition-colors"
            aria-label="Limpiar búsqueda"
            @click="clearSearch"
          >
            <i class="bi bi-x-circle-fill"></i>
          </button>
        </div>
      </div>

      <!-- Quick Trust Indicators -->
      <div class="flex flex-wrap items-center justify-center gap-6 sm:gap-10 pt-4 text-xs sm:text-sm text-slate-400">
        <div class="flex items-center gap-2">
          <i class="bi bi-patch-check-fill text-emerald-400 text-base"></i>
          <span>100% Gratuito y sin apuestas</span>
        </div>
        <div class="flex items-center gap-2">
          <i class="bi bi-trophy-fill text-emerald-400 text-base"></i>
          <span>Premios oficiales entregados en cancha</span>
        </div>
        <div class="flex items-center gap-2">
          <i class="bi bi-people-fill text-emerald-400 text-base"></i>
          <span>Comunidad oficial de fanáticos</span>
        </div>
      </div>
    </div>
  </section>
</template>
