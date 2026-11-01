<script setup lang="ts">
import { useSupabaseUser } from '#imports'

const user = useSupabaseUser()
</script>

<template>
  <section class="py-16 sm:py-24 bg-gradient-to-b from-slate-950 to-emerald-950/60 text-white border-b border-slate-800">
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-6">
      <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-bold tracking-wide uppercase">
        <i class="bi bi-lightning-charge-fill"></i>
        <span>Comienza hoy mismo</span>
      </div>

      <h2 class="text-3xl sm:text-5xl font-black font-title tracking-tight text-white leading-tight">
        Únete a la Fan Zone y Lleva los Colores de tu Club al Siguiente Nivel
      </h2>

      <p class="text-sm sm:text-base text-slate-300 max-w-xl mx-auto font-sans">
        Crea tu cuenta gratuita en menos de 1 minuto, gana tus primeras perlitas y compite por premios exclusivos en cada partido.
      </p>

      <div class="pt-4 flex flex-col sm:flex-row items-center justify-center gap-4">
        <NuxtLink
          v-if="!user"
          to="/registro"
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-emerald-600 hover:bg-emerald-500 text-white transition-all shadow-lg shadow-emerald-900/40 text-sm sm:text-base"
        >
          <span>Crear Cuenta Gratis</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>
        <NuxtLink
          v-else
          to="/app"
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-emerald-600 hover:bg-emerald-500 text-white transition-all shadow-lg shadow-emerald-900/40 text-sm sm:text-base"
        >
          <span>Ir a Mi Panel de Fanático</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>

        <a
          href="#equipos"
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-slate-900/90 hover:bg-slate-800 text-slate-200 border border-slate-700 transition-all text-sm sm:text-base"
        >
          <span>Ver Clubes Disponibles</span>
          <i class="bi bi-grid-fill"></i>
        </a>
      </div>
    </div>
  </section>
</template>
