<script setup lang="ts">
const emit = defineEmits<{
  (e: 'close'): void
}>()
</script>

<template>
  <div class="py-8 px-4 text-center">
    <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-500 shadow-inner">
      <i class="bi bi-shield-slash text-3xl"></i>
    </div>
    <h3 class="text-base font-bold text-white mb-2">
      No sigues a ningún equipo todavía
    </h3>
    <p class="text-xs text-slate-400 max-w-sm mx-auto mb-6 leading-relaxed">
      Cada equipo tiene su propia moneda de perlitas, trivias diarias y catálogo de premios. Sigue a tus equipos favoritos para comenzar.
    </p>
    <NuxtLink
      to="/app/equipos"
      @click="emit('close')"
      class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-display font-bold uppercase tracking-wider text-sm bg-emerald-500 hover:bg-emerald-400 text-slate-950 transition-colors shadow-lg shadow-emerald-950/40"
    >
      <i class="bi bi-search text-sm"></i>
      <span>Explorar Equipos</span>
    </NuxtLink>
  </div>
</template>
