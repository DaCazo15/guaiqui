<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import BandanaSeparator from '~/components/landing/BandanaSeparator.vue'
import HallOfFameHero from '~/components/hall-of-fame/HallOfFameHero.vue'
import HallOfFameJerseys from '~/components/hall-of-fame/HallOfFameJerseys.vue'
import HallOfFameLegends from '~/components/hall-of-fame/HallOfFameLegends.vue'
import HallOfFameTrophies from '~/components/hall-of-fame/HallOfFameTrophies.vue'
import { BaseButton } from '@guaiqui/ui'

useSeoMeta({
  title: 'Salón de la Fama — Guaiqueríes de Margarita',
  description: 'Conoce los 6 dorsales retirados, leyendas inmortales y los 9 campeonatos que consagraron a la Tribu Verde de Nueva Esparta.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main>
      <HallOfFameHero />
      <BandanaSeparator />
      <HallOfFameJerseys />
      <HallOfFameLegends />
      <HallOfFameTrophies />

      <!-- Interactive Trivia CTA Section -->
      <section class="py-14 sm:py-20 bg-white px-4 sm:px-8 border-t border-guaiqui-border text-center">
        <div class="max-w-3xl mx-auto space-y-6">
          <div class="w-14 h-14 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary mx-auto flex items-center justify-center text-2xl border border-guaiqui-primary/30">
            <i class="bi bi-patch-question-fill"></i>
          </div>

          <div class="space-y-2">
            <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase">
              ¿Cuánto sabes sobre estas leyendas?
            </h2>
            <p class="text-sm sm:text-base text-guaiqui-text-muted leading-relaxed">
              Demuestra tu pasión por la Tribu Verde jugando trivias diarias en la aplicación oficial y gana perlitas para canjear por premios reales.
            </p>
          </div>

          <div class="pt-2 flex flex-wrap items-center justify-center gap-3">
            <NuxtLink to="/app/trivias">
              <BaseButton variant="primary" size="lg">
                <i class="bi bi-play-circle-fill mr-2"></i>
                <span>Jugar Trivias Ahora</span>
              </BaseButton>
            </NuxtLink>
            <NuxtLink to="/historia">
              <BaseButton variant="outline" size="lg">
                <span>Ver Historia Completa</span>
                <i class="bi bi-arrow-right ml-2"></i>
              </BaseButton>
            </NuxtLink>
          </div>
        </div>
      </section>
    </main>

    <SiteFooter />
  </div>
</template>
