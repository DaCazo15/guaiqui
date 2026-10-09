<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import HistoryTimelineSection from '~/components/landing/HistoryTimelineSection.vue'

useSeoMeta({
  title: 'Historia de Guaiqueríes de Margarita — 80 Años de Gloria',
  description: 'Conoce los 80 años de historia, pentacampeonato y la leyenda del club de baloncesto de Nueva Esparta.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-4xl mx-auto space-y-8">
        <div class="space-y-3">
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Orgullo Insular
          </span>
          <h1 class="font-display font-extrabold text-4xl sm:text-5xl text-guaiqui-text uppercase">
            80 Años de Pasión e Historia
          </h1>
          <p class="text-base text-guaiqui-text-muted leading-relaxed">
            Fundado en La Asunción, Guaiqueríes de Margarita es uno de los clubes más venerados en la historia del baloncesto venezolano, símbolo indiscutible del estado Nueva Esparta.
          </p>
        </div>

        <HistoryTimelineSection />
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
