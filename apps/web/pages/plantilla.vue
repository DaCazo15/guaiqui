<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import RosterPreviewSection from '~/components/landing/RosterPreviewSection.vue'

useSeoMeta({
  title: 'Plantilla Oficial 2026 — Guaiqueríes de Margarita',
  description: 'Revisa la plantilla completa de jugadores para la temporada 2026 de la SPB.',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main class="py-12 px-4 sm:px-8">
      <div class="max-w-6xl mx-auto space-y-8">
        <div class="space-y-3 text-center max-w-2xl mx-auto">
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Nuestros Jugadores
          </span>
          <h1 class="font-display font-extrabold text-4xl sm:text-5xl text-guaiqui-text uppercase">
            Plantilla Oficial 2026
          </h1>
          <p class="text-base text-guaiqui-text-muted">
            Los guerreros verdes que defienden la camiseta insular en la cancha.
          </p>
        </div>

        <RosterPreviewSection />
      </div>
    </main>

    <SiteFooter />
  </div>
</template>
