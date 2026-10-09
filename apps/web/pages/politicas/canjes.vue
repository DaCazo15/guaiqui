<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import { BaseCard } from '@guaiqui/ui'

useSeoMeta({
  title: 'Reglamento de Canjes y Entregas — Guaiqueríes de Margarita',
  description: 'Proceso de verificación QR, retiro de premios físicos y pases en el gimnasio.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <h1 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Reglamento de Canjes y Entregas
        </h1>
        <p class="text-xs text-guaiqui-text-muted">Protocolo oficial para retiro de recompensas</p>

        <BaseCard padding="lg" class="space-y-4 text-sm leading-relaxed text-guaiqui-text">
          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">1. Códigos QR Únicos e Idempotentes</h2>
            <p>Al confirmar un canje en la app, se debita el monto correspondiente y se genera un ticket digital con un código QR único en tu billetera. Este código contiene un token atómico firmado.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">2. Retiro Presencial en el Gimnasio</h2>
            <p>Los premios físicos (camisas, gorras, pases) se entregan exclusivamente en el módulo oficial del staff ubicado en el Gimnasio Ciudad de La Asunción, previa verificación del código QR y cédula de identidad del titular.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">3. Cancelaciones y Reembolsos</h2>
            <p>Si un canje es cancelado por falta de stock o caducidad, el reembolso se procesa insertando una entrada compensatoria positiva en tu historial de perlitas. Nunca se borran registros anteriores.</p>
          </section>
        </BaseCard>
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
