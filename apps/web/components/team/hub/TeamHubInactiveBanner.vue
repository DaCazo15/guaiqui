<script setup lang="ts">
defineProps<{
  teamName: string
}>()
</script>

<template>
  <div
    class="p-4 sm:p-5 rounded-2xl bg-amber-950/40 border-2 border-amber-500/50 text-amber-200 flex items-start gap-3.5 shadow-lg shadow-black/20"
    role="alert"
  >
    <div class="w-10 h-10 rounded-xl bg-amber-900/60 border border-amber-600/40 flex items-center justify-center text-amber-300 shrink-0 mt-0.5">
      <i class="bi bi-exclamation-triangle-fill text-xl"></i>
    </div>
    <div class="space-y-1">
      <h4 class="text-sm font-bold text-white uppercase tracking-wider">
        Equipo temporalmente no disponible
      </h4>
      <p class="text-xs text-amber-200/90 leading-relaxed">
        <strong>{{ teamName }}</strong> se encuentra inactivo actualmente. No es posible jugar nuevas trivias ni realizar canjes de premios para este equipo. Tu saldo de perlitas acumulado y tu historial de jugadas se mantienen completamente seguros.
      </p>
    </div>
  </div>
</template>
