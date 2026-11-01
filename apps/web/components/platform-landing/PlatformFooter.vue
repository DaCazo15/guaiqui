<script setup lang="ts">
const currentYear = new Date().getFullYear()
</script>

<template>
  <footer class="bg-[#050e12] text-slate-300 font-body border-t border-cyan-950/80">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16 grid grid-cols-1 md:grid-cols-4 gap-8">
      <!-- Col 1: Brand & Desc -->
      <div class="space-y-4 md:col-span-2">
        <div class="flex items-center gap-2.5 font-title font-black text-2xl tracking-tight text-white">
          <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-white shadow-md shadow-orange-500/20">
            <i class="bi bi-fire text-base"></i>
          </div>
          <div class="flex items-baseline gap-1">
            <span class="text-white">FAN</span>
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-amber-400">ACTIVO</span>
          </div>
        </div>

        <p class="text-xs sm:text-sm text-slate-400 max-w-sm leading-relaxed">
          Plataforma multi-equipo de fidelización y gamificación deportiva. Respaldamos la conexión directa entre clubes oficiales y sus verdaderos fanáticos.
        </p>

        <div class="pt-2">
          <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-950/80 border border-cyan-800/40 text-cyan-300 text-xs font-semibold">
            <i class="bi bi-shield-lock-fill"></i>
            <span>100% Gratuito • Sin apuestas ni dinero real</span>
          </span>
        </div>
      </div>

      <!-- Col 2: Enlaces Rápidos -->
      <div class="space-y-3">
        <h4 class="text-sm font-bold uppercase tracking-wider text-white font-title">
          Plataforma
        </h4>
        <ul class="space-y-2 text-xs sm:text-sm text-slate-400">
          <li>
            <a href="#equipos" class="hover:text-orange-400 transition-colors">Clubes Oficiales</a>
          </li>
          <li>
            <a href="#como-funciona" class="hover:text-cyan-400 transition-colors">¿Cómo Funciona?</a>
          </li>
          <li>
            <NuxtLink to="/registro" class="hover:text-orange-400 transition-colors">Crear Cuenta</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/login" class="hover:text-cyan-400 transition-colors">Iniciar Sesión</NuxtLink>
          </li>
        </ul>
      </div>

      <!-- Col 3: Legal y Soporte -->
      <div class="space-y-3">
        <h4 class="text-sm font-bold uppercase tracking-wider text-white font-title">
          Transparencia
        </h4>
        <ul class="space-y-2 text-xs sm:text-sm text-slate-400">
          <li>
            <NuxtLink to="/politicas/terminos" class="hover:text-slate-200 transition-colors">Términos de Uso</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/politicas/privacidad" class="hover:text-slate-200 transition-colors">Política de Privacidad</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/politicas/reglas-juego" class="hover:text-slate-200 transition-colors">Reglas del Juego</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/faq" class="hover:text-slate-200 transition-colors">Preguntas Frecuentes</NuxtLink>
          </li>
        </ul>
      </div>
    </div>

    <!-- Bottom copyright -->
    <div class="border-t border-cyan-950/60 py-6 text-center text-xs text-slate-400">
      <div class="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-3">
        <p>© {{ currentYear }} FanActivo. Todos los derechos reservados.</p>
        <p class="text-[11px] text-slate-400">Las marcas y logotipos de cada equipo pertenecen a sus respectivas franquicias.</p>
      </div>
    </div>
  </footer>
</template>
