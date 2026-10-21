<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import FaqSection from '~/components/landing/FaqSection.vue'

useSeoMeta({
  title: 'Preguntas Frecuentes — Guaiqueríes de Margarita',
  description: 'Centro de ayuda con las respuestas a todas tus dudas sobre puntos, trivias y canjes.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <FaqSection />
    </main>

    <SiteFooter />
  </div>
</template>
