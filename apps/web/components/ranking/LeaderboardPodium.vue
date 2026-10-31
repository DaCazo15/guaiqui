<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import type { LeaderboardItem } from '~/stores/trivias'

const props = defineProps<{
  items: LeaderboardItem[]
}>()

const firstPlace = computed(() => props.items.find((i) => i.rank === 1) || null)
const secondPlace = computed(() => props.items.find((i) => i.rank === 2) || null)
const thirdPlace = computed(() => props.items.find((i) => i.rank === 3) || null)

const hasPodium = computed(() => {
  return Boolean(firstPlace.value || secondPlace.value || thirdPlace.value)
})
</script>

<template>
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

      <!-- 1º LUGAR (Oro - Centro) -->
      <div class="flex flex-col items-center text-center space-y-2">
        <div v-if="firstPlace" class="space-y-1.5 flex flex-col items-center">
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
</template>
