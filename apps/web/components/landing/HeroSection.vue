<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'
import { useGSAP } from '~/composables/useGSAP'
import HeroCarousel from './HeroCarousel.vue'
import AnnouncementBar from './AnnouncementBar.vue'
import type { HeroCarouselSlide } from '@guaiqui/shared'

const { trackEvent } = useAnalytics()
const supabase = useSupabaseClient()
const { gsap } = useGSAP()

const heroContainer = ref<HTMLElement | null>(null)
let mm: gsap.MatchMedia | null = null

// Server-side + client hydrated data fetch using useAsyncData
const { data: heroData } = await useAsyncData('landing-hero-data', async () => {
  try {
    const [settsRes, slidesRes] = await Promise.all([
      (supabase as any)
        .from('landing_settings')
        .select('*')
        .eq('id', 1)
        .maybeSingle(),
      (supabase as any)
        .from('hero_carousel_slides')
        .select('*')
        .eq('is_published', true)
        .order('order_index', { ascending: true })
    ])

    return {
      settings: settsRes.data || null,
      slides: (slidesRes.data as HeroCarouselSlide[]) || []
    }
  } catch (err) {
    console.error('Error fetching hero data:', err)
    return {
      settings: null,
      slides: []
    }
  }
})

const settings = computed(() => heroData.value?.settings || null)
const heroSlides = computed<HeroCarouselSlide[]>(() => heroData.value?.slides || [])

const heroTitle = computed(() => settings.value?.hero_title || 'Juega, gana puntos y canjea con tu equipo')
const heroSubtitle = computed(() => settings.value?.hero_subtitle || 'La plataforma oficial de fidelización de Guaiqueríes de Margarita. Responde trivias diarias, demuestra tu pasión insular y reclama camisetas, pases y premios reales gratis.')
const ctaPrimaryText = computed(() => settings.value?.cta_primary_text || 'Regístrate Gratis Ahora')
const ctaPrimaryUrl = computed(() => {
  const url = settings.value?.cta_primary_url
  if (!url) return '/registro'
  return url === '/register' ? '/registro' : url
})
const ctaSecondaryText = computed(() => settings.value?.cta_secondary_text || 'Ver cómo funciona')
const ctaSecondaryUrl = computed(() => settings.value?.cta_secondary_url || '/#como-funciona')
const heroBadgeText = computed(() => settings.value?.hero_badge_text || 'Fan Zone Oficial • Temporada 2026')
const heroGuarantee1 = computed(() => settings.value?.hero_guarantee_1 || '100% Gratuito')
const heroGuarantee2 = computed(() => settings.value?.hero_guarantee_2 || 'Sin tarjetas ni pagos')
const heroGuarantee3 = computed(() => settings.value?.hero_guarantee_3 || 'Premios y Perlitas Reales')
const heroImageUrl = computed(() => settings.value?.hero_image_url || '')
const heroCarouselEnabled = computed(() => Boolean(settings.value?.hero_carousel_enabled))

const isCarouselActive = computed(() => heroCarouselEnabled.value && heroSlides.value.length > 0)

onMounted(async () => {
  await nextTick()
  // GSAP kinetic entrance for classic hero mode
  if (heroContainer.value && !isCarouselActive.value) {
    mm = gsap.matchMedia()
    mm.add(
      {
        reduceMotion: '(prefers-reduced-motion: reduce)',
        all: '(min-width: 0px)',
      },
      (context) => {
        const { reduceMotion } = context.conditions as { reduceMotion: boolean }
        const tl = gsap.timeline({
          defaults: {
            ease: 'power3.out',
            duration: reduceMotion ? 0 : 0.8,
          },
        })

        tl.from('.hero-badge', {
          y: -15,
          autoAlpha: 0,
          duration: reduceMotion ? 0 : 0.6,
        })
          .from(
            '.hero-headline',
            {
              y: 25,
              autoAlpha: 0,
              duration: reduceMotion ? 0 : 0.8,
            },
            '-=0.4'
          )
          .from(
            '.hero-subtitle',
            {
              y: 20,
              autoAlpha: 0,
              duration: reduceMotion ? 0 : 0.7,
            },
            '-=0.5'
          )
          .from(
            '.hero-cta',
            {
              scale: 0.94,
              y: 12,
              autoAlpha: 0,
              stagger: 0.12,
              ease: 'back.out(1.5)',
              duration: reduceMotion ? 0 : 0.6,
            },
            '-=0.4'
          )
          .from(
            '.hero-guarantee',
            {
              autoAlpha: 0,
              y: 8,
              stagger: 0.08,
              duration: reduceMotion ? 0 : 0.5,
            },
            '-=0.3'
          )
      },
      heroContainer.value
    )
  }
})

onUnmounted(() => {
  mm?.revert()
})

const handleHeroRegister = () => {
  trackEvent('click_register', { source: 'hero_primary' })
}

const handleHeroHowItWorks = () => {
  trackEvent('click_how_it_works', { source: 'hero_secondary' })
}
</script>

<template>
  <div class="w-full relative">
    <!-- Cinta de Anuncios integrada dentro de la sección Hero -->
    <AnnouncementBar />

    <!-- MODE A: Hero Carousel Full Screen (Active) -->
    <section v-if="isCarouselActive" class="w-full relative overflow-hidden">
      <HeroCarousel :slides="heroSlides" />
    </section>

    <!-- MODE B: Classic Hero Layout (Carousel Inactive / No Slides) -->
  <section
    v-else
    ref="heroContainer"
    class="relative bg-gradient-to-b from-guaiqui-primary-dark via-emerald-900 to-slate-950 text-white overflow-hidden py-20 sm:py-28 px-4 sm:px-8 min-h-[560px] sm:min-h-[640px] flex items-center justify-center"
  >
    <!-- Optional Hero Background Image uploaded by admin -->
    <div
      v-if="heroImageUrl"
      class="absolute inset-0 bg-cover bg-center mix-blend-overlay opacity-30 pointer-events-none"
      :style="{ backgroundImage: `url('${heroImageUrl}')` }"
    ></div>

    <!-- Subtle Background Pattern Overlay -->
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/10 via-transparent to-black/60 pointer-events-none" />

    <!-- Centered Hero Content without the right card -->
    <div class="max-w-4xl mx-auto relative z-10 text-center space-y-6">
      <!-- Top Badge / Distintivo -->
      <div v-if="heroBadgeText" class="hero-badge inline-flex items-center gap-2.5 bg-emerald-950/80 border border-emerald-400/40 text-emerald-300 text-xs font-mono font-bold tracking-wider uppercase px-4 py-1.5 rounded-full shadow-[0_0_20px_rgba(16,185,129,0.25)] backdrop-blur-md">
        <span class="relative flex h-2 w-2">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-400"></span>
        </span>
        <span>{{ heroBadgeText }}</span>
      </div>

      <!-- Headline -->
      <h1 class="hero-headline font-display font-extrabold text-4xl sm:text-6xl lg:text-7xl uppercase tracking-tight leading-none text-white drop-shadow-md">
        {{ heroTitle }}
      </h1>

      <!-- Subtitle -->
      <p class="hero-subtitle text-emerald-100 text-lg sm:text-xl max-w-2xl mx-auto leading-relaxed">
        {{ heroSubtitle }}
      </p>

      <!-- Double CTA Buttons -->
      <div class="flex flex-col sm:flex-row items-center justify-center gap-4 pt-2">
        <NuxtLink :to="ctaPrimaryUrl" class="hero-cta w-full sm:w-auto relative group">
          <!-- 21st.dev Shiny Border & Ambient Glow Layer -->
          <div class="absolute -inset-0.5 bg-gradient-to-r from-emerald-400 via-emerald-200 to-amber-300 rounded-guaiqui-lg blur-xs opacity-75 group-hover:opacity-100 transition duration-300 group-hover:shadow-[0_0_25px_rgba(16,185,129,0.6)]" />
          <BaseButton variant="primary" size="lg" block class="relative px-8 shadow-xl" @click="handleHeroRegister">
            {{ ctaPrimaryText }}
          </BaseButton>
        </NuxtLink>

        <NuxtLink v-if="ctaSecondaryText" :to="ctaSecondaryUrl" class="hero-cta w-full sm:w-auto">
          <BaseButton variant="secondary" size="lg" block class="px-8 bg-white/10 hover:bg-white/20 border border-white/20 text-white shadow-lg backdrop-blur-sm" @click="handleHeroHowItWorks">
            {{ ctaSecondaryText }}
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Free Guarantee Notice -->
      <div class="flex flex-wrap items-center justify-center gap-6 text-xs sm:text-sm text-emerald-200/90 pt-4 font-medium">
        <span v-if="heroGuarantee1" class="hero-guarantee flex items-center gap-1.5">
          <i class="bi bi-check-lg text-emerald-400"></i> {{ heroGuarantee1 }}
        </span>
        <span v-if="heroGuarantee2" class="hero-guarantee flex items-center gap-1.5">
          <i class="bi bi-shield-check text-emerald-400"></i> {{ heroGuarantee2 }}
        </span>
        <span v-if="heroGuarantee3" class="hero-guarantee flex items-center gap-1.5">
          <i class="bi bi-gem text-emerald-400"></i> {{ heroGuarantee3 }}
        </span>
      </div>
    </div>
  </section>
  </div>
</template>
