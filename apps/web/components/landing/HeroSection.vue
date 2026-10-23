<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'
import { useGSAP } from '~/composables/useGSAP'
import HeroCarousel from './HeroCarousel.vue'
import type { HeroCarouselSlide } from '@guaiqui/shared'

const { trackEvent } = useAnalytics()
const supabase = useSupabaseClient()
const { gsap } = useGSAP()

const heroContainer = ref<HTMLElement | null>(null)
let mm: gsap.MatchMedia | null = null

const nextGame = ref<any>(null)
const loadingGame = ref(true)

const heroTitle = ref('Juega, gana puntos y canjea con tu equipo')
const heroSubtitle = ref('La plataforma oficial de fidelización de Guaiqueríes de Margarita. Responde trivias diarias, demuestra tu pasión insular y reclama camisetas, pases y premios reales gratis.')
const ctaPrimaryText = ref('Regístrate Gratis Ahora')
const ctaPrimaryUrl = ref('/registro')
const ctaSecondaryText = ref('Ver cómo funciona')
const ctaSecondaryUrl = ref('/#como-funciona')

// Hero Image, Carousel, and Card Customization
const heroImageUrl = ref('')
const heroCarouselEnabled = ref(false)
const heroCardColor = ref('')
const heroSlides = ref<HeroCarouselSlide[]>([])

const formattedGameDate = computed(() => {
  if (!nextGame.value?.game_date) return null
  const d = new Date(nextGame.value.game_date)
  return d.toLocaleDateString('es-VE', { weekday: 'short', day: 'numeric', month: 'short' })
})

const formattedGameTime = computed(() => {
  if (!nextGame.value?.game_date) return null
  const d = new Date(nextGame.value.game_date)
  return d.toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
})

onMounted(async () => {
  loadingGame.value = true
  try {
    const [gameRes, settsRes] = await Promise.all([
      supabase
        .from('games')
        .select('*')
        .in('status', ['scheduled', 'live'])
        .order('game_date', { ascending: true })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('landing_settings')
        .select('*')
        .eq('id', 1)
        .maybeSingle()
    ])

    nextGame.value = gameRes.data || null

    if (settsRes.data) {
      const s = settsRes.data
      if (s.hero_title) heroTitle.value = s.hero_title
      if (s.hero_subtitle) heroSubtitle.value = s.hero_subtitle
      if (s.cta_primary_text) ctaPrimaryText.value = s.cta_primary_text
      if (s.cta_primary_url) ctaPrimaryUrl.value = s.cta_primary_url === '/register' ? '/registro' : s.cta_primary_url
      if (s.cta_secondary_text) ctaSecondaryText.value = s.cta_secondary_text
      if (s.cta_secondary_url) ctaSecondaryUrl.value = s.cta_secondary_url
      if (s.hero_image_url) heroImageUrl.value = s.hero_image_url
      if (s.hero_carousel_enabled !== undefined) heroCarouselEnabled.value = s.hero_carousel_enabled
      if (s.hero_card_color) heroCardColor.value = s.hero_card_color

      // If carousel is enabled, fetch published hero slides
      if (s.hero_carousel_enabled) {
        const { data: slidesData } = await supabase
          .from('hero_carousel_slides')
          .select('*')
          .eq('is_published', true)
          .order('order_index', { ascending: true })

        heroSlides.value = (slidesData as HeroCarouselSlide[]) || []
      }
    }
  } catch (_err) {
    nextGame.value = null
  } finally {
    loadingGame.value = false
  }

  // Animaciones Cinéticas GSAP con accesibilidad prefers-reduced-motion
  if (heroContainer.value) {
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

        tl.from(
          '.hero-headline',
          {
            y: 25,
            autoAlpha: 0,
            duration: reduceMotion ? 0 : 0.8,
          }
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
          .from(
            '.hero-card',
            {
              x: 30,
              autoAlpha: 0,
              duration: reduceMotion ? 0 : 0.8,
              ease: 'power2.out',
            },
            '-=0.7'
          )

        if (!reduceMotion) {
          gsap.to('.hero-card', {
            y: '-=6',
            repeat: -1,
            yoyo: true,
            ease: 'sine.inOut',
            duration: 3.2,
            delay: 1,
          })
        }
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
  <section ref="heroContainer" class="relative bg-gradient-to-b from-guaiqui-primary-dark via-emerald-900 to-slate-950 text-white overflow-hidden py-16 sm:py-24 px-4 sm:px-8">
    <!-- Optional Uploaded Hero Background Image (blended over the default brand gradient) -->
    <div
      v-if="heroImageUrl"
      class="absolute inset-0 bg-cover bg-center mix-blend-overlay opacity-30 pointer-events-none"
      :style="{ backgroundImage: `url('${heroImageUrl}')` }"
    ></div>

    <!-- Subtle Background Pattern Overlay for Text Legibility -->
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/10 via-transparent to-black/60 pointer-events-none" />

    <div class="max-w-6xl mx-auto relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
      <!-- Left Content -->
      <div class="lg:col-span-7 space-y-6 text-center lg:text-left">
        <!-- Headline -->
        <h1 class="hero-headline font-display font-extrabold text-4xl sm:text-5xl lg:text-6xl uppercase tracking-tight leading-none">
          {{ heroTitle }}
        </h1>

        <!-- Subtitle -->
        <p class="hero-subtitle text-emerald-100 text-base sm:text-lg max-w-2xl mx-auto lg:mx-0 leading-relaxed">
          {{ heroSubtitle }}
        </p>

        <!-- Double CTA Buttons -->
        <div class="flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-4 pt-2">
          <NuxtLink :to="ctaPrimaryUrl" class="hero-cta w-full sm:w-auto">
            <BaseButton variant="primary" size="lg" block @click="handleHeroRegister">
              {{ ctaPrimaryText }}
            </BaseButton>
          </NuxtLink>

          <NuxtLink :to="ctaSecondaryUrl" class="hero-cta w-full sm:w-auto">
            <BaseButton variant="secondary" size="lg" block @click="handleHeroHowItWorks">
              {{ ctaSecondaryText }}
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Free Guarantee Notice -->
        <div class="flex items-center justify-center lg:justify-start gap-4 text-xs text-emerald-200/90 pt-2 font-medium">
          <span class="hero-guarantee flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> 100% Gratuito</span>
          <span class="hero-guarantee flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> Sin tarjetas ni pagos</span>
          <span class="hero-guarantee flex items-center gap-1.5"><i class="bi bi-check-lg text-emerald-400"></i> Premios reales</span>
        </div>
      </div>

      <!-- Right Content: Hero Carousel OR Dynamic Match Card OR Institutional Fan Zone Card -->
      <div class="hero-card lg:col-span-5 w-full max-w-md mx-auto">
        <!-- Mode A: Hero Carousel (when enabled and slides exist) -->
        <HeroCarousel
          v-if="heroCarouselEnabled && heroSlides.length > 0"
          :slides="heroSlides"
        />

        <!-- Mode B: Real scheduled match in database -->
        <div
          v-else-if="nextGame"
          class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-guaiqui-xl p-6 shadow-2xl relative overflow-hidden"
          :style="heroCardColor ? { backgroundColor: heroCardColor } : {}"
        >
          <div class="absolute top-0 right-0 bg-guaiqui-accent text-white text-[10px] font-extrabold uppercase px-3 py-1 rounded-bl-lg">
            {{ nextGame.status === 'live' ? 'En Vivo' : 'Próximo Juego' }}
          </div>

          <div class="text-xs uppercase font-bold text-emerald-300 tracking-wider mb-2">
            Superliga Profesional de Baloncesto
          </div>

          <h2 class="font-display font-extrabold text-2xl text-white uppercase mb-1">
            Guaiqueríes <span class="text-emerald-400">vs</span> {{ nextGame.opponent }}
          </h2>

          <p class="text-xs text-emerald-100/80 mb-6 flex items-center gap-1.5">
            <i class="bi bi-geo-alt-fill text-emerald-400"></i>
            <span>{{ nextGame.location }}</span>
          </p>

          <div class="bg-black/40 rounded-guaiqui-lg p-4 border border-white/10 flex items-center justify-between mb-6">
            <div>
              <div class="text-[10px] uppercase text-emerald-300 font-bold">Fecha y Hora</div>
              <div class="text-sm font-bold text-white">{{ formattedGameDate }}</div>
              <div class="text-xs text-emerald-200">{{ formattedGameTime }}</div>
            </div>

            <div class="text-right">
              <div class="text-[10px] uppercase text-amber-300 font-bold">Recompensa</div>
              <div class="text-sm font-bold text-amber-400 flex items-center justify-end gap-1">
                +300 <PearlIcon size="xs" />
              </div>
              <div class="text-[10px] text-emerald-200">por acertar trivia</div>
            </div>
          </div>

          <NuxtLink to="/registro">
            <BaseButton variant="primary" block size="md" @click="handleHeroRegister">
              Participar en la Trivia del Partido
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Mode C: Institutional Fan Zone Card -->
        <div
          v-else
          class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-guaiqui-xl p-6 shadow-2xl relative overflow-hidden space-y-5"
          :style="heroCardColor ? { backgroundColor: heroCardColor } : {}"
        >
          <div class="absolute top-0 right-0 bg-guaiqui-primary text-white text-[10px] font-extrabold uppercase px-3 py-1 rounded-bl-lg">
            Fan Zone Oficial
          </div>

          <div>
            <div class="text-xs uppercase font-bold text-emerald-300 tracking-wider mb-1">
              Temporada 2026
            </div>
            <h2 class="font-display font-extrabold text-2xl text-white uppercase">
              La Tribu Verde
            </h2>
            <p class="text-xs text-emerald-100/80 flex items-center gap-1.5 mt-1">
              <i class="bi bi-geo-alt-fill text-emerald-400"></i>
              <span>Gimnasio Ciudad de La Asunción</span>
            </p>
          </div>

          <div class="bg-black/40 rounded-guaiqui-lg p-4 border border-white/10 space-y-3">
            <div class="flex items-center justify-between border-b border-white/10 pb-2.5">
              <span class="text-xs text-slate-300">Historia Nacional</span>
              <span class="font-display font-bold text-sm text-amber-300">9 Estrellas</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-xs text-slate-300">Moneda de Fidelidad</span>
              <span class="font-bold text-xs text-emerald-300 flex items-center gap-1">
                Puntos Gratis <PearlIcon size="xs" />
              </span>
            </div>
          </div>

          <p class="text-xs text-emerald-200/90 leading-relaxed">
            Acumula puntos respondiendo las trivias de la historia del club y prepárate para los próximos partidos oficiales.
          </p>

          <NuxtLink to="/registro">
            <BaseButton variant="primary" block size="md" @click="handleHeroRegister">
              Únete a la Tribu Gratis
            </BaseButton>
          </NuxtLink>
        </div>
      </div>
    </div>
  </section>
</template>
