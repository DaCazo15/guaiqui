<script setup lang="ts">
import { useSupabaseUser } from '#imports'

const user = useSupabaseUser()
</script>

<template>
  <section class="py-16 sm:py-24 bg-gradient-to-b from-[#071318] to-[#0c202a] text-white border-b border-cyan-950/80">
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-6">
      <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-orange-500/10 border border-orange-500/20 text-orange-400 text-xs font-bold tracking-wide uppercase">
        <i class="bi bi-lightning-charge-fill"></i>
        <span>Comienza hoy mismo en FanActivo</span>
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
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white transition-all shadow-lg shadow-orange-950/40 text-sm sm:text-base"
        >
          <span>Crear Cuenta Gratis</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>
        <NuxtLink
          v-else
          to="/app"
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white transition-all shadow-lg shadow-orange-950/40 text-sm sm:text-base"
        >
          <span>Ir a Mi Panel de Fanático</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>

        <a
          href="#equipos"
          class="inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl font-bold bg-cyan-950/70 hover:bg-cyan-900/70 text-cyan-200 border border-cyan-800/80 transition-all text-sm sm:text-base"
        >
          <span>Ver Clubes Disponibles</span>
          <i class="bi bi-grid-fill text-cyan-400"></i>
        </a>
      </div>
    </div>
  </section>
</template>
