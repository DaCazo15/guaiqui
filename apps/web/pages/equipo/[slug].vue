<script setup lang="ts">
import { onMounted } from 'vue'
import { useTeamLanding } from '~/composables/useTeamLanding'
import TeamLandingHeader from '~/components/team-landing/TeamLandingHeader.vue'
import TeamLandingAnnouncement from '~/components/team-landing/TeamLandingAnnouncement.vue'
import TeamLandingHero from '~/components/team-landing/TeamLandingHero.vue'
import TeamLandingRoster from '~/components/team-landing/TeamLandingRoster.vue'
import TeamLandingTrivias from '~/components/team-landing/TeamLandingTrivias.vue'
import TeamLandingStore from '~/components/team-landing/TeamLandingStore.vue'
import TeamLandingHistory from '~/components/team-landing/TeamLandingHistory.vue'
import TeamLandingFaq from '~/components/team-landing/TeamLandingFaq.vue'
import TeamLandingFooter from '~/components/team-landing/TeamLandingFooter.vue'

const route = useRoute()
const slug = computed(() => (route.params.slug as string) || 'guaiqueries')

const {
  loading,
  error,
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

await fetchTeamLanding(slug.value)

if (team.value) {
  applyTeamTheme(team.value.primary_color, team.value.secondary_color)
}

useSeoMeta({
  title: () => team.value ? `${team.value.name} — Fan Zone Oficial` : 'Equipo no encontrado',
  ogTitle: () => team.value ? `${team.value.name} — Fan Zone Oficial` : 'Equipo no encontrado',
  description: () => team.value?.bio || 'Fan Zone oficial para fanáticos. Juega trivias y canjea premios reales sin dinero.',
  ogDescription: () => team.value?.bio || 'Fan Zone oficial para fanáticos.',
  ogImage: () => team.value?.logo_url || '/logo.png'
})

onMounted(() => {
  if (team.value) {
    applyTeamTheme(team.value.primary_color, team.value.secondary_color)
  }
})
</script>

<template>
  <div class="min-h-screen bg-white text-gray-900 selection:bg-guaiqui-primary selection:text-white flex flex-col">
    <!-- Estado de Carga -->
    <div v-if="loading && !team" class="flex-1 flex items-center justify-center min-h-[50vh]">
      <div class="flex flex-col items-center gap-3">
        <div class="w-10 h-10 border-4 border-guaiqui-primary border-t-transparent rounded-full animate-spin"></div>
        <p class="text-sm font-semibold text-gray-500">Cargando Fan Zone...</p>
      </div>
    </div>

    <!-- Error o Equipo no Encontrado -->
    <div v-else-if="error || !team" class="flex-1 flex items-center justify-center min-h-[60vh] px-4">
      <div class="max-w-md w-full bg-gray-50 rounded-2xl border border-gray-200 p-8 text-center space-y-4">
        <div class="w-16 h-16 rounded-full bg-red-100 text-red-600 flex items-center justify-center mx-auto text-2xl">
          <i class="bi bi-exclamation-triangle" aria-hidden="true"></i>
        </div>
        <h1 class="font-display font-extrabold text-2xl text-gray-900 uppercase">
          Equipo no disponible
        </h1>
        <p class="text-sm text-gray-600">
          No pudimos encontrar la página de este equipo o actualmente se encuentra inactivo.
        </p>
        <NuxtLink to="/">
          <button class="mt-2 px-5 py-2.5 rounded-xl bg-guaiqui-primary text-white font-bold text-sm hover:opacity-90 transition-opacity">
            Volver al inicio
          </button>
        </NuxtLink>
      </div>
    </div>

    <!-- Contenido de Landing Oficial -->
    <template v-else>
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
    </template>
  </div>
</template>
