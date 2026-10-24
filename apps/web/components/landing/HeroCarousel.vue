<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { BaseButton } from '@guaiqui/ui'
import type { HeroCarouselSlide } from '@guaiqui/shared'
import { useAnalytics } from '~/composables/useAnalytics'
import gsap from 'gsap'

const props = defineProps<{
  slides: HeroCarouselSlide[]
}>()

const { trackEvent } = useAnalytics()

const currentIndex = ref(0)
const isPaused = ref(false)
const slideContainer = ref<HTMLElement | null>(null)
const slideContentRef = ref<HTMLElement | null>(null)
let autoplayInterval: ReturnType<typeof setInterval> | null = null
let ctx: gsap.Context | null = null

// Drag & touch state
const isDragging = ref(false)
const startX = ref(0)
const currentX = ref(0)
const dragThreshold = 50

const currentSlide = computed(() => {
  if (props.slides.length === 0) return null
  return props.slides[currentIndex.value] || props.slides[0]
})

const animateSlideTransition = (direction: 'next' | 'prev' | 'fade' = 'next') => {
  if (!slideContentRef.value) return

  const mm = gsap.matchMedia()
  mm.add('(prefers-reduced-motion: no-preference)', () => {
    const xOffset = direction === 'next' ? 40 : direction === 'prev' ? -40 : 0
    const tl = gsap.timeline({ defaults: { ease: 'power3.out' } })

    tl.fromTo(
      slideContentRef.value,
      { opacity: 0.15, x: xOffset },
      { opacity: 1, x: 0, duration: 0.6 }
    )

    tl.fromTo(
      '.hero-carousel-anim-el',
      { opacity: 0, y: 18 },
      { opacity: 1, y: 0, duration: 0.5, stagger: 0.08, ease: 'power2.out' },
      '-=0.45'
    )
  })
}

const goToSlide = (index: number) => {
  if (index === currentIndex.value || index < 0 || index >= props.slides.length) return
  const direction = index > currentIndex.value ? 'next' : 'prev'
  currentIndex.value = index
  resetAutoplay()
  animateSlideTransition(direction)
}

const nextSlide = () => {
  if (props.slides.length <= 1) return
  const nextIdx = (currentIndex.value + 1) % props.slides.length
  currentIndex.value = nextIdx
  resetAutoplay()
  animateSlideTransition('next')
}

const prevSlide = () => {
  if (props.slides.length <= 1) return
  const prevIdx = (currentIndex.value - 1 + props.slides.length) % props.slides.length
  currentIndex.value = prevIdx
  resetAutoplay()
  animateSlideTransition('prev')
}

// Autoplay (4 seconds)
const startAutoplay = () => {
  stopAutoplay()
  if (props.slides.length <= 1) return
  autoplayInterval = setInterval(() => {
    if (!isPaused.value && !isDragging.value) {
      nextSlide()
    }
  }, 3000)
}

const stopAutoplay = () => {
  if (autoplayInterval) {
    clearInterval(autoplayInterval)
    autoplayInterval = null
  }
}

const resetAutoplay = () => {
  stopAutoplay()
  startAutoplay()
}

// Touch Handlers
const handleTouchStart = (e: TouchEvent) => {
  isDragging.value = true
  startX.value = e.touches[0].clientX
  currentX.value = e.touches[0].clientX
}

const handleTouchMove = (e: TouchEvent) => {
  if (!isDragging.value) return
  currentX.value = e.touches[0].clientX
}

const handleTouchEnd = () => {
  if (!isDragging.value) return
  const diff = startX.value - currentX.value
  if (Math.abs(diff) > dragThreshold) {
    if (diff > 0) {
      nextSlide()
    } else {
      prevSlide()
    }
  }
  isDragging.value = false
  startX.value = 0
  currentX.value = 0
}

// Mouse Drag Handlers
const handleMouseDown = (e: MouseEvent) => {
  // Only trigger on left click
  if (e.button !== 0) return
  isDragging.value = true
  startX.value = e.clientX
  currentX.value = e.clientX
}

const handleMouseMove = (e: MouseEvent) => {
  if (!isDragging.value) return
  currentX.value = e.clientX
}

const handleMouseUp = () => {
  if (!isDragging.value) return
  const diff = startX.value - currentX.value
  if (Math.abs(diff) > dragThreshold) {
    if (diff > 0) {
      nextSlide()
    } else {
      prevSlide()
    }
  }
  isDragging.value = false
  startX.value = 0
  currentX.value = 0
}

const handleMouseLeave = () => {
  if (isDragging.value) {
    handleMouseUp()
  }
  isPaused.value = false
}

const handleCtaClick = () => {
  if (!currentSlide.value) return
  trackEvent('click_hero_carousel_slide', {
    slideId: currentSlide.value.id,
    title: currentSlide.value.title,
    index: currentIndex.value
  })
}

// Keyboard navigation
const handleKeyDown = (e: KeyboardEvent) => {
  if (e.key === 'ArrowLeft') {
    prevSlide()
  } else if (e.key === 'ArrowRight') {
    nextSlide()
  }
}

onMounted(() => {
  ctx = gsap.context(() => {}, slideContainer.value || undefined)
  startAutoplay()
  window.addEventListener('keydown', handleKeyDown)
})

onUnmounted(() => {
  stopAutoplay()
  ctx?.revert()
  window.removeEventListener('keydown', handleKeyDown)
})

watch(() => props.slides.length, () => {
  resetAutoplay()
})
</script>

<template>
  <div
    v-if="currentSlide"
    ref="slideContainer"
    class="relative w-full min-h-[560px] sm:min-h-[640px] lg:min-h-[700px] flex items-center justify-center overflow-hidden bg-slate-950 text-white select-none cursor-grab active:cursor-grabbing"
    @mouseenter="isPaused = true"
    @mouseleave="handleMouseLeave"
    @touchstart="handleTouchStart"
    @touchmove="handleTouchMove"
    @touchend="handleTouchEnd"
    @mousedown="handleMouseDown"
    @mousemove="handleMouseMove"
    @mouseup="handleMouseUp"
  >
    <!-- Background Media Cover -->
    <div class="absolute inset-0 z-0 overflow-hidden pointer-events-none">
      <img
        v-if="currentSlide.image_url"
        :key="currentSlide.image_url"
        :src="currentSlide.image_url"
        :alt="currentSlide.title"
        class="w-full h-full object-cover object-center transition-all duration-1000 ease-out scale-100"
      />
      <!-- Fallback brand gradient if no image -->
      <div
        v-else
        class="w-full h-full bg-gradient-to-b from-guaiqui-primary-dark via-emerald-950 to-slate-950"
      ></div>

      <!-- High-contrast overlays for text legibility and brand aesthetics -->
      <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/75 to-slate-950/40"></div>
      <div class="absolute inset-0 bg-gradient-to-r from-guaiqui-primary-dark/80 via-transparent to-slate-950/70"></div>
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-emerald-500/15 via-transparent to-black/60"></div>
    </div>

    <!-- Center Content Area -->
    <div
      ref="slideContentRef"
      class="relative z-10 max-w-5xl mx-auto px-6 sm:px-12 py-16 sm:py-24 text-center flex flex-col items-center justify-center space-y-6"
    >
      <!-- Tag / Badge -->
      <div class="hero-carousel-anim-el inline-flex items-center gap-2 bg-guaiqui-primary text-white text-xs font-extrabold uppercase px-4 py-1.5 rounded-full shadow-lg border border-white/20 tracking-wider">
        <i class="bi bi-star-fill text-amber-300 text-[10px]"></i>
        <span>{{ currentSlide.tag || 'Fan Zone Oficial' }}</span>
      </div>

      <!-- Slide Title -->
      <h1 class="hero-carousel-anim-el font-display font-extrabold text-4xl sm:text-6xl lg:text-7xl uppercase tracking-tight leading-none text-white drop-shadow-xl max-w-4xl">
        {{ currentSlide.title }}
      </h1>

      <!-- Slide Subtitle -->
      <p
        v-if="currentSlide.subtitle"
        class="hero-carousel-anim-el text-emerald-100 text-base sm:text-lg lg:text-xl max-w-2xl mx-auto leading-relaxed drop-shadow-md"
      >
        {{ currentSlide.subtitle }}
      </p>

      <!-- CTA Button -->
      <div class="hero-carousel-anim-el pt-2 flex flex-col sm:flex-row items-center justify-center gap-4 w-full sm:w-auto">
        <NuxtLink :to="currentSlide.cta_url || '/registro'" class="w-full sm:w-auto">
          <BaseButton
            variant="primary"
            size="lg"
            block
            class="shadow-xl shadow-emerald-950/80 px-8"
            @click="handleCtaClick"
          >
            <span>{{ currentSlide.cta_text || 'Ver Más' }}</span>
            <i class="bi bi-arrow-right ml-2"></i>
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Guarantees Notice -->
      <div class="hero-carousel-anim-el flex flex-wrap items-center justify-center gap-6 text-xs sm:text-sm text-emerald-200/90 pt-4 font-medium">
        <span class="flex items-center gap-1.5">
          <i class="bi bi-check-lg text-emerald-400"></i> 100% Gratuito
        </span>
        <span class="flex items-center gap-1.5">
          <i class="bi bi-check-lg text-emerald-400"></i> Sin tarjetas ni pagos
        </span>
        <span class="flex items-center gap-1.5">
          <i class="bi bi-check-lg text-emerald-400"></i> Premios reales
        </span>
      </div>
    </div>

    <!-- Navigation Arrows (Desktop / Tablet) -->
    <div v-if="slides.length > 1" class="hidden sm:block pointer-events-none">
      <button
        type="button"
        aria-label="Diapositiva anterior"
        title="Diapositiva anterior"
        @click="prevSlide"
        class="pointer-events-auto absolute left-4 sm:left-8 top-1/2 -translate-y-1/2 z-20 w-12 h-12 rounded-full bg-black/40 hover:bg-emerald-600 border border-white/20 text-white backdrop-blur-md flex items-center justify-center text-lg transition-all duration-300 shadow-xl hover:scale-110 active:scale-95 focus:outline-hidden"
      >
        <i class="bi bi-chevron-left"></i>
      </button>

      <button
        type="button"
        aria-label="Siguiente diapositiva"
        title="Siguiente diapositiva"
        @click="nextSlide"
        class="pointer-events-auto absolute right-4 sm:right-8 top-1/2 -translate-y-1/2 z-20 w-12 h-12 rounded-full bg-black/40 hover:bg-emerald-600 border border-white/20 text-white backdrop-blur-md flex items-center justify-center text-lg transition-all duration-300 shadow-xl hover:scale-110 active:scale-95 focus:outline-hidden"
      >
        <i class="bi bi-chevron-right"></i>
      </button>
    </div>

    <!-- Bottom Controls: Dots & Counter -->
    <div
      v-if="slides.length > 1"
      class="absolute bottom-6 sm:bottom-8 left-0 right-0 z-20 flex items-center justify-center gap-4 px-4 pointer-events-none"
    >
      <div class="pointer-events-auto flex items-center gap-3 bg-black/50 backdrop-blur-md px-5 py-2.5 rounded-full border border-white/15 shadow-xl">
        <!-- Dots -->
        <div class="flex items-center gap-2">
          <button
            v-for="(slide, idx) in slides"
            :key="slide.id"
            type="button"
            :title="`Ir a diapositiva ${idx + 1}`"
            @click="goToSlide(idx)"
            class="group relative h-2.5 transition-all duration-300 rounded-full focus:outline-hidden cursor-pointer"
            :class="currentIndex === idx ? 'w-8 bg-emerald-400' : 'w-2.5 bg-white/30 hover:bg-white/60'"
          >
            <span
              v-if="currentIndex === idx && !isPaused"
              class="absolute inset-0 bg-white/40 rounded-full animate-pulse"
            ></span>
          </button>
        </div>

        <!-- Slide Counter -->
        <span class="text-xs font-mono font-bold text-white/80 border-l border-white/20 pl-3">
          {{ currentIndex + 1 }} / {{ slides.length }}
        </span>
      </div>
    </div>
  </div>
</template>
