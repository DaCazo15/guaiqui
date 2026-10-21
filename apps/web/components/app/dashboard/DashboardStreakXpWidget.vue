<script setup lang="ts">
import { computed } from 'vue'
import { BaseCard, PearlAmount } from '@guaiqui/ui'
import { useAuthStore } from '~/stores/auth'
import { useTriviaStore } from '~/stores/trivias'

const authStore = useAuthStore()
const triviaStore = useTriviaStore()

const currentBalance = computed(() => {
  return triviaStore.homeSummary?.balance ?? authStore.wallet?.balance_cache ?? 0
})

const streakDays = computed(() => {
  return triviaStore.homeSummary?.streak?.streak_days || 0
})

// Sistema de Niveles de Fidelidad (XP = Balance de perlitas ganadas)
const levelConfig = [
  { level: 1, name: 'Novato', min: 0, max: 500 },
  { level: 2, name: 'Insular', min: 500, max: 1500 },
  { level: 3, name: 'Guerrero Verde', min: 1500, max: 3500 },
  { level: 4, name: 'Capitán de Grada', min: 3500, max: 7000 },
  { level: 5, name: 'Leyenda Guaiquerí', min: 7000, max: 15000 },
]

const currentLevelData = computed(() => {
  const bal = currentBalance.value
  const found = levelConfig.find(l => bal >= l.min && bal < l.max)
  return found || levelConfig[levelConfig.length - 1]
})

const nextLevelData = computed(() => {
  const current = currentLevelData.value
  const next = levelConfig.find(l => l.level === current.level + 1)
  return next || current
})

const progressPercent = computed(() => {
  const bal = currentBalance.value
  const cur = currentLevelData.value
  const range = cur.max - cur.min
  if (range <= 0) return 100
  const progress = ((bal - cur.min) / range) * 100
  return Math.min(100, Math.max(0, Math.round(progress)))
})

const xpNeeded = computed(() => {
  const bal = currentBalance.value
  const nextMin = currentLevelData.value.max
  return Math.max(0, nextMin - bal)
})

// Configuración de los 7 días de la semana
const weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D']
const todayIndex = computed(() => {
  const day = new Date().getDay()
  // getDay: 0 es Domingo, 1 es Lunes... Convertir a 0:Lunes, 6:Domingo
  return day === 0 ? 6 : day - 1
})
</script>

<template>
  <BaseCard class="p-2 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-4">
    <!-- Header: Racha con acento bandana rojo y dorado -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-lg bg-rose-50 text-guaiqui-accent border border-rose-200 flex items-center justify-center text-base">
          <i class="bi bi-fire"></i>
        </div>
        <div>
          <h3 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Racha
          </h3>
          <p class="text-[11px] text-guaiqui-text-muted">
            Constancia diaria en la Tribu
          </p>
        </div>
      </div>

      <div class="flex items-center gap-1 px-2.5 py-1 rounded-full bg-gradient-to-r from-amber-500 to-rose-600 text-white font-display font-black text-xs shadow-xs">
        <i class="bi bi-lightning-charge-fill text-[11px]"></i>
        <span>{{ streakDays }} {{ streakDays === 1 ? 'DÍA' : 'DÍAS' }}</span>
      </div>
    </div>

    <!-- Rastreador Visual de 7 Días -->
    <div class="space-y-2 pt-1">
      <div class="grid grid-cols-7 gap-1.5 text-center">
        <div
          v-for="(dayName, idx) in weekDays"
          :key="idx"
          class="flex flex-col items-center gap-1"
        >
          <span class="text-[10px] font-bold text-guaiqui-text-subtle uppercase">
            {{ dayName }}
          </span>

          <!-- Burbuja de Día -->
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-200 relative"
            :class="[
              idx < todayIndex
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : idx === todayIndex
                ? 'bg-gradient-to-tr from-rose-600 to-amber-500 text-white ring-2 ring-rose-400 ring-offset-2 scale-110 shadow-sm'
                : 'bg-guaiqui-surface text-guaiqui-text-muted border border-guaiqui-border'
            ]"
          >
            <!-- Check si fue completado antes de hoy -->
            <i v-if="idx < todayIndex" class="bi bi-check-lg text-sm font-black"></i>
            
            <!-- Fuego si es hoy -->
            <i v-else-if="idx === todayIndex" class="bi bi-fire text-amber-200 text-sm animate-pulse"></i>

            <!-- Día 7: Ícono de cofre de bonus -->
            <i v-else-if="idx === 6" class="bi bi-gift text-amber-500 text-xs"></i>

            <!-- Día futuro general -->
            <span v-else class="text-[10px] text-guaiqui-text-subtle font-mono">{{ idx + 1 }}</span>
          </div>
        </div>
      </div>

      <!-- Banner de Bonificación Semanal -->
      <div class="flex items-center justify-between px-3 py-1.5 rounded-guaiqui-md bg-amber-50 border border-amber-200 text-[11px] font-semibold text-amber-900">
        <span class="flex items-center gap-1.5">
          <i class="bi bi-gift-fill text-amber-600"></i>
          <span>Bonus 7 Días:</span>
        </span>
        <span class="font-bold text-amber-800">+50 Perlitas extra</span>
      </div>
    </div>

    <!-- Barra de Nivel de Fidelidad (XP) -->
    <div class="pt-3 border-t border-guaiqui-border space-y-2">
      <div class="flex items-center justify-between text-xs">
        <div class="flex items-center gap-1.5">
          <span class="px-2 py-0.5 rounded bg-emerald-100 text-emerald-800 font-bold font-mono text-[10px] uppercase">
            Nivel {{ currentLevelData.level }}
          </span>
          <span class="font-display font-extrabold uppercase text-guaiqui-text">
            {{ currentLevelData.name }}
          </span>
        </div>
        <span class="text-[11px] text-guaiqui-text-muted font-mono font-medium">
          {{ progressPercent }}%
        </span>
      </div>

      <!-- Barra de Progreso con Gradiente Energético -->
      <div class="w-full h-2.5 rounded-full bg-guaiqui-surface overflow-hidden border border-guaiqui-border p-0.5">
        <div
          class="h-full rounded-full bg-gradient-to-r from-guaiqui-primary via-emerald-500 to-amber-400 transition-all duration-500 ease-out shadow-xs"
          :style="{ width: `${progressPercent}%` }"
        ></div>
      </div>

      <div class="flex items-center justify-between text-[11px] text-guaiqui-text-subtle font-medium">
        <span>{{ currentBalance }} Perlitas</span>
        <span v-if="xpNeeded > 0">Faltan {{ xpNeeded }} para Nivel {{ nextLevelData.level }}</span>
        <span v-else class="text-amber-600 font-bold">¡Nivel Máximo!</span>
      </div>
    </div>
  </BaseCard>
</template>
