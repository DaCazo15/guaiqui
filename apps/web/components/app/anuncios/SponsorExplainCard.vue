<script setup lang="ts">
import { PearlIcon } from '@guaiqui/ui'

defineProps<{
  completedToday: number
  maxDaily: number
  currentTierReward: number
}>()
</script>

<template>
  <div class="bg-white border border-guaiqui-border rounded-guaiqui-2xl p-5 sm:p-6 shadow-guaiqui-sm space-y-5">
    <!-- Header de la tarjeta explicativa -->
    <div class="flex items-start gap-3.5">
      <div class="w-10 h-10 rounded-xl bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-xl shrink-0 border border-guaiqui-primary/20">
        <i class="bi bi-info-circle-fill"></i>
      </div>
      <div>
        <h2 class="font-display font-black text-lg sm:text-xl text-guaiqui-text uppercase tracking-wide">
          ¿Cómo funcionan los videos patrocinados?
        </h2>
        <p class="text-xs sm:text-sm text-guaiqui-text-muted mt-0.5 leading-relaxed">
          Mira videos, acumula puntos y sube en el ranking.
        </p>
      </div>
    </div>

    <!-- Tramos de Puntos (Bloques de 10 videos: máx 60 puntos al día) -->
    <div class="space-y-2.5">
      <div class="flex items-center justify-between text-xs font-bold text-guaiqui-text">
        <span class="uppercase tracking-wider text-[11px] text-guaiqui-text-muted">
          Puntos por Bloques de 10 Videos
        </span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <!-- Tramo 1: Bloque 1 (Videos 1 al 10) -->
        <div
          class="p-3.5 rounded-guaiqui-xl border transition-all"
          :class="[
            completedToday < 10
              ? 'bg-emerald-50/70 border-guaiqui-primary ring-2 ring-guaiqui-primary/20 shadow-xs'
              : 'bg-slate-50 border-slate-200 opacity-80'
          ]"
        >
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-black uppercase tracking-wider text-guaiqui-text">
              Bloque 1
            </span>
            <span
              v-if="completedToday < 10"
              class="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-guaiqui-primary text-white"
            >
              En Curso
            </span>
            <span
              v-else
              class="text-[10px] font-bold text-emerald-600 flex items-center gap-1"
            >
              <i class="bi bi-check-circle-fill"></i> Completado
            </span>
          </div>

          <div class="flex items-center gap-2 mt-2">
            <PearlIcon size="md" />
            <span class="font-display font-black text-2xl text-guaiqui-text">
              +5
            </span>
            <span class="text-xs font-semibold text-guaiqui-text-muted">
              puntos al completar los 10
            </span>
          </div>
        </div>

        <!-- Tramo 2: Bloque 2 (Videos 11 al 20) -->
        <div
          class="p-3.5 rounded-guaiqui-xl border transition-all"
          :class="[
            completedToday >= 10 && completedToday < 20
              ? 'bg-emerald-50/70 border-guaiqui-primary ring-2 ring-guaiqui-primary/20 shadow-xs'
              : completedToday >= 20
                ? 'bg-slate-50 border-slate-200 opacity-80'
                : 'bg-white border-guaiqui-border'
          ]"
        >
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-black uppercase tracking-wider text-guaiqui-text">
              Bloque 2
            </span>
            <span
              v-if="completedToday >= 10 && completedToday < 20"
              class="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-guaiqui-primary text-white"
            >
              En Curso
            </span>
            <span
              v-else-if="completedToday >= 20"
              class="text-[10px] font-bold text-emerald-600 flex items-center gap-1"
            >
              <i class="bi bi-check-circle-fill"></i> Completado
            </span>
            <span
              v-else
              class="text-[10px] font-semibold text-guaiqui-text-muted"
            >
              Bloqueado
            </span>
          </div>

          <div class="flex items-center gap-2 mt-2">
            <PearlIcon size="md" />
            <span class="font-display font-black text-2xl text-guaiqui-text">
              +10
            </span>
            <span class="text-xs font-semibold text-guaiqui-text-muted">
              puntos al completar los 20
            </span>
          </div>
        </div>

        <!-- Tramo 3: Bloques 3, 4 y 5 (Videos 21 al 50) -->
        <div
          class="p-3.5 rounded-guaiqui-xl border transition-all"
          :class="[
            completedToday >= 20 && completedToday < 50
              ? 'bg-emerald-50/70 border-guaiqui-primary ring-2 ring-guaiqui-primary/20 shadow-xs'
              : completedToday >= 50
                ? 'bg-slate-50 border-slate-200 opacity-80'
                : 'bg-white border-guaiqui-border'
          ]"
        >
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-black uppercase tracking-wider text-guaiqui-text">
              Bloques 3 (Videos 21 a 50)
            </span>
            <span
              v-if="completedToday >= 20 && completedToday < 50"
              class="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-guaiqui-primary text-white"
            >
              En Curso
            </span>
            <span
              v-else-if="completedToday >= 50"
              class="text-[10px] font-bold text-emerald-600 flex items-center gap-1"
            >
              <i class="bi bi-check-circle-fill"></i> Máximo Alcanzado
            </span>
            <span
              v-else
              class="text-[10px] font-semibold text-guaiqui-text-muted"
            >
              Bloqueado
            </span>
          </div>

          <div class="flex items-center gap-2 mt-2">
            <PearlIcon size="md" />
            <span class="font-display font-black text-2xl text-guaiqui-text">
              +15
            </span>
            <span class="text-xs font-semibold text-guaiqui-text-muted">
              puntos cada 10 videos
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Reglas de visualización y validación del video -->
    <div class="p-3.5 bg-slate-50 border border-slate-200 rounded-guaiqui-xl text-xs text-guaiqui-text space-y-2">
      <div class="font-bold flex items-center gap-2 text-guaiqui-text">
        <i class="bi bi-shield-check text-guaiqui-primary text-base"></i>
        <span>Condiciones para validar tus puntos:</span>
      </div>
      <ul class="grid grid-cols-1 sm:grid-cols-3 gap-2.5 text-[11px] text-guaiqui-text-muted">
        <li class="flex items-start gap-2">
          <i class="bi bi-play-circle text-guaiqui-primary shrink-0 mt-0.5 text-sm"></i>
          <span>El temporizador arranca únicamente cuando inicia la reproducción del video.</span>
        </li>
        <li class="flex items-start gap-2">
          <i class="bi bi-pause-circle text-amber-500 shrink-0 mt-0.5 text-sm"></i>
          <span>Si pausas el video, el tiempo de validez también se detiene en seco.</span>
        </li>
        <li class="flex items-start gap-2">
          <i class="bi bi-x-circle text-guaiqui-accent shrink-0 mt-0.5 text-sm"></i>
          <span>Si cierras la modal antes de terminar el tiempo requerido, el progreso se pierde.</span>
        </li>
      </ul>
    </div>
  </div>
</template>
