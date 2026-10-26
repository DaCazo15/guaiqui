<script setup lang="ts">
interface MilestoneItem {
  id: string
  year: string
  title: string
  badge?: string
  isChampionship?: boolean
}

defineProps<{
  scrollProgress: number
  milestones: MilestoneItem[]
  activeYear?: string
}>()

const emit = defineEmits<{
  (e: 'prev'): void
  (e: 'next'): void
  (e: 'selectYear', year: string, index: number): void
}>()
</script>

<template>
  <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-6 border-b border-emerald-900/60 pb-5 shrink-0">
    <div class="space-y-2 max-w-2xl">
      <div class="inline-flex items-center gap-2 bg-emerald-950/80 border border-emerald-500/30 px-3.5 py-1 rounded-full text-xs font-mono font-bold text-emerald-400 uppercase tracking-widest">
        <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
        49 Años de Tradición Insular
      </div>
      <h2 class="font-display font-black text-3xl sm:text-4xl lg:text-5xl uppercase tracking-tight text-white">
        Línea del Tiempo <span class="text-emerald-400">Histórica</span>
      </h2>
      <p class="text-xs sm:text-sm text-slate-300">
        De La Asunción a la inmortalidad. Desplaza para revivir las gestas y títulos que consagraron a Guaiqueríes de Margarita.
      </p>

      <!-- Píldoras de Años / Hitos para navegación rápida -->
      <div class="hidden sm:flex flex-wrap items-center gap-1.5 pt-2">
        <button
          v-for="(m, idx) in milestones"
          :key="m.id"
          type="button"
          class="text-[11px] font-mono px-2.5 py-0.5 rounded-full border transition-all duration-200 cursor-pointer"
          :class="[
            m.year === activeYear
              ? 'bg-amber-400 text-slate-950 border-amber-400 font-bold shadow-[0_0_12px_rgba(251,191,36,0.5)]'
              : m.isChampionship
              ? 'bg-amber-400/10 text-amber-300 border-amber-400/30 hover:bg-amber-400/20'
              : 'bg-slate-800/80 text-slate-300 border-white/10 hover:border-emerald-400/40 hover:text-emerald-300',
          ]"
          @click="emit('selectYear', m.year, idx)"
        >
          <i v-if="m.isChampionship" class="bi bi-star-fill text-[9px] mr-0.5 text-amber-400"></i>
          {{ m.year.split(' ')[0] }}
        </button>
      </div>
    </div>

    <!-- Controles de Progreso y Navegación de Flechas -->
    <div class="flex items-center lg:flex-col lg:items-end justify-between gap-3 shrink-0">
      <!-- Indicador de Desplazamiento Horizontal con Barra y Porcentaje -->
      <div class="flex flex-col gap-1.5 min-w-[180px] sm:min-w-[220px]">
        <div class="flex items-center justify-between w-full text-xs font-mono">
          <span class="text-slate-400">Progreso Histórico</span>
          <span class="font-bold text-amber-400 tabular-nums">{{ scrollProgress }}%</span>
        </div>
        <div class="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden border border-white/10">
          <div
            class="h-full bg-gradient-to-r from-emerald-500 via-emerald-400 to-amber-400 rounded-full transition-all duration-150"
            :style="{ width: `${scrollProgress}%` }"
          />
        </div>
        <span class="hidden lg:flex text-[10px] text-slate-400 items-center gap-1">
          <i class="bi bi-mouse text-emerald-400"></i> Desplaza verticalmente o usa las flechas
        </span>
      </div>

      <!-- Flechas de navegación interactiva Anterior / Siguiente -->
      <div class="flex items-center gap-2">
        <button
          type="button"
          aria-label="Hito histórico anterior"
          class="w-8 h-8 rounded-full border border-white/20 bg-slate-900/80 hover:bg-emerald-500 hover:text-slate-950 hover:border-emerald-400 text-white flex items-center justify-center transition-all duration-200 cursor-pointer disabled:opacity-30 disabled:pointer-events-none"
          :disabled="scrollProgress <= 2"
          @click="emit('prev')"
        >
          <i class="bi bi-chevron-left text-sm"></i>
        </button>
        <button
          type="button"
          aria-label="Hito histórico siguiente"
          class="w-8 h-8 rounded-full border border-white/20 bg-slate-900/80 hover:bg-emerald-500 hover:text-slate-950 hover:border-emerald-400 text-white flex items-center justify-center transition-all duration-200 cursor-pointer disabled:opacity-30 disabled:pointer-events-none"
          :disabled="scrollProgress >= 98"
          @click="emit('next')"
        >
          <i class="bi bi-chevron-right text-sm"></i>
        </button>
      </div>
    </div>
  </div>
</template>
