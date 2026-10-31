<script setup lang="ts">
import { onMounted, nextTick } from 'vue'
import { useTenantSubdomain } from '~/composables/useTenantSubdomain'
import { useTeamLanding } from '~/composables/useTeamLanding'
import { useGSAP } from '~/composables/useGSAP'

// Componentes de Landing por Equipo (Subdominios)
import TeamLandingHeader from '~/components/team-landing/TeamLandingHeader.vue'
import TeamLandingAnnouncement from '~/components/team-landing/TeamLandingAnnouncement.vue'
import TeamLandingHero from '~/components/team-landing/TeamLandingHero.vue'
import TeamLandingRoster from '~/components/team-landing/TeamLandingRoster.vue'
import TeamLandingTrivias from '~/components/team-landing/TeamLandingTrivias.vue'
import TeamLandingStore from '~/components/team-landing/TeamLandingStore.vue'
import TeamLandingHistory from '~/components/team-landing/TeamLandingHistory.vue'
import TeamLandingFaq from '~/components/team-landing/TeamLandingFaq.vue'
import TeamLandingFooter from '~/components/team-landing/TeamLandingFooter.vue'

// Componentes de Landing de Plataforma
import Navbar from '~/components/landing/Navbar.vue'
import HeroSection from '~/components/landing/HeroSection.vue'
import FeaturedCarousel from '~/components/landing/FeaturedCarousel.vue'
import HowItWorksSection from '~/components/landing/HowItWorksSection.vue'
import AppShowcaseSection from '~/components/landing/AppShowcaseSection.vue'
import RewardsPreviewSection from '~/components/landing/RewardsPreviewSection.vue'
import StatsBand from '~/components/landing/StatsBand.vue'
import RosterPreviewSection from '~/components/landing/RosterPreviewSection.vue'
import StaffGridSection from '~/components/landing/StaffGridSection.vue'
import FaqSection from '~/components/landing/FaqSection.vue'
import FinalCtaSection from '~/components/landing/FinalCtaSection.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'

const { subdomain, isSubdomain } = useTenantSubdomain()
const {
  loading: teamLoading,
  team,
  announcement,
  rosterPreview,
  triviasPreview,
  productsPreview,
  milestones,
  faqs,
  fetchTeamLanding,
  applyTeamTheme
} = useTeamLanding()

// Si se detecta un subdominio de equipo, cargar sus datos atómicos
if (isSubdomain.value && subdomain.value) {
  await fetchTeamLanding(subdomain.value)
  if (team.value) {
    applyTeamTheme(team.value.primary_color, team.value.secondary_color)
  }
}

const { ScrollTrigger } = useGSAP()

onMounted(async () => {
  if (team.value) {
    applyTeamTheme(team.value.primary_color, team.value.secondary_color)
  }
  await nextTick()
  setTimeout(() => {
    ScrollTrigger?.refresh()
  }, 250)
})

// SEO Meta dinámico según contexto (subdominio o portal base)
useSeoMeta({
  title: () => team.value
    ? `${team.value.name} — Fan Zone Oficial`
    : 'Guaiqueríes de Margarita — Fan Zone Oficial & Plataforma de Fidelización',
  ogTitle: () => team.value
    ? `${team.value.name} — Fan Zone Oficial`
    : 'Guaiqueríes de Margarita — Fan Zone Oficial',
  description: () => team.value?.bio
    || 'Gana puntos respondiendo trivias y canjea camisas, entradas y premios reales de Guaiqueríes de Margarita.',
  ogDescription: () => team.value?.bio
    || 'La plataforma oficial de la tribu insular. 100% gratuita y sin dinero real.',
  ogType: 'website',
  ogImage: () => team.value?.logo_url || '/logo.png'
})
</script>

<template>
  <!-- Caso A: Navegación bajo Subdominio de Equipo (ej. guaiqueries.dominio.com) -->
  <div
    v-if="isSubdomain && team"
    class="min-h-screen bg-white text-gray-900 selection:bg-guaiqui-primary selection:text-white flex flex-col"
  >
    <TeamLandingAnnouncement :announcement="announcement" />
    <TeamLandingHeader :team="team" />
    <main class="flex-1">
      <TeamLandingHero :team="team" />
      <TeamLandingRoster :team="team" :roster="rosterPreview" />
      <TeamLandingTrivias :team="team" :trivias="triviasPreview" />
      <TeamLandingStore :team="team" :products="productsPreview" />
      <TeamLandingHistory :team="team" :milestones="milestones" />
      <TeamLandingFaq :team="team" :faqs="faqs" />
    </main>
    <TeamLandingFooter :team="team" />
  </div>

  <!-- Caso B: Navegación en Dominio Principal (ej. dominio.com o localhost:3000) -->
  <div
    v-else
    class="min-h-screen bg-guaiqui-bg text-guaiqui-text selection:bg-guaiqui-primary selection:text-white"
  >
    <Navbar />
    <HeroSection />
    <FinalCtaSection placement="after_hero" />
    <FeaturedCarousel />
    <HowItWorksSection />
    <AppShowcaseSection />
    <RewardsPreviewSection />
    <StatsBand />
    <RosterPreviewSection />
    <StaffGridSection />
    <FaqSection />
    <FinalCtaSection placement="before_footer" />
    <SiteFooter />
  </div>
</template>
