<script setup lang="ts">
import type { TeamLandingProfile } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'

const props = defineProps<{
  team: TeamLandingProfile
}>()

const currentYear = new Date().getFullYear()

const instagramUrl = computed(() => props.team.social_links?.instagram || null)
const twitterUrl = computed(() => props.team.social_links?.twitter || null)
const websiteUrl = computed(() => props.team.social_links?.website || null)
</script>

<template>
  <footer class="bg-gray-950 text-gray-400 py-12 border-t border-gray-900">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col md:flex-row items-center justify-between gap-8 pb-8 border-b border-gray-800">
        <!-- Brand & Info -->
        <div class="flex items-center gap-4 text-center md:text-left">
          <img
            v-if="team.logo_url"
            :src="team.logo_url"
            :alt="team.name"
            class="w-12 h-12 object-contain"
          />
          <div>
            <p class="font-display font-extrabold text-xl text-white uppercase tracking-tight">
              {{ team.name }}
            </p>
            <p class="text-xs text-gray-500">
              Fan Zone Oficial impulsada por la plataforma multi-equipo
            </p>
          </div>
        </div>

        <!-- Social Media Links -->
        <div class="flex items-center gap-4">
          <a
            v-if="instagramUrl"
            :href="instagramUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="w-10 h-10 rounded-full bg-gray-900 flex items-center justify-center text-gray-300 hover:text-white hover:bg-guaiqui-primary transition-colors"
            :aria-label="`Instagram de ${team.name}`"
          >
            <i class="bi bi-instagram text-lg" aria-hidden="true"></i>
          </a>
          <a
            v-if="twitterUrl"
            :href="twitterUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="w-10 h-10 rounded-full bg-gray-900 flex items-center justify-center text-gray-300 hover:text-white hover:bg-guaiqui-primary transition-colors"
            :aria-label="`X / Twitter de ${team.name}`"
          >
            <i class="bi bi-twitter-x text-lg" aria-hidden="true"></i>
          </a>
          <a
            v-if="websiteUrl"
            :href="websiteUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="w-10 h-10 rounded-full bg-gray-900 flex items-center justify-center text-gray-300 hover:text-white hover:bg-guaiqui-primary transition-colors"
            :aria-label="`Sitio oficial de ${team.name}`"
          >
            <i class="bi bi-globe text-lg" aria-hidden="true"></i>
          </a>
        </div>
      </div>

      <!-- Bottom Credits & Legal -->
      <div class="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs">
        <p>
          &copy; {{ currentYear }} {{ team.name }}. Todos los derechos reservados.
        </p>
        <div class="flex items-center gap-6">
          <NuxtLink to="/politicas/terminos" class="hover:text-white transition-colors">Términos</NuxtLink>
          <NuxtLink to="/politicas/privacidad" class="hover:text-white transition-colors">Privacidad</NuxtLink>
          <NuxtLink to="/como-funciona" class="hover:text-white transition-colors">Cómo Funciona</NuxtLink>
        </div>
      </div>
    </div>
  </footer>
</template>
