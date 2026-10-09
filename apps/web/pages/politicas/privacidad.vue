<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import CookieConsentBanner from '~/components/landing/CookieConsentBanner.vue'
import { BaseCard } from '@guaiqui/ui'

useSeoMeta({
  title: 'Políticas de Privacidad — Guaiqueríes de Margarita',
  description: 'Políticas de privacidad, analítica de uso y protección de datos personales de la Fan Zone.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <h1 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Políticas de <span class="text-guaiqui-primary">Privacidad</span>
        </h1>
        <p class="text-xs text-guaiqui-text-muted">Versión 1.1 — Protección de Datos Personales y Analítica de Uso</p>

        <BaseCard padding="lg" class="space-y-4 text-sm leading-relaxed text-guaiqui-text">
          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">1. Recopilación de Datos</h2>
            <p>Respetamos tu privacidad. Tus datos personales se recopilan exclusivamente para gestionar tu cuenta de fanático, entregarte premios canjeados y personalizar tu experiencia deportiva.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">2. Seguridad y Acceso</h2>
            <p>Toda la información reside en servidores seguros con cifrado y políticas de control de acceso estrictas (Row Level Security). Nunca compartimos ni vendemos tu información personal con terceros.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">3. Derecho al Olvido y Supresión</h2>
            <p>En caso de solicitar la eliminación de tu cuenta en la sección de ajustes, tus datos identificables (nombre, correo, fecha de nacimiento) son anonimizados permanentemente para resguardar tu privacidad.</p>
          </section>

          <section class="border-t border-guaiqui-border pt-4">
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase flex items-center gap-2">
              <span>4. Analítica de Uso y Medición de Audiencia</span>
              <span class="text-[10px] bg-guaiqui-primary-soft text-guaiqui-primary px-2 py-0.5 rounded-full font-bold">Respeto a la Privacidad</span>
            </h2>
            <p class="mt-1">
              La plataforma utiliza servicios de analítica web (Vercel Web Analytics, Speed Insights y PostHog) para medir el rendimiento de la aplicación y comprender la participación de la fanaticada.
            </p>
            <ul class="list-disc list-inside mt-2 space-y-1 text-xs text-guaiqui-text-muted">
              <li><strong>Sin datos personales:</strong> Ningún evento recopila correos electrónicos, nombres, saldos de perlitas ni contraseñas.</li>
              <li><strong>Consentimiento previo:</strong> La analítica se activa únicamente si otorgas tu consentimiento en nuestro banner o ajustes.</li>
              <li><strong>Sin grabación de sesión:</strong> No realizamos grabaciones de pantalla ni seguimiento de pulsaciones de teclas.</li>
              <li><strong>Do Not Track:</strong> Respetamos la configuración de no rastreo de tu navegador.</li>
            </ul>
          </section>
        </BaseCard>
      </div>
    </main>

    <CookieConsentBanner />
    <SiteFooter />
  </div>
</template>
