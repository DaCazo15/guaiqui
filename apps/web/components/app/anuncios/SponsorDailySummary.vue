<script setup lang="ts">
import { computed } from 'vue'
import { PearlIcon, BaseButton } from '@guaiqui/ui'

const props = withDefaults(
  defineProps<{
    completedToday: number
    pointsEarnedToday: number
    activeVideosCount: number
    maxDaily?: number
    currentTierReward: number
    blockProgress?: number
    videosUntilNextBlock?: number
    loading: boolean
  }>(),
  {
    maxDaily: 50,
    blockProgress: 0,
    videosUntilNextBlock: 10,
  }
)

const emit = defineEmits<{
  (e: 'watch'): void
}>()

const dailyPercentage = computed(() => {
  return Math.min(100, Math.round((props.completedToday / props.maxDaily) * 100))
})

const blockPercentage = computed(() => {
  const currentBlockProgress = props.completedToday % 10
  return Math.min(100, Math.round((currentBlockProgress / 10) * 100))
})

const isLimitReached = computed(() => {
  return props.completedToday >= props.maxDaily
})

const canWatch = computed(() => {
  return !props.loading && props.activeVideosCount > 0 && !isLimitReached.value
})
</script>

<template>
  <div class="bg-white border border-guaiqui-border rounded-guaiqui-2xl p-5 sm:p-6 shadow-guaiqui-sm space-y-6">
    <!-- Grid de Métricas Diarias (3 columnas en móvil y desktop) -->
    <div class="grid grid-cols-3 gap-2 sm:gap-4">
      <!-- Métrica 1: Videos Reclamados Hoy -->
      <div class="p-2.5 sm:p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-xl flex flex-col sm:flex-row items-center sm:items-center justify-between text-center sm:text-left gap-1 sm:gap-2">
        <div class="space-y-0.5 min-w-0">
          <span class="text-[9px] sm:text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted block leading-tight truncate">
            Vistos Hoy
          </span>
          <div class="flex items-baseline justify-center sm:justify-start gap-1">
            <span class="font-display font-black text-lg sm:text-2xl text-guaiqui-primary">
              {{ completedToday }}
            </span>
            <span class="text-[9px] sm:text-xs text-guaiqui-text-muted font-medium">
              /{{ maxDaily }}
            </span>
          </div>
          <span class="text-[8px] sm:text-[10px] text-guaiqui-text-muted hidden sm:block">máx diario</span>
        </div>
        <div class="w-7 h-7 sm:w-11 sm:h-11 rounded-lg sm:rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center text-sm sm:text-xl border border-emerald-100 shrink-0">
          <i class="bi bi-camera-reels-fill"></i>
        </div>
      </div>

      <!-- Métrica 2: Puntos Ganados Hoy -->
      <div class="p-2.5 sm:p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-xl flex flex-col sm:flex-row items-center sm:items-center justify-between text-center sm:text-left gap-1 sm:gap-2">
        <div class="space-y-0.5 min-w-0">
          <span class="text-[9px] sm:text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted block leading-tight truncate">
            Puntos Hoy
          </span>
          <div class="flex items-center justify-center sm:justify-start gap-1">
            <PearlIcon size="xs" class="sm:hidden" />
            <PearlIcon size="sm" class="hidden sm:inline-flex" />
            <span class="font-display font-black text-lg sm:text-2xl text-guaiqui-text">
              +{{ pointsEarnedToday }}
            </span>
          </div>
          <span class="text-[8px] sm:text-[10px] text-guaiqui-text-muted hidden sm:block">/ 60 máx diario</span>
        </div>
        <div class="w-7 h-7 sm:w-11 sm:h-11 rounded-lg sm:rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center text-sm sm:text-xl border border-amber-100 shrink-0">
          <i class="bi bi-coin"></i>
        </div>
      </div>

      <!-- Métrica 3: Recompensa Próximo Bloque -->
      <div class="p-2.5 sm:p-4 bg-guaiqui-surface border border-guaiqui-border rounded-guaiqui-xl flex flex-col sm:flex-row items-center sm:items-center justify-between text-center sm:text-left gap-1 sm:gap-2">
        <div class="space-y-0.5 min-w-0">
          <span class="text-[9px] sm:text-[11px] font-bold uppercase tracking-wider text-guaiqui-text-muted block leading-tight truncate">
            Próximo (+{{ isLimitReached ? 0 : currentTierReward }})
          </span>
          <div class="flex items-center justify-center sm:justify-start gap-1">
            <span class="font-display font-black text-lg sm:text-2xl text-guaiqui-primary">
              {{ isLimitReached ? 0 : (videosUntilNextBlock || (10 - (completedToday % 10))) }}
            </span>
          </div>
          <span class="text-[8px] sm:text-[10px] font-medium text-guaiqui-text-muted truncate block">
            {{ isLimitReached ? 'Completado' : 'videos restantes' }}
          </span>
        </div>
        <div class="w-7 h-7 sm:w-11 sm:h-11 rounded-lg sm:rounded-xl bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-sm sm:text-xl border border-guaiqui-primary/20 shrink-0">
          <i class="bi bi-award-fill"></i>
        </div>
      </div>
    </div>

    <!-- Barra de progreso hacia el límite de 50 videos -->
    <div class="space-y-1.5">
      <div class="flex items-center justify-between text-xs">
        <span class="text-guaiqui-text-muted font-semibold flex items-center gap-1">
          <i class="bi bi-calendar-check text-guaiqui-primary"></i>
          Meta diaria global ({{ completedToday }} de {{ maxDaily }} videos · {{ pointsEarnedToday }} de 60 pts)
        </span>
        <span class="font-mono font-bold text-guaiqui-primary">
          {{ dailyPercentage }}%
        </span>
      </div>
      <div class="w-full h-2 bg-slate-100 rounded-full overflow-hidden border border-slate-200">
        <div
          class="h-full bg-guaiqui-primary bg-gradient-to-r from-guaiqui-primary via-emerald-500 to-emerald-400 transition-all duration-500 rounded-full"
          :style="{ width: `${dailyPercentage}%` }"
        ></div>
      </div>
    </div>

    <!-- Banner y Botón Principal "Ver Video" -->
    <div class="p-5 sm:p-6 rounded-guaiqui-xl bg-slate-950 bg-gradient-to-r from-emerald-950 via-slate-900 to-emerald-900 text-white flex flex-col md:flex-row items-start md:items-center justify-between gap-5 shadow-guaiqui-md border border-emerald-500/30">
      <div class="space-y-1.5">
        <h3 class="font-display font-black text-xl sm:text-2xl uppercase tracking-wide text-white">
          ¡Apoya a Guaiqueríes y acumula puntos!
        </h3>
        <p class="text-xs sm:text-sm text-slate-300 max-w-xl leading-relaxed">
          Cada video dura pocos segundos. El sistema seleccionará un video al azar para ti. Míralo completo sin pausar para acreditar tus puntos.
        </p>
      </div>

      <div class="w-full md:w-auto shrink-0">
        <button
          type="button"
          :disabled="!canWatch"
          class="w-full md:w-auto px-8 py-4 rounded-guaiqui-xl bg-guaiqui-primary bg-gradient-to-r from-guaiqui-primary to-emerald-600 hover:from-emerald-600 hover:to-emerald-500 disabled:from-slate-700 disabled:to-slate-800 disabled:bg-slate-700 disabled:text-slate-400 disabled:cursor-not-allowed text-white font-display font-black text-base uppercase tracking-wider shadow-lg flex items-center justify-center gap-3 transition-all transform hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
          @click="emit('watch')"
        >
          <i class="bi bi-play-circle-fill text-2xl text-emerald-200"></i>
          <span>{{ isLimitReached ? 'Límite de Hoy Alcanzado' : 'Ver Video' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
