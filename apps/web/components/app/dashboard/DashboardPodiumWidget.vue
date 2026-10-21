<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'
import { useAuthStore } from '~/stores/auth'

const triviaStore = useTriviaStore()
const authStore = useAuthStore()

// Carga asíncrona del podio oficial
onMounted(async () => {
  if (triviaStore.leaderboard.length === 0) {
    await triviaStore.fetchLeaderboard('monthly')
  }
})

// Mapeo dinámico de posiciones del podio real (1º, 2º, 3º)
const firstPlace = computed(() => triviaStore.leaderboard[0] || null)
const secondPlace = computed(() => triviaStore.leaderboard[1] || null)
const thirdPlace = computed(() => triviaStore.leaderboard[2] || null)

// Rango del usuario actual calculado dinámicamente
const myRank = computed(() => {
  if (triviaStore.homeSummary?.my_rank) return triviaStore.homeSummary.my_rank
  const currentUserId = authStore.user?.id
  if (currentUserId && triviaStore.leaderboard.length > 0) {
    const idx = triviaStore.leaderboard.findIndex(item => item.user_id === currentUserId || item.is_current_user)
    if (idx !== -1) return idx + 1
  }
  return null
})

const myBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})
</script>

<template>
  <BaseCard class="p-4 sm:p-5 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Encabezado con Trofeo y Enlace -->
    <div class="flex items-center justify-between pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2.5">
        <div class="w-9 h-9 rounded-guaiqui-md bg-amber-50 text-amber-500 border border-amber-200 flex items-center justify-center text-base shrink-0">
          <i class="bi bi-trophy-fill"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide leading-tight">
            Podio Mensual
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">
            Top Fanáticos de la Tribu
          </p>
        </div>
      </div>

      <NuxtLink to="/app/ranking" class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-bold inline-flex items-center gap-1 transition-colors">
        <span>Tabla completa</span>
        <i class="bi bi-arrow-right"></i>
      </NuxtLink>
    </div>

    <!-- Podio Escalonado Visual 100% Dinámico (2º, 1º, 3º) -->
    <div class="pt-2">
      <div class="grid grid-cols-3 gap-2 items-end">
        <!-- 2º LUGAR (Plata - Izquierda) -->
        <div class="flex flex-col items-center text-center space-y-1">
          <div class="relative">
            <div class="w-12 h-12 rounded-full bg-slate-100 border-2 border-slate-400 p-0.5 shadow-sm flex items-center justify-center font-display font-bold text-slate-700 text-xs overflow-hidden">
              <img
                v-if="secondPlace?.avatar_url"
                :src="secondPlace.avatar_url"
                :alt="secondPlace.display_name"
                class="w-full h-full object-cover rounded-full"
                referrerpolicy="no-referrer"
              />
              <span v-else-if="secondPlace" class="uppercase">{{ secondPlace.display_name.charAt(0) }}</span>
              <i v-else class="bi bi-person-plus text-slate-400 text-sm"></i>
            </div>
            <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-slate-500 text-white text-[10px] font-bold flex items-center justify-center shadow-xs">
              2
            </span>
          </div>

          <span class="font-display font-bold text-xs uppercase truncate max-w-[85px] text-guaiqui-text">
            {{ secondPlace ? secondPlace.display_name : 'Disponible' }}
          </span>
          <div class="text-[11px] font-mono font-bold text-slate-600">
            {{ secondPlace ? secondPlace.pearls_earned : 0 }} <span class="text-[9px]">pts</span>
          </div>

          <!-- Bloque de Podio Plata -->
          <div class="w-full h-16 rounded-t-lg bg-gradient-to-t from-slate-300 to-slate-100 border-t-2 border-slate-400 flex items-center justify-center text-slate-500 font-display font-black text-lg shadow-inner">
            <i class="bi bi-award text-slate-600"></i>
          </div>
        </div>

        <!-- 1º LUGAR (Oro - Centro y Más Alto) -->
        <div class="flex flex-col items-center text-center space-y-1">
          <!-- Corona Oro -->
          <i class="bi bi-crown-fill text-amber-500 text-base animate-bounce"></i>
          <div class="relative">
            <div class="w-14 h-14 rounded-full bg-amber-100 border-2 border-amber-400 p-0.5 shadow-md flex items-center justify-center font-display font-extrabold text-amber-900 text-sm overflow-hidden ring-2 ring-amber-400/30">
              <img
                v-if="firstPlace?.avatar_url"
                :src="firstPlace.avatar_url"
                :alt="firstPlace.display_name"
                class="w-full h-full object-cover rounded-full"
                referrerpolicy="no-referrer"
              />
              <span v-else-if="firstPlace" class="uppercase">{{ firstPlace.display_name.charAt(0) }}</span>
              <i v-else class="bi bi-person text-amber-400 text-base"></i>
            </div>
            <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-amber-500 text-white text-[10px] font-black flex items-center justify-center shadow-xs">
              1
            </span>
          </div>

          <span class="font-display font-extrabold text-xs uppercase truncate max-w-[95px] text-guaiqui-text">
            {{ firstPlace ? firstPlace.display_name : 'Disponible' }}
          </span>
          <div class="text-[11px] font-mono font-bold text-amber-700">
            {{ firstPlace ? firstPlace.pearls_earned : 0 }} <span class="text-[9px]">pts</span>
          </div>

          <!-- Bloque de Podio Oro -->
          <div class="w-full h-22 rounded-t-lg bg-gradient-to-t from-amber-300 via-amber-200 to-amber-100 border-t-2 border-amber-400 flex items-center justify-center text-amber-700 font-display font-black text-xl shadow-inner">
            <i class="bi bi-trophy-fill text-amber-600"></i>
          </div>
        </div>

        <!-- 3º LUGAR (Bronce - Derecha) -->
        <div class="flex flex-col items-center text-center space-y-1">
          <div class="relative">
            <div class="w-11 h-11 rounded-full bg-amber-800/10 border-2 border-amber-700/60 p-0.5 shadow-sm flex items-center justify-center font-display font-bold text-amber-900 text-xs overflow-hidden">
              <img
                v-if="thirdPlace?.avatar_url"
                :src="thirdPlace.avatar_url"
                :alt="thirdPlace.display_name"
                class="w-full h-full object-cover rounded-full"
                referrerpolicy="no-referrer"
              />
              <span v-else-if="thirdPlace" class="uppercase">{{ thirdPlace.display_name.charAt(0) }}</span>
              <i v-else class="bi bi-person-plus text-amber-700/50 text-sm"></i>
            </div>
            <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-amber-700 text-white text-[10px] font-bold flex items-center justify-center shadow-xs">
              3
            </span>
          </div>

          <span class="font-display font-bold text-xs uppercase truncate max-w-[85px] text-guaiqui-text">
            {{ thirdPlace ? thirdPlace.display_name : 'Disponible' }}
          </span>
          <div class="text-[11px] font-mono font-bold text-amber-900">
            {{ thirdPlace ? thirdPlace.pearls_earned : 0 }} <span class="text-[9px]">pts</span>
          </div>

          <!-- Bloque de Podio Bronce -->
          <div class="w-full h-12 rounded-t-lg bg-gradient-to-t from-amber-200/80 to-amber-100 border-t-2 border-amber-700/60 flex items-center justify-center text-amber-800 font-display font-black text-base shadow-inner">
            <i class="bi bi-award text-amber-700"></i>
          </div>
        </div>
      </div>
    </div>

    <!-- Franja Destacada: Tu Posición Actual Calculada -->
    <div class="flex items-center justify-between p-3 rounded-guaiqui-lg bg-guaiqui-primary-soft border border-guaiqui-primary/20 text-xs font-semibold">
      <div class="flex items-center gap-2">
        <div class="w-6 h-6 rounded-full bg-guaiqui-primary text-white flex items-center justify-center text-[11px] font-bold font-mono">
          {{ myRank ? `#${myRank}` : '—' }}
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
