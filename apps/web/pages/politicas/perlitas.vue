<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import { BaseCard } from '@guaiqui/ui'

useSeoMeta({
  title: 'Reglas del Programa de Puntos — Guaiqueríes de Margarita',
  description: 'Reglamento oficial para la obtención, límites y canje de puntos.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <h1 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
          Reglas del Programa de <span class="text-guaiqui-primary">Puntos</span>
        </h1>
        <p class="text-xs text-guaiqui-text-muted">Versión 1.0 — Economía y Recompensas de la Tribu</p>

        <BaseCard padding="lg" class="space-y-4 text-sm leading-relaxed text-guaiqui-text">
          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">1. Obtención de Puntos</h2>
            <p>Los puntos se ganan exclusivamente respondiendo trivias y participando en dinámicas interactivas del club. Las respuestas correctas acreditan puntos según las reglas de cada trivia.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">2. Límites y Reglas de la Economía</h2>
            <p>Existe un límite diario y semanal de puntos acumulables para garantizar un juego justo. Las rachas de días consecutivos otorgan bonos adicionales.</p>
          </section>

          <section>
            <h2 class="font-display font-bold text-lg text-guaiqui-primary uppercase">3. Prohibición de Fraude</h2>
            <p>Está estrictamente prohibido el uso de scripts, bots o múltiples cuentas para acumular puntos. Cualquier conducta sospechosa anulará los canjes y suspenderá la cuenta.</p>
          </section>
        </BaseCard>
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
