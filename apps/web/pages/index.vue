<script setup lang="ts">
import { onMounted } from 'vue'
import PlatformNavbar from '~/components/platform-landing/PlatformNavbar.vue'
import PlatformFooter from '~/components/platform-landing/PlatformFooter.vue'
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
  title: 'FanActivo — Plataforma Oficial de Fidelización de Baloncesto Profesional',
  ogTitle: 'FanActivo — Fidelización & Premios Oficiales',
  description: 'Elige tu franquicia de baloncesto, responde trivias oficiales, acumula perlitas virtuales y canjea premios reales sin costo.',
  ogDescription: 'La plataforma oficial multi-equipo para los fanáticos del baloncesto profesional. 100% gratuita y sin dinero real.',
  ogType: 'website',
})
</script>

<template>
  <div class="min-h-screen bg-[#071318] text-slate-100 selection:bg-orange-500 selection:text-white">
    <!-- 1. Navbar Sticky: FanActivo -->
    <PlatformNavbar />

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

    <!-- 7. Footer: FanActivo -->
    <PlatformFooter />
  </div>
</template>
