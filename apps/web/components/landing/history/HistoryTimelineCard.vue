<script setup lang="ts">
interface MilestoneItem {
  id: string
  year: string
  title: string
  description: string
  badge?: string
  isChampionship?: boolean
}

defineProps<{
  milestone: MilestoneItem
  index: number
  isActive?: boolean
}>()
</script>

<template>
  <div
    class="history-card snap-center w-[300px] sm:w-[380px] lg:w-[420px] shrink-0 bg-slate-900/85 backdrop-blur-xl border rounded-guaiqui-2xl p-6 sm:p-7 flex flex-col justify-between relative overflow-hidden transition-all duration-300 group hover:border-emerald-400/80 hover:shadow-[0_10px_35px_-10px_rgba(16,185,129,0.3)]"
    :class="[
      milestone.isChampionship
        ? 'border-amber-400/50 bg-gradient-to-b from-slate-900/95 via-emerald-950/40 to-slate-900/95'
        : 'border-white/15',
      isActive ? 'ring-2 ring-emerald-400/60' : '',
    ]"
  >
    <!-- Marca de agua gigante con el Año en el fondo -->
    <div
      class="font-display font-black text-7xl sm:text-8xl text-white/[0.04] absolute -right-2 -bottom-2 select-none pointer-events-none group-hover:text-emerald-400/10 transition-colors"
    >
      {{ milestone.year.split(' ')[0] }}
    </div>

    <!-- Cabecera de la Tarjeta -->
    <div class="space-y-3 relative z-10">
      <div class="flex items-center justify-between gap-2">
        <!-- Badge de Tipo de Hito -->
        <span
          class="text-[10px] font-extrabold uppercase tracking-wider px-2.5 py-1 rounded-md border"
          :class="[
            milestone.isChampionship
              ? 'bg-amber-400/20 text-amber-300 border-amber-400/40'
              : 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
          ]"
        >
          <i v-if="milestone.isChampionship" class="bi bi-trophy-fill mr-1 text-amber-400"></i>
          {{ milestone.badge }}
        </span>

        <!-- Número de Orden -->
        <span class="text-xs font-mono font-bold text-slate-500">
          #0{{ index + 1 }}
        </span>
      </div>

      <!-- Año Destacado -->
      <div class="font-display font-black text-3xl sm:text-4xl text-amber-400 tracking-tight flex items-baseline gap-2">
        <span>{{ milestone.year }}</span>
        <span v-if="milestone.isChampionship" class="text-xs font-normal text-amber-300 font-body">
          ★ Corona Nacional
        </span>
      </div>

      <!-- Título del Hito -->
      <h3 class="font-display font-bold text-lg sm:text-xl text-white uppercase tracking-wide leading-snug group-hover:text-emerald-300 transition-colors">
        {{ milestone.title }}
      </h3>

      <!-- Narrativa Histórica -->
      <p class="text-xs sm:text-sm text-slate-300 leading-relaxed pt-1">
        {{ milestone.description }}
      </p>
    </div>

    <!-- Pie de la Tarjeta con Detalle de Identidad Insular -->
    <div class="mt-6 pt-4 border-t border-white/10 flex items-center justify-between text-[11px] text-slate-400 relative z-10">
      <span class="flex items-center gap-1.5">
        <i class="bi bi-geo-alt-fill text-emerald-400"></i>
        La Asunción, Nva. Esparta
      </span>
      <span class="font-mono text-emerald-400/80 font-semibold uppercase">
        Tribu Verde
      </span>
    </div>
  </div>
</template>
