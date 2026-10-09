<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import StaffGridSection from '~/components/landing/StaffGridSection.vue'

useSeoMeta({
  title: 'Cuerpo Técnico y Directiva — Guaiqueríes de Margarita',
  description: 'Conoce al equipo de dirección, cuerpo técnico y logística de la tribu insular.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-6xl mx-auto space-y-8">
        <StaffGridSection />
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
