<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../components/layout/AdminLayout.vue'
import LandingHeroTab from '../components/landing-admin/LandingHeroTab.vue'
import LandingCarouselTab from '../components/landing-admin/LandingCarouselTab.vue'
import LandingCtaTab from '../components/landing-admin/LandingCtaTab.vue'
import LandingWelcomeModalTab from '../components/landing-admin/LandingWelcomeModalTab.vue'
import LandingFooterTab from '../components/landing-admin/LandingFooterTab.vue'

type LandingTab = 'hero' | 'carousel' | 'cta' | 'popup' | 'footer'

const route = useRoute()
const router = useRouter()

const activeTab = ref<LandingTab>('hero')

const tabs = [
  { id: 'hero' as const, label: 'Hero & Anuncios', icon: 'bi-layout-text-window-reverse', description: 'Cabecera, textos, distintivos y cinta de anuncios' },
  { id: 'carousel' as const, label: 'Carrusel Landing', icon: 'bi-images', description: 'Diapositivas y carrusel interactivo' },
  { id: 'cta' as const, label: 'Llamados a la Acción (CTA)', icon: 'bi-megaphone-fill', description: 'Bloques de conversión y frases de impacto' },
  { id: 'popup' as const, label: 'Pop-up Bienvenida', icon: 'bi-window-stack', description: 'Modal inicial de bienvenida para fanáticos' },
  { id: 'footer' as const, label: 'Pie de Página (Footer)', icon: 'bi-layout-sidebar-inset-reverse', description: 'Redes sociales, textos legales y soporte' }
]

const setTab = (tab: LandingTab) => {
  activeTab.value = tab
  router.replace({ query: { ...route.query, tab } })
}

const syncTabFromRoute = () => {
  const queryTab = route.query.tab as string
  if (queryTab && ['hero', 'carousel', 'cta', 'popup', 'footer'].includes(queryTab)) {
    activeTab.value = queryTab as LandingTab
  } else if (route.query.tab === 'anuncios') {
    activeTab.value = 'hero'
  } else if (route.query.tab === 'pie' || route.query.tab === 'redes') {
    activeTab.value = 'footer'
  }
}

onMounted(() => {
  syncTabFromRoute()
})

import { useAuthStore } from '../stores/auth'

const authStore = useAuthStore()

const currentTeamName = computed(() => authStore.selectedTeam?.name || 'Guaiqueríes de Margarita')
const currentTeamSlug = computed(() => authStore.selectedTeam?.slug || 'guaiqueries')
const previewUrl = computed(() => `http://localhost:3000/e/${currentTeamSlug.value}`)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Section Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-800">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-window-fullscreen text-emerald-400"></i>
            Gestión de la Landing Page
          </h1>
          <p class="text-xs sm:text-sm text-slate-400 mt-1">
            Administra todos los componentes visuales y contenidos de la página de inicio pública desde un solo lugar.
          </p>
        </div>

        <!-- Preview & Team Badge -->
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-300">
            <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
            <span>Equipo: <strong class="text-white">{{ currentTeamName }}</strong></span>
          </div>

          <a
            :href="previewUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs transition-all shadow-md shadow-emerald-950/40"
          >
            <i class="bi bi-box-arrow-up-right"></i>
            <span>Ver Vista Previa</span>
          </a>
        </div>
      </div>

      <!-- Dynamic Tab Buttons -->
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2.5 p-1.5 bg-slate-950/80 border border-slate-800/80 rounded-2xl shadow-inner">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          type="button"
          @click="setTab(tab.id)"
          :class="[
            'px-4 py-3 rounded-xl text-left transition-all duration-200 flex flex-col justify-center gap-1 group relative',
            activeTab === tab.id
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-950/60 ring-1 ring-emerald-400/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900/80'
          ]"
        >
          <div class="flex items-center gap-2">
            <i :class="['bi', tab.icon, 'text-base', activeTab === tab.id ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400']"></i>
            <span class="text-xs sm:text-sm font-bold tracking-tight">{{ tab.label }}</span>
          </div>
          <span :class="['text-[11px] truncate hidden sm:block', activeTab === tab.id ? 'text-emerald-100' : 'text-slate-500']">
            {{ tab.description }}
          </span>
        </button>
      </div>

      <!-- Dynamic Tab Content Render -->
      <div class="pt-2">
        <LandingHeroTab v-if="activeTab === 'hero'" />
        <LandingCarouselTab v-else-if="activeTab === 'carousel'" />
        <LandingCtaTab v-else-if="activeTab === 'cta'" />
        <LandingWelcomeModalTab v-else-if="activeTab === 'popup'" />
        <LandingFooterTab v-else-if="activeTab === 'footer'" />
      </div>
    </div>
  </AdminLayout>
</template>
