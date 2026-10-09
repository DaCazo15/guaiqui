<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { BaseBadge, BaseButton } from '@guaiqui/ui'
import { carouselSlides as fallbackSlides, type CarouselSlide } from '~/data/landingData'
import { useAnalytics } from '~/composables/useAnalytics'

const supabase = useSupabaseClient()
const { trackEvent } = useAnalytics()

const slides = ref<CarouselSlide[]>(fallbackSlides)
const currentIndex = ref(0)
const isPaused = ref(false)
let timer: ReturnType<typeof setInterval> | null = null

// Touch swipe variables
let touchStartX = 0
let touchEndX = 0

const nextSlide = () => {
  if (slides.value.length === 0) return
  currentIndex.value = (currentIndex.value + 1) % slides.value.length
}

const prevSlide = () => {
  if (slides.value.length === 0) return
  currentIndex.value = (currentIndex.value - 1 + slides.value.length) % slides.value.length
}

const goToSlide = (index: number) => {
  currentIndex.value = index
}

const handleSlideClick = (slide: CarouselSlide) => {
  trackEvent('click_carousel_slide', { slideId: slide.id, title: slide.title })
}

const handleTouchStart = (e: TouchEvent) => {
  touchStartX = e.changedTouches[0].screenX
}

const handleTouchEnd = (e: TouchEvent) => {
  touchEndX = e.changedTouches[0].screenX
  if (touchStartX - touchEndX > 50) {
    nextSlide()
  } else if (touchEndX - touchStartX > 50) {
    prevSlide()
  }
}

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('carousel_slides')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      slides.value = data.map((row: any) => ({
        id: row.id,
        tag: row.tag || 'Destacado',
        title: row.title,
        subtitle: row.subtitle || '',
        ctaText: row.cta_text || 'Ver Más',
        ctaUrl: row.cta_url || '#',
        bgGradient: row.bg_gradient || 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
        badgeVariant: (row.badge_variant as any) || 'primary'
      }))
    }
  } catch (_err) {
    // Keep fallback
  }

  // Respect prefers-reduced-motion
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (!prefersReducedMotion) {
    timer = setInterval(() => {
      if (!isPaused.value) {
        nextSlide()
      }
    }, 5000)
  }
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<template>
  <section class="py-12 bg-guaiqui-surface border-y border-guaiqui-border px-4 sm:px-8">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-wider">Novedades</span>
          <h2 class="font-display font-extrabold text-2xl sm:text-3xl text-guaiqui-text uppercase">
            Destacados de la Tribu
          </h2>
        </div>

        <!-- Controls -->
        <div class="hidden sm:flex items-center gap-2">
          <button
            type="button"
            class="p-2 rounded-full border border-guaiqui-border bg-white text-guaiqui-text hover:bg-guaiqui-surface transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
            aria-label="Diapositiva anterior"
            @click="prevSlide"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <button
            type="button"
            class="p-2 rounded-full border border-guaiqui-border bg-white text-guaiqui-text hover:bg-guaiqui-surface transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-guaiqui-primary"
            aria-label="Siguiente diapositiva"
            @click="nextSlide"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Carousel Track Container -->
      <div
        class="relative rounded-guaiqui-xl overflow-hidden shadow-guaiqui-lg text-white"
        @mouseenter="isPaused = true"
        @mouseleave="isPaused = false"
        @touchstart="handleTouchStart"
        @touchend="handleTouchEnd"
      >
        <div
          v-for="(slide, index) in slides"
          v-show="index === currentIndex"
          :key="slide.id"
          :class="[
            'p-8 sm:p-12 min-h-[300px] flex flex-col justify-between bg-gradient-to-r transition-opacity duration-300',
            slide.bgGradient,
          ]"
        >
          <div class="space-y-4 max-w-2xl">
            <BaseBadge :variant="slide.badgeVariant" size="md">
              {{ slide.tag }}
            </BaseBadge>

            <h3 class="font-display font-extrabold text-3xl sm:text-4xl uppercase tracking-tight leading-tight">
              {{ slide.title }}
            </h3>

            <p class="text-sm sm:text-base text-emerald-100/90 leading-relaxed">
              {{ slide.subtitle }}
            </p>
          </div>

          <div class="pt-6">
            <NuxtLink :to="slide.ctaUrl">
              <BaseButton variant="primary" size="md" @click="handleSlideClick(slide)">
                {{ slide.ctaText }}
              </BaseButton>
            </NuxtLink>
          </div>
        </div>

        <!-- Indicators / Dots -->
        <div class="absolute bottom-4 right-4 flex items-center gap-2 bg-black/40 backdrop-blur-md px-3 py-1.5 rounded-full">
          <button
            v-for="(_, index) in slides"
            :key="index"
            type="button"
            :class="[
              'h-2.5 rounded-full transition-all duration-200 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-white',
              index === currentIndex ? 'w-6 bg-amber-400' : 'w-2.5 bg-white/50 hover:bg-white',
            ]"
            :aria-label="`Ir a la diapositiva ${index + 1}`"
            @click="goToSlide(index)"
          />
        </div>
      </div>
    </div>
  </section>
</template>
