<script setup lang="ts">
import { computed } from 'vue'
import { BaseBadge } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'

const authStore = useAuthStore()
const triviaStore = useTriviaStore()

// Cálculo del Rango de Fanático según perlitas acumuladas (FanActivo)
const fanLevel = computed(() => {
  const balance = triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
  if (balance >= 7000) return { title: 'Leyenda FanActivo', level: 5, color: 'text-amber-400 bg-amber-500/20 border-amber-400/40' }
  if (balance >= 3500) return { title: 'Capitán Fanático', level: 4, color: 'text-orange-400 bg-orange-500/20 border-orange-400/40' }
  if (balance >= 1500) return { title: 'Fanático Destacado', level: 3, color: 'text-cyan-400 bg-cyan-500/20 border-cyan-400/40' }
  if (balance >= 500) return { title: 'Fanático Activo', level: 2, color: 'text-teal-400 bg-teal-500/20 border-teal-400/40' }
  return { title: 'Novato FanActivo', level: 1, color: 'text-slate-300 bg-slate-700/40 border-slate-600/40' }
})
</script>

<template>
  <div class="relative overflow-hidden rounded-guaiqui-xl bg-gradient-to-r from-[#050e12] via-[#071318] to-[#0a1c22] border border-cyan-900/60 p-5 shadow-guaiqui-md text-white">
    <!-- Resplandor sutil de fondo en cian y naranja FanActivo -->
    <div class="absolute -right-16 -top-16 w-64 h-64 rounded-full bg-orange-500/15 blur-3xl pointer-events-none"></div>
    <div class="absolute -left-10 -bottom-10 w-48 h-48 rounded-full bg-cyan-500/15 blur-2xl pointer-events-none"></div>

    <div class="relative z-10 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <!-- Avatar y Saludo Conciso con Rango -->
      <div class="flex items-center gap-4">
        <!-- Avatar con borde temático y status activo -->
        <div class="relative shrink-0">
          <div class="w-14 h-14 rounded-full bg-[#0c1e24] border-2 border-orange-500/60 p-0.5 shadow-md flex items-center justify-center overflow-hidden">
            <img
              v-if="authStore.profile?.avatar_url"
              :src="authStore.profile.avatar_url"
              :alt="authStore.profile.display_name"
              class="w-full h-full rounded-full object-cover"
              referrerpolicy="no-referrer"
            />
            <span v-else class="font-display font-extrabold text-xl text-orange-400">
              {{ (authStore.profile?.display_name || 'F').charAt(0).toUpperCase() }}
            </span>
          </div>
          <!-- Corona o insignia de nivel -->
          <div class="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-[#071318] border border-cyan-500/60 flex items-center justify-center text-[10px] text-amber-400 font-bold shadow-sm">
            <i class="bi bi-shield-fill-check"></i>
          </div>
        </div>

        <!-- Identidad y Nivel -->
        <div class="space-y-1">
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="px-2.5 py-0.5 rounded-full text-[11px] font-bold font-mono uppercase tracking-wide border shadow-xs"
              :class="fanLevel.color"
            >
              Nivel {{ fanLevel.level }} · {{ fanLevel.title }}
            </span>
          </div>

          <h1 class="font-display font-extrabold text-2xl sm:text-3xl uppercase tracking-tight text-white flex items-center gap-2">
            <span>¡Hola, {{ authStore.profile?.display_name || 'Fanático' }}!</span>
          </h1>
          <p class="text-xs text-slate-300">
            Demuestra tu pasión, suma puntos y canjea recompensas en FanActivo.
          </p>
        </div>
      </div>

      <!-- Accesos Rápidos Compactos -->
      <div class="flex items-center gap-2.5 pt-1 sm:pt-0 shrink-0">
        <NuxtLink to="/app/tienda">
          <button class="inline-flex items-center gap-1.5 px-3 py-2 rounded-guaiqui-md bg-[#0c1e24] hover:bg-cyan-950/60 border border-cyan-800/60 text-xs font-bold text-white transition-all duration-150 shadow-xs cursor-pointer">
            <i class="bi bi-shop text-amber-400"></i>
            <span>Tienda</span>
          </button>
        </NuxtLink>

        <NuxtLink to="/app/ranking">
          <button class="inline-flex items-center gap-1.5 px-3 py-2 rounded-guaiqui-md bg-[#0c1e24] hover:bg-cyan-950/60 border border-cyan-800/60 text-xs font-bold text-white transition-all duration-150 shadow-xs cursor-pointer">
            <i class="bi bi-trophy-fill text-amber-400"></i>
            <span>Ranking</span>
          </button>
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
