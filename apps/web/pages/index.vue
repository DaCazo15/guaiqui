<script setup lang="ts">
import { onMounted } from 'vue'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import PlatformHero from '~/components/platform-landing/PlatformHero.vue'
import PlatformTeamsGrid from '~/components/platform-landing/PlatformTeamsGrid.vue'
import PlatformHowItWorks from '~/components/platform-landing/PlatformHowItWorks.vue'
import PlatformStats from '~/components/platform-landing/PlatformStats.vue'
import PlatformCta from '~/components/platform-landing/PlatformCta.vue'
import { usePlatformLanding } from '~/composables/usePlatformLanding'

const { platformData, searchResults, loading, searchTeams, fetchPlatformLanding } = usePlatformLanding()

onMounted(async () => {
  await fetchPlatformLanding()
})

const handleSearch = (query: string) => {
  searchTeams(query)
}

// SEO Meta
useSeoMeta({
  title: 'Fan Zone — Plataforma Oficial de Fidelización de Baloncesto Profesional',
  ogTitle: 'Fan Zone — Fidelización & Premios Oficiales',
  description: 'Elige tu franquicia de baloncesto, responde trivias oficiales, acumula perlitas virtuales y canjea premios reales sin costo.',
  ogDescription: 'La plataforma oficial multi-equipo para los fanáticos del baloncesto profesional. 100% gratuita y sin dinero real.',
  ogType: 'website',
})
</script>

<template>
  <div class="min-h-screen bg-slate-950 text-slate-100 selection:bg-emerald-600 selection:text-white">
    <!-- 1. Navbar Sticky -->
    <Navbar />

    <!-- 2. Platform Hero & Search -->
    <PlatformHero
      :total-teams="platformData?.totals.total_teams ?? 1"
      :total-fans="platformData?.totals.total_fans ?? 0"
      @search="handleSearch"
    />

    <!-- 3. Platform Stats Band -->
    <PlatformStats :totals="platformData?.totals" />

    <!-- 4. Active Teams Grid -->
    <PlatformTeamsGrid
      :teams="searchResults"
      :loading="loading"
    />

    <!-- 5. How It Works -->
    <PlatformHowItWorks />

    <!-- 6. Registration CTA -->
    <PlatformCta />

    <!-- 7. Footer -->
    <SiteFooter />
  </div>
</template>
