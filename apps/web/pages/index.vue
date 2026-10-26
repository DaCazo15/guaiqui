<script setup lang="ts">
import Navbar from '~/components/landing/Navbar.vue'
import HeroSection from '~/components/landing/HeroSection.vue'
import FeaturedCarousel from '~/components/landing/FeaturedCarousel.vue'
import HowItWorksSection from '~/components/landing/HowItWorksSection.vue'
import AppShowcaseSection from '~/components/landing/AppShowcaseSection.vue'
import RewardsPreviewSection from '~/components/landing/RewardsPreviewSection.vue'
import StatsBand from '~/components/landing/StatsBand.vue'
import RosterPreviewSection from '~/components/landing/RosterPreviewSection.vue'
import StaffGridSection from '~/components/landing/StaffGridSection.vue'
// import CommunityBlock from '~/components/landing/CommunityBlock.vue'
import FaqSection from '~/components/landing/FaqSection.vue'
import FinalCtaSection from '~/components/landing/FinalCtaSection.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'

import { onMounted, nextTick } from 'vue'
import { useGSAP } from '~/composables/useGSAP'

const { ScrollTrigger } = useGSAP()

onMounted(async () => {
  await nextTick()
  setTimeout(() => {
    ScrollTrigger?.refresh()
  }, 250)
})

// SEO Meta
useSeoMeta({
  title: 'Guaiqueríes de Margarita — Fan Zone Oficial & Plataforma de Fidelización',
  ogTitle: 'Guaiqueríes de Margarita — Fan Zone Oficial',
  description: 'Gana puntos respondiendo trivias y canjea camisas, entradas y premios reales de Guaiqueríes de Margarita.',
  ogDescription: 'La plataforma oficial de la tribu insular. 100% gratuita y sin dinero real.',
  ogType: 'website',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text selection:bg-guaiqui-primary selection:text-white">
    <!-- 1. Navbar Sticky -->
    <Navbar />

    <!-- 2. HeroSection (includes integrated AnnouncementBar) -->
    <HeroSection />

    <!-- 3.1 Optional CTA after Hero -->
    <FinalCtaSection placement="after_hero" />

    <!-- 4. FeaturedCarousel -->
    <FeaturedCarousel />

    <!-- 5. HowItWorks -->
    <HowItWorksSection />

    <!-- 6. AppShowcase -->
    <AppShowcaseSection />

    <!-- 7. RewardsPreview -->
    <RewardsPreviewSection />

    <!-- 8. StatsBand -->
    <StatsBand />

    <!-- 9. RosterPreview -->
    <RosterPreviewSection />

    <!-- 10. StaffGrid -->
    <StaffGridSection />

    <!-- 12. CommunityBlock -->
    <!-- <CommunityBlock /> -->

    <!-- 13. FaqAccordion -->
    <FaqSection />

    <!-- 14. FinalCta & SiteFooter -->
    <FinalCtaSection placement="before_footer" />
    <SiteFooter />
  </div>
</template>
