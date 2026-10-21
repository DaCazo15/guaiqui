<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseTabs, PearlAmount } from '@guaiqui/ui'
import { useTriviaStore } from '~/stores/trivias'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Tabla de Posiciones — Guaiqueríes de Margarita',
  description: 'Ranking oficial de los fanáticos con más puntos acumulados en Guaiqueríes de Margarita.',
})

const triviaStore = useTriviaStore()
const currentPeriod = ref<'monthly' | 'weekly'>('monthly')

const tabs = [
  { id: 'monthly', label: 'Ranking Mensual' },
  { id: 'weekly', label: 'Ranking Semanal' },
]

onMounted(async () => {
  await triviaStore.fetchLeaderboard(currentPeriod.value)
})

async function handleTabChange(tabId: string) {
  currentPeriod.value = tabId as 'monthly' | 'weekly'
  await triviaStore.fetchLeaderboard(currentPeriod.value)
}

const firstPlace = computed(() => triviaStore.leaderboard.find((i) => i.rank === 1) || null)
const secondPlace = computed(() => triviaStore.leaderboard.find((i) => i.rank === 2) || null)
const thirdPlace = computed(() => triviaStore.leaderboard.find((i) => i.rank === 3) || null)

const hasPodium = computed(() => {
  return Boolean(firstPlace.value || secondPlace.value || thirdPlace.value)
})

const restOfLeaderboard = computed(() => {
  return triviaStore.leaderboard.filter((i) => i.rank > 3)
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
        Tabla de <span class="text-guaiqui-primary">Posiciones</span>
      </h1>
      <p class="text-sm text-guaiqui-text-muted">
        Los fanáticos con más puntos acumulados demostrando su lealtad por los Guaiqueríes.
      </p>
    </div>

    <!-- Tabs -->
    <BaseTabs :tabs="tabs" :model-value="currentPeriod" @update:model-value="handleTabChange" />

    <!-- Loading Skeleton -->
    <div v-if="triviaStore.isLoading" class="space-y-4">
      <div class="h-64 bg-white border border-guaiqui-border rounded-guaiqui-xl animate-pulse p-6"></div>
      <div v-for="i in 4" :key="i" class="h-14 bg-white border border-guaiqui-border rounded-guaiqui-lg animate-pulse"></div>
    </div>

    <!-- Empty State -->
    <BaseCard
      v-else-if="triviaStore.leaderboard.length === 0"
      class="bg-white border-guaiqui-border rounded-guaiqui-xl p-10 text-center text-guaiqui-text-muted space-y-3 shadow-guaiqui-sm max-w-xl mx-auto"
    >
      <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
        <i class="bi bi-trophy"></i>
      </div>
      <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
        Tabla en Preparación
      </h3>
      <p class="text-sm">
        No hay datos registrados en la tabla para este período aún. ¡Responde la trivia del día y sé el primero en sumar puntos!
      </p>
    </BaseCard>

    <div v-else class="space-y-6">
      <!-- 1. PODIO PARA LOS TRES PRIMEROS PUESTOS -->
      <BaseCard
        v-if="hasPodium"
        class="bg-gradient-to-b from-slate-900 via-stone-900 to-emerald-950 border border-emerald-500/30 rounded-guaiqui-xl p-6 sm:p-8 text-white shadow-guaiqui-md relative overflow-hidden"
      >
        <!-- Glow ambiental -->
        <div class="absolute -top-12 left-1/2 -translate-x-1/2 w-96 h-36 bg-amber-500/10 blur-3xl pointer-events-none"></div>

        <div class="text-center space-y-1 mb-6 relative z-10">
          <span class="text-xs uppercase font-extrabold tracking-widest text-amber-400">
            Honor Insular
          </span>
          <h2 class="font-display font-black text-2xl sm:text-3xl uppercase tracking-wider text-white">
            El Podio de la Tribu
          </h2>
        </div>

        <!-- Columnas del Podio: 2º (Plata), 1º (Oro), 3º (Bronce) -->
        <div class="grid grid-cols-3 gap-2 sm:gap-6 items-end max-w-2xl mx-auto pt-2 relative z-10">
          <!-- 2º LUGAR (Plata - Izquierda) -->
          <div class="flex flex-col items-center text-center space-y-2">
            <div v-if="secondPlace" class="space-y-1.5 flex flex-col items-center">
              <div class="relative">
                <div class="w-14 h-14 sm:w-16 sm:h-16 rounded-full bg-slate-800 border-2 border-slate-300 p-0.5 shadow-md flex items-center justify-center font-display font-bold text-slate-200 text-sm overflow-hidden">
                  <img
                    v-if="secondPlace.avatar_url"
                    :src="secondPlace.avatar_url"
                    :alt="secondPlace.display_name"
                    referrerpolicy="no-referrer"
                    class="w-full h-full object-cover rounded-full"
                  />
                  <span v-else class="uppercase">{{ secondPlace.display_name.charAt(0) }}</span>
                </div>
                <span class="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-slate-400 text-slate-900 text-xs font-black flex items-center justify-center shadow-sm">
                  2
                </span>
              </div>

              <div class="max-w-[90px] sm:max-w-[130px]">
                <p class="font-display font-bold text-xs sm:text-sm text-slate-100 uppercase truncate">
                  {{ secondPlace.display_name }}
                </p>
                <span v-if="secondPlace.is_current_user" class="text-[9px] px-1.5 py-0.2 rounded-full bg-emerald-500 text-white font-bold uppercase">
                  Tú
                </span>
              </div>

              <div class="text-xs sm:text-sm font-mono font-bold text-slate-300">
                {{ secondPlace.pearls_earned }} <span class="text-[10px] uppercase font-sans text-slate-400">pts</span>
              </div>
            </div>
            <div v-else class="text-slate-500 text-xs italic py-4">Vacante</div>

            <!-- Pedestal Plata -->
            <div class="w-full h-24 sm:h-28 rounded-t-xl bg-gradient-to-t from-slate-700 via-slate-600 to-slate-400 border-t-2 border-slate-300 flex flex-col items-center justify-center text-slate-900 font-display font-black text-2xl sm:text-3xl shadow-inner">
              <i class="bi bi-award text-slate-200 text-xl sm:text-2xl mb-1"></i>
              <span>2°</span>
            </div>
          </div>

          <!-- 1º LUGAR (Oro - Centro y más alto) -->
          <div class="flex flex-col items-center text-center space-y-2">
            <div v-if="firstPlace" class="space-y-1.5 flex flex-col items-center">
              <!-- Corona Dorada -->
              <i class="bi bi-crown-fill text-amber-400 text-xl sm:text-2xl animate-bounce"></i>

              <div class="relative">
                <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-amber-950 border-2 border-amber-400 p-0.5 shadow-lg flex items-center justify-center font-display font-extrabold text-amber-200 text-base sm:text-lg overflow-hidden ring-4 ring-amber-400/20">
                  <img
                    v-if="firstPlace.avatar_url"
                    :src="firstPlace.avatar_url"
                    :alt="firstPlace.display_name"
                    referrerpolicy="no-referrer"
                    class="w-full h-full object-cover rounded-full"
                  />
                  <span v-else class="uppercase">{{ firstPlace.display_name.charAt(0) }}</span>
                </div>
                <span class="absolute -bottom-1 -right-1 w-7 h-7 rounded-full bg-amber-400 text-amber-950 text-xs font-black flex items-center justify-center shadow-md">
                  1
                </span>
              </div>

              <div class="max-w-[100px] sm:max-w-[150px]">
                <p class="font-display font-black text-sm sm:text-base text-amber-200 uppercase truncate">
                  {{ firstPlace.display_name }}
                </p>
                <span v-if="firstPlace.is_current_user" class="text-[9px] px-1.5 py-0.2 rounded-full bg-emerald-500 text-white font-bold uppercase">
                  Tú
                </span>
              </div>

              <div class="text-xs sm:text-base font-mono font-bold text-amber-300">
                {{ firstPlace.pearls_earned }} <span class="text-[10px] uppercase font-sans text-amber-400">pts</span>
              </div>
            </div>
            <div v-else class="text-amber-500 text-xs italic py-4">Vacante</div>

            <!-- Pedestal Oro -->
            <div class="w-full h-32 sm:h-40 rounded-t-xl bg-gradient-to-t from-amber-600 via-amber-500 to-amber-300 border-t-2 border-amber-200 flex flex-col items-center justify-center text-amber-950 font-display font-black text-3xl sm:text-4xl shadow-inner">
              <i class="bi bi-trophy-fill text-amber-900 text-2xl sm:text-3xl mb-1"></i>
              <span>1°</span>
            </div>
          </div>

          <!-- 3º LUGAR (Bronce - Derecha) -->
          <div class="flex flex-col items-center text-center space-y-2">
            <div v-if="thirdPlace" class="space-y-1.5 flex flex-col items-center">
              <div class="relative">
                <div class="w-12 h-12 sm:w-14 sm:h-14 rounded-full bg-amber-950 border-2 border-amber-700/80 p-0.5 shadow-md flex items-center justify-center font-display font-bold text-amber-200 text-xs overflow-hidden">
                  <img
                    v-if="thirdPlace.avatar_url"
                    :src="thirdPlace.avatar_url"
                    :alt="thirdPlace.display_name"
                    referrerpolicy="no-referrer"
                    class="w-full h-full object-cover rounded-full"
                  />
                  <span v-else class="uppercase">{{ thirdPlace.display_name.charAt(0) }}</span>
                </div>
                <span class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-amber-700 text-amber-100 text-[10px] font-black flex items-center justify-center shadow-sm">
                  3
                </span>
              </div>

              <div class="max-w-[80px] sm:max-w-[120px]">
                <p class="font-display font-bold text-xs sm:text-sm text-amber-100 uppercase truncate">
                  {{ thirdPlace.display_name }}
                </p>
                <span v-if="thirdPlace.is_current_user" class="text-[9px] px-1.5 py-0.2 rounded-full bg-emerald-500 text-white font-bold uppercase">
                  Tú
                </span>
              </div>

              <div class="text-xs sm:text-sm font-mono font-bold text-amber-300">
                {{ thirdPlace.pearls_earned }} <span class="text-[10px] uppercase font-sans text-amber-400">pts</span>
              </div>
            </div>
            <div v-else class="text-amber-700 text-xs italic py-4">Vacante</div>

            <!-- Pedestal Bronce -->
            <div class="w-full h-18 sm:h-22 rounded-t-xl bg-gradient-to-t from-amber-900 via-amber-800 to-amber-600 border-t-2 border-amber-500 flex flex-col items-center justify-center text-amber-200 font-display font-black text-xl sm:text-2xl shadow-inner">
              <i class="bi bi-award text-amber-300 text-lg sm:text-xl mb-0.5"></i>
              <span>3°</span>
            </div>
          </div>
        </div>
      </BaseCard>

      <!-- 2. RESTO DE PUESTOS EN FORMA DE LISTA (4º EN ADELANTE) -->
      <BaseCard class="bg-white border-guaiqui-border rounded-guaiqui-xl p-6 space-y-4 shadow-guaiqui-sm">
        <div class="flex items-center justify-between pb-2 border-b border-guaiqui-border">
          <div class="flex items-center gap-2">
            <i class="bi bi-list-ol text-guaiqui-primary text-lg"></i>
            <h3 class="font-display font-bold text-base text-guaiqui-text uppercase">
              Clasificación General (Puestos 4°)
            </h3>
          </div>
          <span class="text-xs text-guaiqui-text-muted font-medium">
            {{ restOfLeaderboard.length }} fanáticos
          </span>
        </div>

        <div v-if="restOfLeaderboard.length > 0" class="space-y-2">
          <div
            v-for="item in restOfLeaderboard"
            :key="item.user_id"
            class="flex items-center justify-between p-3.5 rounded-guaiqui-lg border transition-all duration-150"
            :class="[
              item.is_current_user
                ? 'bg-guaiqui-primary-soft border-guaiqui-primary shadow-guaiqui-sm'
                : 'bg-guaiqui-surface border-guaiqui-border hover:bg-white',
            ]"
          >
            <!-- Rank & Avatar/Name -->
            <div class="flex items-center gap-3">
              <span class="w-8 h-8 rounded-full flex items-center justify-center font-bold font-display text-sm bg-gray-200 text-guaiqui-text-muted">
                {{ item.rank }}
              </span>

              <div class="flex items-center gap-2.5">
                <div class="w-9 h-9 rounded-full bg-guaiqui-primary-soft border border-guaiqui-primary/30 flex items-center justify-center font-bold text-xs text-guaiqui-primary overflow-hidden">
                  <img
                    v-if="item.avatar_url"
                    :src="item.avatar_url"
                    referrerpolicy="no-referrer"
                    class="w-full h-full object-cover"
                    alt="Avatar"
                  />
                  <span v-else>{{ item.display_name?.slice(0, 2).toUpperCase() || 'FA' }}</span>
                </div>

                <div>
                  <p class="text-sm font-bold text-guaiqui-text flex items-center gap-2">
                    {{ item.display_name }}
                    <span v-if="item.is_current_user" class="text-xs font-normal px-2 py-0.5 rounded-full bg-guaiqui-primary text-white font-medium">
                      Tú
                    </span>
                  </p>
                </div>
              </div>
            </div>

            <!-- Points Earned -->
            <div class="flex items-center gap-1">
              <PearlAmount :amount="item.pearls_earned" size="sm" show-label label="puntos" />
            </div>
          </div>
        </div>

        <div v-else class="text-center py-6 text-guaiqui-text-muted text-xs">
          No hay fanáticos adicionales clasificados a partir del 4° puesto en este período.
        </div>
      </BaseCard>
    </div>
  </div>
</template>
