<script setup lang="ts">
import AnnouncementBar from '~/components/landing/AnnouncementBar.vue'
import Navbar from '~/components/landing/Navbar.vue'
import HeroSection from '~/components/landing/HeroSection.vue'
import FeaturedCarousel from '~/components/landing/FeaturedCarousel.vue'
import HowItWorksSection from '~/components/landing/HowItWorksSection.vue'
import AppShowcaseSection from '~/components/landing/AppShowcaseSection.vue'
import RewardsPreviewSection from '~/components/landing/RewardsPreviewSection.vue'
import StatsBand from '~/components/landing/StatsBand.vue'
import RosterPreviewSection from '~/components/landing/RosterPreviewSection.vue'
import HistoryTimelineSection from '~/components/landing/HistoryTimelineSection.vue'
import StaffGridSection from '~/components/landing/StaffGridSection.vue'
// import CommunityBlock from '~/components/landing/CommunityBlock.vue'
import FaqSection from '~/components/landing/FaqSection.vue'
import FinalCtaSection from '~/components/landing/FinalCtaSection.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import InstagramSection from '~/components/landing/InstagramSection.vue'

// SEO Meta
useSeoMeta({
  title: 'Guaiqueríes de Margarita — Fan Zone Oficial & Plataforma de Fidelización',
  ogTitle: 'Guaiqueríes de Margarita — Fan Zone Oficial',
  description: 'Gana perlitas respondiendo trivias y canjea camisas, entradas y premios reales de Guaiqueríes de Margarita.',
  ogDescription: 'La plataforma oficial de la tribu insular. 100% gratuita y sin dinero real.',
  ogType: 'website',
})
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text selection:bg-guaiqui-primary selection:text-white">
    <!-- 1. AnnouncementBar -->
    <AnnouncementBar />

    <!-- 2. Navbar Sticky -->
    <Navbar />

    <!-- 3. HeroSection -->
    <HeroSection />

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

    <!-- 10. HistoryTimeline -->
    <HistoryTimelineSection />

    <!-- 11. StaffGrid -->
    <StaffGridSection />

    <!-- 12. CommunityBlock -->
    <!-- <CommunityBlock /> -->

    <!-- 13. FaqAccordion -->
    <FaqSection />

    <!-- 14. Instagram Mosaic -->
    <InstagramSection />

    <!-- 15. FinalCta & SiteFooter -->
    <FinalCtaSection />
    <SiteFooter />
  </div>
</template>
