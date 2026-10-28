<script setup lang="ts">
// AuthBasketballHorizon.vue
// Visual hero with rotating 3D basketball peeking at the horizon
</script>

<template>
  <div class="relative w-full flex flex-col items-center justify-between pt-8 pb-12 sm:pt-12 sm:pb-16 md:pt-14 md:pb-20 text-center select-none overflow-visible">
    <!-- Ambient glowing backdrop aura -->
    <div class="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 sm:w-80 sm:h-80 md:w-96 md:h-96 bg-emerald-500/20 rounded-full blur-3xl pointer-events-none"></div>

    <!-- Club Brand & Pill -->
    <div class="relative z-10 flex flex-col items-center gap-2 mb-3">
      <div class="w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 rounded-2xl bg-slate-900/60 p-2 sm:p-2.5 border border-emerald-500/30 shadow-lg backdrop-blur-md flex items-center justify-center">
        <img src="/logo.png" alt="Guaiqueríes de Margarita" class="w-full h-full object-contain" />
      </div>
      <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-950/70 border border-emerald-500/30 text-[11px] sm:text-xs font-mono uppercase tracking-widest text-emerald-300 shadow-sm backdrop-blur-sm">
        <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
        <span>Guaiqueríes de Margarita</span>
      </div>
    </div>

    <!-- Main Branding Title: FAN ACTIVO -->
    <div class="relative z-10 space-y-1.5 px-4 mb-6">
      <h1 class="font-display text-4xl sm:text-5xl md:text-6xl font-black uppercase tracking-wider text-white leading-none">
        Fan <span class="text-emerald-400 drop-shadow-[0_0_20px_rgba(52,211,153,0.5)]">Activo</span>
      </h1>
      <p class="text-xs sm:text-sm md:text-base text-slate-300/90 font-medium max-w-xs sm:max-w-sm md:max-w-md mx-auto">
        Trivias, predicciones y perlitas para la verdadera Tribu insular
      </p>
    </div>

    <!-- 3D Basketball Spinning on the Horizon (Only Top Half Visible) -->
    <!-- translate-y-1/2 ensures the bottom half crosses the boundary to be covered by the curved sheet -->
    <div class="absolute -bottom-16 sm:-bottom-20 md:-bottom-[88px] left-1/2 -translate-x-1/2 z-0 pointer-events-none">
      <!-- Glow halo under/around ball -->
      <div class="absolute inset-0 rounded-full bg-emerald-400/25 blur-xl scale-110"></div>
      
      <!-- Ball container with circular clipping -->
      <div class="relative w-32 h-32 sm:w-40 sm:h-40 md:w-44 md:h-44 rounded-full shadow-[0_12px_36px_rgba(0,0,0,0.8)] border border-emerald-500/30 overflow-hidden bg-slate-950">
        <!-- Rotating ball image -->
        <img
          src="/images/basketball.jpg"
          alt="Balón Fan Activo"
          class="w-full h-full object-cover scale-110 basketball-spin"
        />

        <!-- 3D spherical shading and light reflection overlay -->
        <div class="absolute inset-0 rounded-full pointer-events-none sphere-light"></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.basketball-spin {
  animation: spinBasketball 12s linear infinite;
  transform-origin: center center;
}

@keyframes spinBasketball {
  from {
    transform: scale(1.1) rotate(0deg);
  }
  to {
    transform: scale(1.1) rotate(360deg);
  }
}

/* Realistic 3D rim reflection and sphere depth */
.sphere-light {
  background: radial-gradient(
    circle at 35% 30%,
    rgba(255, 255, 255, 0.35) 0%,
    rgba(255, 255, 255, 0.05) 30%,
    rgba(0, 0, 0, 0.2) 65%,
    rgba(0, 0, 0, 0.8) 100%
  );
  box-shadow: inset 0 2px 6px rgba(255, 255, 255, 0.4), inset 0 -6px 12px rgba(0, 0, 0, 0.8);
}

@media (prefers-reduced-motion: reduce) {
  .basketball-spin {
    animation: none;
  }
}
</style>
