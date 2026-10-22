<script setup lang="ts">
import { BaseBadge, PearlIcon } from '@guaiqui/ui'

const benefits = [
  {
    title: 'Acceso PWA Rápido e Instalable',
    desc: 'Guarda la app en la pantalla de inicio de tu celular sin descargar tiendas de aplicaciones pesadas.',
  },
  {
    title: 'Billetera Digital Inmutable de Puntos',
    desc: 'Tus saldo se almacena de forma segura e inalterable en la nube con respaldo de Supabase.',
  },
  {
    title: 'Notificaciones de Trivias en Vivo',
    desc: 'Recibe alertas instantáneas 15 minutos antes de cada partido para no perderte ningún punto.',
  },
  {
    title: 'Escáner QR de Canjes Instantáneo',
    desc: 'Muestra tu código QR en el gimnasio y el staff te entregará tu premio en segundos.',
  },
]
</script>

<template>
  <section class="py-16 sm:py-24 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
      <!-- Left Column: PWA App Mockup -->
      <div class="lg:col-span-5 flex justify-center">
        <div class="w-full max-w-xs bg-slate-950 p-4 rounded-[40px] shadow-2xl border-4 border-slate-800 text-white relative">
          <!-- Camera notch -->
          <div class="w-28 h-4 bg-slate-800 rounded-full mx-auto mb-4" />

          <!-- App Screen Mockup -->
          <div class="bg-guaiqui-bg text-guaiqui-text rounded-[28px] p-4 space-y-4 overflow-hidden text-xs">
            <div class="flex items-center justify-between border-b pb-2">
              <span class="font-display font-extrabold text-guaiqui-primary uppercase text-sm">Fan Zone</span>
              <BaseBadge variant="perlita" size="sm">1.500 Puntos</BaseBadge>
            </div>

            <div class="bg-guaiqui-primary-dark text-white p-3 rounded-guaiqui-lg text-center space-y-1">
              <div class="text-[10px] uppercase font-bold text-emerald-200">Trivia Diaria</div>
              <div class="font-display font-bold text-sm">Historia de la Tribu</div>
              <div class="text-[10px] text-amber-300 font-bold">+100 Puntos en juego</div>
            </div>

            <div class="bg-white border rounded-guaiqui-md p-2 flex items-center justify-between">
              <div class="flex items-center gap-2">
                <PearlIcon size="xs" />
                <span class="font-bold text-[11px]">Recompensas Oficiales</span>
              </div>
              <span class="text-guaiqui-primary font-bold text-[10px]">Canjear</span>
            </div>

            <div class="bg-gray-100 p-2 rounded-guaiqui-md text-center text-[10px] text-gray-500 flex items-center justify-center gap-1.5">
              <i class="bi bi-phone"></i>
              <span>App Web Progresiva para iOS y Android</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Right Column: Benefits & Privacy -->
      <div class="lg:col-span-7 space-y-8">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest">Experiencia Digital</span>
          <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight mt-1">
            Diseñada exclusivamente para la fanaticada insular
          </h2>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div v-for="(b, i) in benefits" :key="i" class="space-y-2">
            <div class="w-8 h-8 rounded-guaiqui-md bg-guaiqui-primary-soft text-guaiqui-primary font-bold flex items-center justify-center text-sm">
              <i class="bi bi-check-lg"></i>
            </div>
            <h3 class="font-display font-bold text-lg text-guaiqui-text">
              {{ b.title }}
            </h3>
            <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed">
              {{ b.desc }}
            </p>
          </div>
        </div>

        <!-- Privacy & Security Guarantee -->
        <div class="bg-white p-4 rounded-guaiqui-lg border border-guaiqui-border flex items-center gap-4 shadow-xs">
          <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-lg flex-shrink-0">
            <i class="bi bi-shield-lock-fill"></i>
          </div>
          <div class="text-xs">
            <div class="font-bold text-guaiqui-text">Compromiso de Privacidad y Seguridad</div>
            <div class="text-guaiqui-text-muted">Tus datos nunca son compartidos con terceros ni monetizados. La app cumple estrictamente las normas de protección de datos.</div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
