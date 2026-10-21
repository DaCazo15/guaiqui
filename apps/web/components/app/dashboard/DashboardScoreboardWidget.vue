<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { BaseCard } from '@guaiqui/ui'

// Fecha del próximo partido (Juego 5 - Final SPB: viernes a las 19:00 Caracas)
const targetDate = new Date(Date.now() + (2 * 24 * 60 * 60 + 14 * 60 * 60 + 35 * 60) * 1000)

const days = ref('02')
const hours = ref('14')
const minutes = ref('35')
const seconds = ref('00')
let countdownTimer: ReturnType<typeof setInterval> | null = null

function updateCountdown() {
  const now = new Date().getTime()
  const diff = targetDate.getTime() - now

  if (diff <= 0) {
    days.value = '00'
    hours.value = '00'
    minutes.value = '00'
    seconds.value = '00'
    return
  }

  const d = Math.floor(diff / (1000 * 60 * 60 * 24))
  const h = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  const m = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
  const s = Math.floor((diff % (1000 * 60)) / 1000)

  days.value = d.toString().padStart(2, '0')
  hours.value = h.toString().padStart(2, '0')
  minutes.value = m.toString().padStart(2, '0')
  seconds.value = s.toString().padStart(2, '0')
}

onMounted(() => {
  updateCountdown()
  countdownTimer = setInterval(updateCountdown, 1000)
})

onBeforeUnmount(() => {
  if (countdownTimer) clearInterval(countdownTimer)
})
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-5">
    <!-- Encabezado de Sección -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-3">
        <!-- Ícono deportivo con acento bandana rojo -->
        <div class="w-10 h-10 rounded-guaiqui-lg bg-guaiqui-accent/10 border border-guaiqui-accent/20 flex items-center justify-center text-guaiqui-accent text-lg shrink-0">
          <i class="bi bi-trophy-fill"></i>
        </div>
        <div>
          <div class="flex items-center gap-2">
            <h2 class="font-display font-extrabold text-xl text-guaiqui-text uppercase tracking-wide">
              Gran Final SPB & Calendario
            </h2>
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-guaiqui-accent text-white shadow-xs">
              Serie 3-1
            </span>
          </div>
          <p class="text-xs text-guaiqui-text-muted">
            Superliga Profesional de Baloncesto · Edición Oficial 2026
          </p>
        </div>
      </div>

      <NuxtLink to="/app/partidos">
        <button class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-guaiqui-md bg-guaiqui-surface hover:bg-gray-200 text-guaiqui-text text-xs font-bold uppercase tracking-wider border border-guaiqui-border transition-colors">
          <i class="bi bi-calendar-week text-guaiqui-primary"></i>
          <span>Ver Calendario</span>
          <i class="bi bi-chevron-right text-[10px]"></i>
        </button>
      </NuxtLink>
    </div>

    <!-- Matchup Hero: Marcador Deportivo y Cuenta Regresiva -->
    <div class="relative overflow-hidden rounded-guaiqui-xl bg-gradient-to-br from-stone-950 via-emerald-950 to-slate-900 border border-emerald-500/40 p-5 text-white shadow-md">
      <!-- Glow deportivo de fondo -->
      <div class="absolute -top-12 left-1/2 -translate-x-1/2 w-72 h-36 bg-emerald-500/20 blur-3xl pointer-events-none"></div>

      <!-- Fila superior: Badge de partido y Gimnasio -->
      <div class="flex items-center justify-between text-xs text-slate-300 pb-3 border-b border-white/10">
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-guaiqui-accent animate-ping"></span>
          <span class="font-mono font-bold text-emerald-400 uppercase tracking-widest text-[11px]">Juego 5 · En Camino a la Corona</span>
        </div>
        <span class="font-medium text-[11px] text-slate-300 flex items-center gap-1">
          <i class="bi bi-geo-alt-fill text-guaiqui-accent"></i>
          Gimnasio Luis Ramos, Pto. La Cruz
        </span>
      </div>

      <!-- Duelo Guaiqueríes vs Marinos -->
      <div class="grid grid-cols-3 items-center py-5">
        <!-- Equipo Local: Guaiqueríes -->
        <div class="flex flex-col items-center text-center space-y-2">
          <div class="relative w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-emerald-900/80 border-2 border-emerald-400 p-2 shadow-lg flex items-center justify-center">
            <img src="/logo.png" alt="Guaiqueríes de Margarita" class="w-full h-full object-contain drop-shadow" />
            <span class="absolute -bottom-1 px-2 py-0.5 rounded-full bg-emerald-600 text-white text-[9px] font-black uppercase tracking-wider">
              Tribu
            </span>
          </div>
          <div>
            <h3 class="font-display font-black text-base sm:text-lg uppercase text-white tracking-wide">
              Guaiqueríes
            </h3>
            <p class="text-[11px] text-emerald-400 font-bold uppercase">Margarita</p>
          </div>
        </div>

        <!-- Marcador de la Serie y VS -->
        <div class="flex flex-col items-center text-center space-y-1">
          <div class="px-3 py-1 rounded-full bg-white/10 border border-white/20 text-[10px] font-extrabold uppercase tracking-widest text-amber-300">
            Final SPB
          </div>
          <div class="font-display font-black text-3xl sm:text-4xl text-white tracking-widest py-1">
            VS
          </div>
          <div class="text-[11px] font-bold text-slate-400">
            Serie al mejor de 7
          </div>
        </div>

        <!-- Equipo Rival: Marinos de Anzoátegui -->
        <div class="flex flex-col items-center text-center space-y-2">
          <div class="relative w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-slate-900 border-2 border-slate-600 p-2 shadow-lg flex items-center justify-center">
            <!-- Escudo Rival estilizado -->
            <div class="w-full h-full rounded-full bg-gradient-to-br from-blue-900 to-indigo-950 flex items-center justify-center text-amber-400 text-2xl font-black font-display border border-blue-400/30">
              <i class="bi bi-shield-shaded"></i>
            </div>
            <span class="absolute -bottom-1 px-2 py-0.5 rounded-full bg-blue-700 text-white text-[9px] font-black uppercase tracking-wider">
              Rival
            </span>
          </div>
          <div>
            <h3 class="font-display font-black text-base sm:text-lg uppercase text-white tracking-wide">
              Marinos
            </h3>
            <p class="text-[11px] text-slate-400 font-bold uppercase">Anzoátegui</p>
          </div>
        </div>
      </div>

      <!-- Contador Regresivo Deportivo Visible -->
      <div class="mt-2 pt-4 border-t border-white/10 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <span class="px-2 py-0.5 rounded-md bg-guaiqui-accent text-white text-[10px] font-extrabold uppercase tracking-widest">
            Tiempo para el Salto Entre Dos
          </span>
        </div>

        <!-- Dígitos del Countdown -->
        <div class="flex items-center gap-2 font-mono">
          <div class="bg-black/60 border border-emerald-500/30 rounded-lg px-2.5 py-1 text-center min-w-[46px]">
            <span class="font-display font-black text-lg text-emerald-400 tabular-nums">{{ days }}</span>
            <span class="block text-[8px] uppercase tracking-wider text-slate-400">Días</span>
          </div>
          <span class="text-emerald-400 font-bold">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded-lg px-2.5 py-1 text-center min-w-[46px]">
            <span class="font-display font-black text-lg text-emerald-400 tabular-nums">{{ hours }}</span>
            <span class="block text-[8px] uppercase tracking-wider text-slate-400">Horas</span>
          </div>
          <span class="text-emerald-400 font-bold">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded-lg px-2.5 py-1 text-center min-w-[46px]">
            <span class="font-display font-black text-lg text-emerald-400 tabular-nums">{{ minutes }}</span>
            <span class="block text-[8px] uppercase tracking-wider text-slate-400">Min</span>
          </div>
          <span class="text-emerald-400 font-bold">:</span>
          <div class="bg-black/60 border border-emerald-500/30 rounded-lg px-2.5 py-1 text-center min-w-[46px]">
            <span class="font-display font-black text-lg text-amber-400 tabular-nums animate-pulse">{{ seconds }}</span>
            <span class="block text-[8px] uppercase tracking-wider text-slate-400">Seg</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Resultados Recientes de la Serie (Juego 4 y Juego 3) -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
      <div class="p-3.5 bg-guaiqui-surface rounded-guaiqui-lg border border-guaiqui-border space-y-2 hover:border-guaiqui-primary/40 transition-colors">
        <div class="flex items-center justify-between text-xs font-semibold text-guaiqui-text-muted">
          <span>Juego 4 · La Asunción</span>
          <span class="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-[10px] font-black uppercase tracking-wider">
            Victoria Insular
          </span>
        </div>
        <div class="flex items-center justify-between text-sm">
          <span class="font-display font-bold uppercase text-guaiqui-text">Guaiqueríes</span>
          <span class="font-display font-black text-lg text-guaiqui-primary tabular-nums">81</span>
        </div>
        <div class="flex items-center justify-between text-sm">
          <span class="font-display font-semibold uppercase text-guaiqui-text-muted">Marinos</span>
          <span class="font-display font-bold text-base text-guaiqui-text-muted tabular-nums">78</span>
        </div>
      </div>

      <div class="p-3.5 bg-guaiqui-surface rounded-guaiqui-lg border border-guaiqui-border space-y-2 hover:border-guaiqui-primary/40 transition-colors">
        <div class="flex items-center justify-between text-xs font-semibold text-guaiqui-text-muted">
          <span>Juego 3 · La Asunción</span>
          <span class="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-[10px] font-black uppercase tracking-wider">
            Victoria Insular
          </span>
        </div>
        <div class="flex items-center justify-between text-sm">
          <span class="font-display font-bold uppercase text-guaiqui-text">Guaiqueríes</span>
          <span class="font-display font-black text-lg text-guaiqui-primary tabular-nums">75</span>
        </div>
        <div class="flex items-center justify-between text-sm">
          <span class="font-display font-semibold uppercase text-guaiqui-text-muted">Marinos</span>
          <span class="font-display font-bold text-base text-guaiqui-text-muted tabular-nums">72</span>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
