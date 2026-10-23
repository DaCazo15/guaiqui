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
const cardRef = ref<HTMLElement | null>(null)
let autoplayInterval: ReturnType<typeof setInterval> | null = null
let ctx: gsap.Context | null = null

// Drag & touch state
const isDragging = ref(false)
const startX = ref(0)
const currentX = ref(0)
const dragThreshold = 45

const currentSlide = computed(() => {
  if (props.slides.length === 0) return null
  return props.slides[currentIndex.value] || props.slides[0]
})

const animateSlideTransition = (direction: 'next' | 'prev' | 'fade' = 'next') => {
  if (!cardRef.value) return

  const mm = gsap.matchMedia()
  mm.add('(prefers-reduced-motion: no-preference)', () => {
    const xOffset = direction === 'next' ? 35 : direction === 'prev' ? -35 : 0
    const tl = gsap.timeline({ defaults: { ease: 'power3.out' } })

    tl.fromTo(
      cardRef.value,
      { opacity: 0.2, x: xOffset, scale: 0.98 },
      { opacity: 1, x: 0, scale: 1, duration: 0.55 }
    )

    tl.fromTo(
      '.hero-carousel-anim-el',
      { opacity: 0, y: 12 },
      { opacity: 1, y: 0, duration: 0.45, stagger: 0.07 },
      '-=0.35'
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
  animateSlideTransition('next')
}

const prevSlide = () => {
  if (props.slides.length <= 1) return
  const prevIdx = (currentIndex.value - 1 + props.slides.length) % props.slides.length
  currentIndex.value = prevIdx
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
  }, 4000)
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
    resetAutoplay()
  }
  isDragging.value = false
  startX.value = 0
  currentX.value = 0
}

// Mouse Drag Handlers
const handleMouseDown = (e: MouseEvent) => {
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
    resetAutoplay()
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

onMounted(() => {
  ctx = gsap.context(() => {}, slideContainer.value || undefined)
  startAutoplay()
})

onUnmounted(() => {
  stopAutoplay()
  ctx?.revert()
})

watch(() => props.slides.length, () => {
  resetAutoplay()
})
</script>

<template>
  <div
    v-if="currentSlide"
    ref="slideContainer"
    class="w-full max-w-md mx-auto select-none"
    @mouseenter="isPaused = true"
    @mouseleave="handleMouseLeave"
  >
    <!-- Slide Card with Touch & Mouse drag -->
    <div
      ref="cardRef"
      class="relative bg-white/10 backdrop-blur-xl border border-white/20 rounded-guaiqui-xl overflow-hidden shadow-2xl transition-shadow hover:shadow-emerald-950/60 cursor-grab active:cursor-grabbing"
      @touchstart="handleTouchStart"
      @touchmove="handleTouchMove"
      @touchend="handleTouchEnd"
      @mousedown="handleMouseDown"
      @mousemove="handleMouseMove"
      @mouseup="handleMouseUp"
    >
      <!-- Media Cover -->
      <div class="relative w-full h-44 sm:h-52 bg-slate-950 overflow-hidden">
        <img
          v-if="currentSlide.image_url"
          :src="currentSlide.image_url"
          :alt="currentSlide.title"
          class="w-full h-full object-cover transition-transform duration-700 ease-out hover:scale-105 pointer-events-none"
        />
        <div v-else class="w-full h-full bg-gradient-to-br from-emerald-950 via-guaiqui-primary-dark to-slate-950 flex items-center justify-center">
          <i class="bi bi-images text-emerald-400/40 text-5xl"></i>
        </div>

        <!-- Gradient shading overlay for contrast -->
        <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent"></div>

        <!-- Tag / Badge in top right -->
        <div class="hero-carousel-anim-el absolute top-3 right-3 bg-guaiqui-primary text-white text-[10px] font-extrabold uppercase px-3 py-1 rounded-full shadow-md border border-white/20">
          {{ currentSlide.tag || 'Fan Zone' }}
        </div>

        <!-- Slide Counter in top left -->
        <div class="hero-carousel-anim-el absolute top-3 left-3 bg-black/50 backdrop-blur-xs text-emerald-300 text-[10px] font-bold px-2.5 py-0.5 rounded-full border border-white/10">
          {{ currentIndex + 1 }} / {{ slides.length }}
        </div>
      </div>

      <!-- Content Area -->
      <div class="p-5 sm:p-6 space-y-4 relative z-10 bg-slate-950/70">
        <div class="space-y-1.5">
          <h3 class="hero-carousel-anim-el font-display font-extrabold text-xl sm:text-2xl text-white uppercase leading-tight line-clamp-2">
            {{ currentSlide.title }}
          </h3>
          <p v-if="currentSlide.subtitle" class="hero-carousel-anim-el text-xs sm:text-sm text-emerald-100/80 leading-relaxed line-clamp-2">
            {{ currentSlide.subtitle }}
          </p>
        </div>

        <!-- CTA Action Button -->
        <div class="hero-carousel-anim-el pt-1">
          <NuxtLink :to="currentSlide.cta_url || '/registro'" class="block">
            <BaseButton
              variant="primary"
              size="md"
              block
              class="shadow-lg shadow-emerald-950/60"
              @click="handleCtaClick"
            >
              <span>{{ currentSlide.cta_text || 'Ver Más' }}</span>
              <i class="bi bi-arrow-right ml-1.5"></i>
            </BaseButton>
          </NuxtLink>
        </div>
      </div>

      <!-- Drag Indicator Overlay on Hover -->
      <div class="absolute bottom-2 right-3 text-[10px] text-white/40 pointer-events-none flex items-center gap-1 font-medium">
        <i class="bi bi-arrows"></i> Desliza para navegar
      </div>
    </div>

    <!-- Pagination Dots & Navigation Controls -->
    <div v-if="slides.length > 1" class="flex items-center justify-between pt-3 px-1">
      <!-- Dots -->
      <div class="flex items-center gap-2">
        <button
          v-for="(slide, idx) in slides"
          :key="slide.id"
          type="button"
          :title="`Ir al post ${idx + 1}`"
          @click="goToSlide(idx)"
          class="group relative h-2.5 transition-all duration-300 rounded-full focus:outline-hidden"
          :class="currentIndex === idx ? 'w-8 bg-emerald-400' : 'w-2.5 bg-white/30 hover:bg-white/60'"
        >
          <!-- Active dot 4s animation bar -->
          <span
            v-if="currentIndex === idx && !isPaused"
            class="absolute inset-0 bg-white/40 rounded-full animate-pulse"
          ></span>
        </button>
      </div>

      <!-- Arrow Controls -->
      <div class="flex items-center gap-1">
        <button
          type="button"
          title="Anterior"
          @click="prevSlide"
          class="w-7 h-7 rounded-lg bg-white/10 hover:bg-white/20 text-white flex items-center justify-center text-xs transition-colors border border-white/10"
        >
          <i class="bi bi-chevron-left"></i>
        </button>
        <button
          type="button"
          title="Siguiente"
          @click="nextSlide"
          class="w-7 h-7 rounded-lg bg-white/10 hover:bg-white/20 text-white flex items-center justify-center text-xs transition-colors border border-white/10"
        >
          <i class="bi bi-chevron-right"></i>
        </button>
      </div>
    </div>
  </div>
</template>
