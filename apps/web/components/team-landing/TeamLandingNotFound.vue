<script setup lang="ts">
defineProps<{
  slug?: string
}>()
</script>

<template>
  <div class="min-h-[70vh] flex items-center justify-center px-4 py-16">
    <div class="max-w-md w-full bg-slate-900/80 border border-slate-800 rounded-3xl p-8 text-center space-y-5 shadow-2xl">
      <div class="w-16 h-16 mx-auto rounded-2xl bg-slate-800 border border-slate-700 text-slate-400 flex items-center justify-center text-3xl">
        <i class="bi bi-shield-x"></i>
      </div>

      <div class="space-y-2">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-500 font-sans">
          Error 404
        </span>
        <h1 class="text-2xl font-black font-title text-white">
          Equipo no encontrado
        </h1>
        <p class="text-xs sm:text-sm text-slate-400 leading-relaxed">
          No existe ninguna franquicia registrada con el identificador <code class="text-emerald-400 font-mono">/e/{{ slug }}</code>.
        </p>
      </div>

      <div class="pt-2">
        <NuxtLink
          to="/"
          class="inline-flex items-center justify-center gap-2 w-full py-3 px-5 rounded-xl font-bold bg-emerald-600 hover:bg-emerald-500 text-white transition-all text-sm shadow-lg shadow-emerald-950/30"
        >
          <i class="bi bi-grid-fill"></i>
          <span>Volver al Directorio de Equipos</span>
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
