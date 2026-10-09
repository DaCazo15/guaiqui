<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import { BaseCard } from '@guaiqui/ui'

useSeoMeta({
  title: 'Términos y Condiciones — Guaiqueríes de Margarita',
  description: 'Términos y condiciones oficiales del programa de fidelización Fan Zone.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <h1 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Términos y <span class="text-guaiqui-primary">Condiciones</span>
        </h1>
        <p class="text-xs text-guaiqui-text-muted">Versión 1.0 — Programa Oficial Guaiqueríes de Margarita Fan Zone</p>

        <BaseCard padding="lg" class="space-y-4 text-sm leading-relaxed text-guaiqui-text">
          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">1. Naturaleza del Programa</h2>
            <p>Bienvenido al programa de fidelización de Guaiqueríes de Margarita. Al registrarte y usar nuestra plataforma, aceptas estos Términos y Condiciones en su totalidad. La plataforma es un programa de fidelización sin costo de participación para los fanáticos.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">2. Perlitas y Moneda Virtual</h2>
            <p>Las perlitas son puntos virtuales de fidelización y no representan dinero ni valor monetario canjeable por efectivo. No existe venta de boletos ni transacciones con dinero real dentro de la aplicación.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">3. Elegibilidad y Uso de la Cuenta</h2>
            <p>Cada fanático puede tener una única cuenta activa. El uso de cuentas duplicadas o métodos automatizados para alterar los resultados de trivias conllevará a la suspensión de la cuenta.</p>
          </section>
        </BaseCard>
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
