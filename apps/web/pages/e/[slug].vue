<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import TeamLandingHero from '~/components/team-landing/TeamLandingHero.vue'
import TeamLandingTrivias from '~/components/team-landing/TeamLandingTrivias.vue'
import TeamLandingRanking from '~/components/team-landing/TeamLandingRanking.vue'
import TeamLandingStore from '~/components/team-landing/TeamLandingStore.vue'
import TeamLandingInactive from '~/components/team-landing/TeamLandingInactive.vue'
import TeamLandingNotFound from '~/components/team-landing/TeamLandingNotFound.vue'
import { useTeamLanding } from '~/composables/useTeamLanding'

const route = useRoute()
const slug = computed(() => (route.params.slug as string) || '')

const {
  landingData,
  loading,
  actionLoading,
  isNotFound,
  isInactive,
  isActive,
  fetchTeamLanding,
  toggleFollow
} = useTeamLanding()

// Carga inicial
await fetchTeamLanding(slug.value)

onMounted(async () => {
  if (!landingData.value) {
    await fetchTeamLanding(slug.value)
  }
})

// SEO & Metadatos
useSeoMeta({
  title: () =>
    landingData.value?.team
      ? `${landingData.value.team.name} — Fan Zone Oficial`
      : 'Fan Zone de Franquicia Oficial',
  ogTitle: () =>
    landingData.value?.team
      ? `${landingData.value.team.name} — Fan Zone Oficial`
      : 'Fan Zone Oficial',
  description: () =>
    landingData.value?.content?.hero_subtitle ||
    'Responde trivias oficiales, gana perlitas virtuales y canjea premios reales sin costo.',
  ogDescription: () =>
    landingData.value?.content?.hero_subtitle ||
    'La comunidad oficial de fanáticos de este club. 100% gratuita y sin dinero real.',
  ogImage: () =>
    landingData.value?.team?.logo_url ||
    landingData.value?.content?.hero_image_url ||
    '/logo.png',
  ogType: 'website'
})
</script>

<template>
  <div class="min-h-screen bg-slate-950 text-slate-100 selection:bg-emerald-600 selection:text-white flex flex-col justify-between">
    <div>
      <!-- Header -->
      <Navbar />

      <!-- Loading State -->
      <div v-if="loading" class="py-24 text-center max-w-xl mx-auto space-y-4">
        <div class="w-12 h-12 mx-auto rounded-full border-2 border-emerald-500 border-t-transparent animate-spin"></div>
        <p class="text-xs sm:text-sm text-slate-400">Cargando Fan Zone del equipo...</p>
      </div>

      <!-- 404: Not Found -->
      <TeamLandingNotFound
        v-else-if="isNotFound"
        :slug="slug"
      />

      <!-- Inactive Team Notice -->
      <TeamLandingInactive
        v-else-if="isInactive"
        :team-name="landingData?.team?.name"
      />

      <!-- Active Team Public Landing -->
      <main v-else-if="isActive && landingData?.team">
        <!-- Hero Section -->
        <TeamLandingHero
          :team="landingData.team"
          :follower-count="landingData.follower_count ?? 0"
          :is-following="landingData.is_following ?? false"
          :action-loading="actionLoading"
          :hero-title="landingData.content?.hero_title"
          :hero-subtitle="landingData.content?.hero_subtitle"
          :hero-image-url="landingData.content?.hero_image_url"
          @toggle-follow="toggleFollow"
        />

        <!-- Active Trivias Section -->
        <TeamLandingTrivias
          :trivias="landingData.active_trivias ?? []"
          :team-slug="landingData.team.slug"
        />

        <!-- Top Ranking Fans Section -->
        <TeamLandingRanking
          :ranking="landingData.top_ranking ?? []"
          :team-name="landingData.team.name"
        />

        <!-- Featured Store Rewards Section -->
        <TeamLandingStore
          :products="landingData.featured_products ?? []"
          :team-name="landingData.team.name"
        />
      </main>
    </div>

    <!-- Footer -->
    <SiteFooter />
  </div>
</template>
