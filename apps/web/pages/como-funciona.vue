<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import HowItWorksSection from '~/components/landing/HowItWorksSection.vue'
import AppShowcaseSection from '~/components/landing/AppShowcaseSection.vue'

useSeoMeta({
  title: '¿Cómo Funciona? — Fan Zone Guaiqueríes de Margarita',
  description: 'Aprende a jugar trivias, ganar perlitas y canjear tus premios sin pagar un solo bolívar.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="space-y-12">
      <HowItWorksSection />
      <AppShowcaseSection />
    </main>

    <SiteFooter />
  </div>
</template>
