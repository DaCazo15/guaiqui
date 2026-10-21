<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import { useAuthStore } from '~/stores/auth'

const triviaStore = useTriviaStore()
const authStore = useAuthStore()

// Cargamos el leaderboard en background
onMounted(async () => {
  if (triviaStore.leaderboard.length === 0) {
    await triviaStore.fetchLeaderboard('monthly')
  }
})

// Obtenemos los 3 primeros lugares o datos mock estructurados si está vacía
const topThree = computed(() => {
  const list = triviaStore.leaderboard
  if (list && list.length >= 3) {
    return [
      list[1], // 2do Lugar (Izquierda)
      list[0], // 1er Lugar (Centro)
      list[2], // 3er Lugar (Derecha)
    ]
  }
  // Fallback representativo para visualización inmediata
  return [
    { rank: 2, display_name: 'Carlos R.', pearls_earned: 4250, is_current_user: false },
    { rank: 1, display_name: 'María G.', pearls_earned: 5800, is_current_user: false },
    { rank: 3, display_name: 'José V.', pearls_earned: 3600, is_current_user: false },
  ]
})

const myRank = computed(() => {
  return triviaStore.homeSummary?.my_rank || 12
})

const myBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})
</script>

<template>
  <BaseCard class="p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Encabezado con Trofeo y Enlace -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-lg bg-amber-50 text-amber-500 border border-amber-200 flex items-center justify-center text-base">
          <i class="bi bi-trophy-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Podio de la Tribu
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">
            Top Fanáticos del Mes
          </p>
        </div>
      </div>

      <NuxtLink to="/app/ranking" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-bold inline-flex items-center gap-1 transition-colors">
        <span>Tabla Completa</span>
        <i class="bi bi-arrow-right"></i>
      </NuxtLink>
    </div>

    <!-- Podio Escalonado Visual (2º, 1º, 3º) -->
    <div class="pt-3 pb-1">
      <div class="grid grid-cols-3 gap-2 items-end">
        <!-- 2º LUGAR (Plata - Izquierda) -->
        <div class="flex flex-col items-center text-center space-y-1.5">
          <div class="relative">
            <div class="w-11 h-11 rounded-full bg-slate-200 border-2 border-slate-400 p-0.5 shadow-sm flex items-center justify-center font-display font-bold text-slate-700 text-xs overflow-hidden">
              <span class="uppercase">{{ (topThree[0].display_name || '2').charAt(0) }}</span>
            </div>
            <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-slate-500 text-white text-[10px] font-bold flex items-center justify-center shadow-xs">
              2
            </span>
          </div>
          <span class="font-display font-bold text-xs uppercase truncate max-w-[80px] text-guaiqui-text">
            {{ topThree[0].display_name }}
          </span>
          <div class="text-[11px] font-mono font-bold text-slate-600">
            {{ topThree[0].pearls_earned }} <span class="text-[9px]">pts</span>
          </div>
          <!-- Bloque de Podio Plata -->
          <div class="w-full h-16 rounded-t-lg bg-gradient-to-t from-slate-300 to-slate-100 border-t-2 border-slate-400 flex items-center justify-center text-slate-500 font-display font-black text-xl shadow-inner">
            <i class="bi bi-award text-slate-600"></i>
          </div>
        </div>

        <!-- 1º LUGAR (Oro - Centro y Más Alto) -->
        <div class="flex flex-col items-center text-center space-y-1.5">
          <!-- Corona Oro -->
          <i class="bi bi-crown-fill text-amber-500 text-base animate-bounce"></i>
          <div class="relative">
            <div class="w-14 h-14 rounded-full bg-amber-100 border-2 border-amber-400 p-0.5 shadow-md flex items-center justify-center font-display font-extrabold text-amber-900 text-sm overflow-hidden ring-2 ring-amber-400/30">
              <span class="uppercase">{{ (topThree[1].display_name || '1').charAt(0) }}</span>
            </div>
            <span class="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-amber-500 text-white text-xs font-black flex items-center justify-center shadow-xs">
              1
            </span>
          </div>
          <span class="font-display font-extrabold text-xs uppercase truncate max-w-[90px] text-guaiqui-text">
            {{ topThree[1].display_name }}
          </span>
          <div class="text-[11px] font-mono font-bold text-amber-700">
            {{ topThree[1].pearls_earned }} <span class="text-[9px]">pts</span>
          </div>
          <!-- Bloque de Podio Oro -->
          <div class="w-full h-24 rounded-t-lg bg-gradient-to-t from-amber-300 via-amber-200 to-amber-100 border-t-2 border-amber-400 flex items-center justify-center text-amber-700 font-display font-black text-2xl shadow-inner">
            <i class="bi bi-trophy-fill text-amber-600"></i>
          </div>
        </div>

        <!-- 3º LUGAR (Bronce - Derecha) -->
        <div class="flex flex-col items-center text-center space-y-1.5">
          <div class="relative">
            <div class="w-10 h-10 rounded-full bg-amber-800/10 border-2 border-amber-700/60 p-0.5 shadow-sm flex items-center justify-center font-display font-bold text-amber-900 text-xs overflow-hidden">
              <span class="uppercase">{{ (topThree[2].display_name || '3').charAt(0) }}</span>
            </div>
            <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-amber-700 text-white text-[10px] font-bold flex items-center justify-center shadow-xs">
              3
            </span>
          </div>
          <span class="font-display font-bold text-xs uppercase truncate max-w-[80px] text-guaiqui-text">
            {{ topThree[2].display_name }}
          </span>
          <div class="text-[11px] font-mono font-bold text-amber-900">
            {{ topThree[2].pearls_earned }} <span class="text-[9px]">pts</span>
          </div>
          <!-- Bloque de Podio Bronce -->
          <div class="w-full h-12 rounded-t-lg bg-gradient-to-t from-amber-200/80 to-amber-100 border-t-2 border-amber-700/60 flex items-center justify-center text-amber-800 font-display font-black text-lg shadow-inner">
            <i class="bi bi-award text-amber-700"></i>
          </div>
        </div>
      </div>
    </div>

    <!-- Franja Destacada: Tu Posición Actual -->
    <div class="flex items-center justify-between p-3 rounded-guaiqui-lg bg-guaiqui-primary-soft border border-guaiqui-primary/30 text-xs font-semibold">
      <div class="flex items-center gap-2">
        <div class="w-6 h-6 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-xs font-bold font-mono">
          #{{ myRank }}
        </div>
        <span class="text-guaiqui-primary-dark font-bold">Tu Posición</span>
      </div>
      <div class="flex items-center gap-1 font-mono text-guaiqui-primary font-bold">
        <span>{{ myBalance }}</span>
        <span class="text-[10px] uppercase font-sans text-guaiqui-text-muted">Perlitas</span>
      </div>
    </div>
  </BaseCard>
</template>
