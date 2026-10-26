<script setup lang="ts">
import { PearlIcon } from '@guaiqui/ui'
import BandanaSeparator from './BandanaSeparator.vue'
</script>

<template>
  <footer class="bg-slate-950 text-white font-body border-t border-slate-800">
    <BandanaSeparator />

    <div class="max-w-6xl mx-auto px-4 sm:px-8 py-12 grid grid-cols-1 md:grid-cols-4 gap-8">
      <!-- Col 1: Brand -->
      <div class="space-y-4 md:col-span-1">
        <NuxtLink to="/" class="flex items-center gap-2 text-white font-display font-extrabold text-xl tracking-tight uppercase">
          <span class="w-8 h-8 rounded-full bg-guaiqui-primary text-white flex items-center justify-center font-bold text-sm">
            G
          </span>
          <span class="flex items-center gap-1">
            <span>GUAIQUERÍES</span>
            <PearlIcon size="xs" />
          </span>
        </NuxtLink>

        <p class="text-xs text-slate-400 leading-relaxed">
          Plataforma oficial de fidelización de Guaiqueríes de Margarita. Fan Zone 2026.
        </p>

        <div class="text-xs text-emerald-400 font-semibold flex items-center gap-1.5">
          <i class="bi bi-geo-alt-fill"></i>
          <span>Gimnasio Ciudad de La Asunción, Nueva Esparta</span>
        </div>
      </div>

      <!-- Col 2: Navegación -->
      <div class="space-y-3">
        <h4 class="font-display font-bold text-sm text-amber-400 uppercase tracking-wider">
          Navegación
        </h4>
        <ul class="space-y-2 text-xs text-slate-300">
          <li><NuxtLink to="/" class="hover:text-emerald-400 transition-colors">Inicio</NuxtLink></li>
          <li><NuxtLink to="/#como-funciona" class="hover:text-emerald-400 transition-colors">La App</NuxtLink></li>
          <li><NuxtLink to="/salon-de-la-fama" class="hover:text-emerald-400 transition-colors">Salón de la Fama</NuxtLink></li>
          <li><NuxtLink to="/historia" class="hover:text-emerald-400 transition-colors">Historia de la Tribu</NuxtLink></li>
          <li><NuxtLink to="/plantilla" class="hover:text-emerald-400 transition-colors">Plantilla de Jugadores</NuxtLink></li>
          <li><NuxtLink to="/equipo-de-trabajo" class="hover:text-emerald-400 transition-colors">Cuerpo Técnico y Directiva</NuxtLink></li>
        </ul>
      </div>

      <!-- Col 3: Políticas -->
      <div class="space-y-3">
        <h4 class="font-display font-bold text-sm text-amber-400 uppercase tracking-wider">
          Políticas & Legales
        </h4>
        <ul class="space-y-2 text-xs text-slate-300">
          <li><NuxtLink to="/politicas/terminos" class="hover:text-emerald-400 transition-colors">Términos y Condiciones</NuxtLink></li>
          <li><NuxtLink to="/politicas/privacidad" class="hover:text-emerald-400 transition-colors">Política de Privacidad</NuxtLink></li>
          <li><NuxtLink to="/politicas/perlitas" class="hover:text-emerald-400 transition-colors">Reglas de la Economía de Puntos</NuxtLink></li>
          <li><NuxtLink to="/politicas/canjes" class="hover:text-emerald-400 transition-colors">Reglamento de Canje y Entregas</NuxtLink></li>
          <li><button class="hover:text-emerald-400 transition-colors text-left font-medium" @click="useAnalytics().setConsent(false)">Configuración de Cookies</button></li>
          <li><NuxtLink to="/faq" class="hover:text-emerald-400 transition-colors">Preguntas Frecuentes (FAQ)</NuxtLink></li>
        </ul>
      </div>

      <!-- Col 4: Contacto -->
      <div class="space-y-3">
        <h4 class="font-display font-bold text-sm text-amber-400 uppercase tracking-wider">
          Atención al Fanático
        </h4>
        <p class="text-xs text-slate-300">
          ¿Tienes alguna duda sobre tus puntos o tu canje?
        </p>
        <NuxtLink to="/contacto" class="inline-block text-xs font-semibold text-emerald-400 hover:underline">
          Contactar con Soporte →
        </NuxtLink>
        <div class="pt-2 text-[11px] text-slate-400">
          Atención presencial en días de juego: 4:00 PM a 9:00 PM.
        </div>
      </div>
    </div>

    <!-- Subfooter copyright -->
    <div class="border-t border-slate-900 bg-slate-950 py-4 px-4 text-center text-xs text-slate-500">
      <div class="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-2">
        <span>© 2026 Guaiqueríes de Margarita. Todos los derechos reservados.</span>
        <span>Sin pagos con dinero real • 100% Fidelización Gratuita</span>
      </div>
    </div>
  </footer>
</template>
