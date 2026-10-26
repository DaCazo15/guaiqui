<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import type { HeroCarouselSlide } from '@guaiqui/shared'
import { useAnalytics } from '~/composables/useAnalytics'
import { useGSAP } from '~/composables/useGSAP'

const { gsap } = useGSAP()

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

const isRightImageLayout = computed(() => {
  return currentSlide.value?.image_layout === 'right' && Boolean(currentSlide.value?.image_url)
})

const isCenterAligned = computed(() => {
  return currentSlide.value?.text_align === 'center'
})

const badgeClasses = computed(() => {
  const variant = currentSlide.value?.tag_variant || 'primary'
  if (variant === 'gold') {
    return 'bg-amber-400/20 text-amber-300 border-amber-400/40 shadow-amber-950/40'
  }
  if (variant === 'accent') {
    return 'bg-red-500/20 text-red-300 border-red-500/40 shadow-red-950/40'
  }
  return 'bg-guaiqui-primary text-white border-white/20 shadow-emerald-950/40'
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

// Autoplay (4.5s)
const startAutoplay = () => {
  stopAutoplay()
  if (props.slides.length <= 1) return
  autoplayInterval = setInterval(() => {
    if (!isPaused.value && !isDragging.value) {
      nextSlide()
    }
  }, 4500)
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

const handleCtaClick = (buttonType: 'primary' | 'secondary') => {
  if (!currentSlide.value) return
  trackEvent('click_hero_carousel_slide', {
    slideId: currentSlide.value.id,
    title: currentSlide.value.title,
    index: currentIndex.value,
    button: buttonType
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

onMounted(async () => {
  await nextTick()
  ctx = gsap.context(() => {
    animateSlideTransition('fade')
  }, slideContainer.value || undefined)
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
    class="relative w-full min-h-[580px] sm:min-h-[640px] lg:min-h-[720px] flex items-center overflow-hidden bg-slate-950 text-white select-none cursor-grab active:cursor-grabbing"
    @mouseenter="isPaused = true"
    @mouseleave="handleMouseLeave"
    @touchstart="handleTouchStart"
    @touchmove="handleTouchMove"
    @touchend="handleTouchEnd"
    @mousedown="handleMouseDown"
    @mousemove="handleMouseMove"
    @mouseup="handleMouseUp"
  >
    <!-- Background Layer (Full-bleed mode) -->
    <div
      v-if="!isRightImageLayout"
      class="absolute inset-0 z-0 overflow-hidden pointer-events-none"
    >
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
      <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/70 to-slate-950/40"></div>
      <div class="absolute inset-0 bg-gradient-to-r from-slate-950/95 via-slate-950/65 to-transparent"></div>
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-emerald-500/15 via-transparent to-black/60"></div>
    </div>

    <!-- Base ambient lighting for right-image mode -->
    <div
      v-else
      class="absolute inset-0 z-0 bg-gradient-to-b from-guaiqui-primary-dark via-slate-950 to-slate-950 pointer-events-none overflow-hidden"
    >
      <div class="absolute -top-32 -left-32 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl"></div>
      <div class="absolute top-1/3 -right-32 w-96 h-96 bg-guaiqui-primary/15 rounded-full blur-3xl"></div>
    </div>

    <!-- Main Container Area -->
    <div class="relative z-10 max-w-7xl mx-auto px-6 sm:px-12 lg:px-20 py-16 sm:py-24 w-full">
      <!-- Layout A: Right Image / Split Hero -->
      <div
        v-if="isRightImageLayout"
        ref="slideContentRef"
        class="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center"
      >
        <!-- Left Column: Typography & CTAs -->
        <div class="lg:col-span-7 text-left space-y-6">
          <!-- Tag / Badge -->
          <div
            v-if="currentSlide.tag"
            class="hero-carousel-anim-el inline-flex items-center gap-2 text-xs font-extrabold uppercase px-3.5 py-1.5 rounded-full shadow-lg border tracking-wider"
            :class="badgeClasses"
          >
            <i class="bi bi-star-fill text-[10px]"></i>
            <span>{{ currentSlide.tag }}</span>
          </div>

          <!-- Slide Title -->
          <h1 class="hero-carousel-anim-el font-display font-extrabold text-4xl sm:text-6xl lg:text-7xl uppercase tracking-tight leading-none text-white drop-shadow-xl">
            {{ currentSlide.title }}
          </h1>

          <!-- Slide Subtitle -->
          <p
            v-if="currentSlide.subtitle"
            class="hero-carousel-anim-el text-emerald-100 text-base sm:text-lg lg:text-xl max-w-xl text-left leading-relaxed drop-shadow-md"
          >
            {{ currentSlide.subtitle }}
          </p>

          <!-- Dual CTA Buttons -->
          <div class="hero-carousel-anim-el pt-2 flex flex-wrap items-center justify-start gap-4">
            <NuxtLink v-if="currentSlide.cta_text" :to="currentSlide.cta_url || '/registro'">
              <BaseButton
                variant="primary"
                size="lg"
                class="shadow-xl shadow-emerald-950/80 px-8"
                @click="handleCtaClick('primary')"
              >
                <span>{{ currentSlide.cta_text }}</span>
                <i class="bi bi-arrow-right ml-2"></i>
              </BaseButton>
            </NuxtLink>

            <NuxtLink v-if="currentSlide.cta_secondary_text" :to="currentSlide.cta_secondary_url || '/tienda'">
              <BaseButton
                variant="secondary"
                size="lg"
                class="shadow-lg px-7 bg-white/10 hover:bg-white/20 border border-white/20 text-white"
                @click="handleCtaClick('secondary')"
              >
                <span>{{ currentSlide.cta_secondary_text }}</span>
              </BaseButton>
            </NuxtLink>
          </div>

          <!-- Trust Badges (Dynamic) -->
          <div
            v-if="currentSlide.show_guarantees !== false"
            class="hero-carousel-anim-el flex flex-wrap items-center gap-6 text-xs text-emerald-200/90 pt-3 font-medium"
          >
            <span v-if="currentSlide.guarantee_1" class="flex items-center gap-1.5">
              <i class="bi bi-check-lg text-emerald-400"></i> {{ currentSlide.guarantee_1 }}
            </span>
            <span v-if="currentSlide.guarantee_2" class="flex items-center gap-1.5">
              <i class="bi bi-shield-check text-emerald-400"></i> {{ currentSlide.guarantee_2 }}
            </span>
            <span v-if="currentSlide.guarantee_3" class="flex items-center gap-1.5">
              <i class="bi bi-gem text-emerald-400"></i> {{ currentSlide.guarantee_3 }}
            </span>
          </div>
        </div>

        <!-- Right Column: Prominent Image & Floating Micro-Card -->
        <div class="lg:col-span-5 relative flex items-center justify-center">
          <div class="relative w-full max-w-md aspect-4/3 sm:aspect-square rounded-3xl overflow-hidden shadow-2xl border border-white/10 bg-slate-900/60 group">
            <img
              :src="currentSlide.image_url!"
              :alt="currentSlide.title"
              class="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-700"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-slate-950/70 via-transparent to-transparent pointer-events-none"></div>

            <!-- Floating Micro-Card inside/over the image -->
            <div
              v-if="currentSlide.highlight_title"
              class="absolute bottom-4 left-4 right-4 bg-slate-950/85 backdrop-blur-xl border border-white/15 p-3.5 rounded-2xl shadow-2xl flex items-center gap-3"
            >
              <div class="w-10 h-10 rounded-xl bg-guaiqui-primary/20 border border-guaiqui-primary/40 flex items-center justify-center text-emerald-400 text-lg shrink-0">
                <i class="bi bi-trophy-fill"></i>
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2">
                  <span v-if="currentSlide.highlight_badge" class="text-[9px] font-bold uppercase px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300">
                    {{ currentSlide.highlight_badge }}
                  </span>
                  <span class="text-xs font-bold text-white truncate">{{ currentSlide.highlight_title }}</span>
                </div>
                <p v-if="currentSlide.highlight_subtitle" class="text-[11px] text-slate-300 truncate">
                  {{ currentSlide.highlight_subtitle }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Layout B: Full-bleed Background mode -->
      <div
        v-else
        ref="slideContentRef"
        class="w-full max-w-xl lg:max-w-2xl flex flex-col space-y-6"
        :class="isCenterAligned ? 'text-center items-center justify-center mx-auto' : 'text-left items-start justify-start'"
      >
        <!-- Tag / Badge -->
        <div
          v-if="currentSlide.tag"
          class="hero-carousel-anim-el inline-flex items-center gap-2 text-xs font-extrabold uppercase px-3.5 py-1.5 rounded-full shadow-lg border tracking-wider"
          :class="badgeClasses"
        >
          <i class="bi bi-star-fill text-[10px]"></i>
          <span>{{ currentSlide.tag }}</span>
        </div>

        <!-- Slide Title -->
        <h1 class="hero-carousel-anim-el font-display font-extrabold text-4xl sm:text-6xl lg:text-7xl uppercase tracking-tight leading-none text-white drop-shadow-xl">
          {{ currentSlide.title }}
        </h1>

        <!-- Slide Subtitle -->
        <p
          v-if="currentSlide.subtitle"
          class="hero-carousel-anim-el text-emerald-100 text-base sm:text-lg lg:text-xl max-w-xl leading-relaxed drop-shadow-md"
          :class="isCenterAligned ? 'mx-auto text-center' : 'text-left'"
        >
          {{ currentSlide.subtitle }}
        </p>

        <!-- Dual CTA Buttons -->
        <div
          class="hero-carousel-anim-el pt-2 flex flex-wrap items-center gap-4"
          :class="isCenterAligned ? 'justify-center' : 'justify-start'"
        >
          <NuxtLink v-if="currentSlide.cta_text" :to="currentSlide.cta_url || '/registro'">
            <BaseButton
              variant="primary"
              size="lg"
              class="shadow-xl shadow-emerald-950/80 px-8"
              @click="handleCtaClick('primary')"
            >
              <span>{{ currentSlide.cta_text }}</span>
              <i class="bi bi-arrow-right ml-2"></i>
            </BaseButton>
          </NuxtLink>

          <NuxtLink v-if="currentSlide.cta_secondary_text" :to="currentSlide.cta_secondary_url || '/tienda'">
            <BaseButton
              variant="secondary"
              size="lg"
              class="shadow-lg px-7 bg-white/10 hover:bg-white/20 border border-white/20 text-white"
              @click="handleCtaClick('secondary')"
            >
              <span>{{ currentSlide.cta_secondary_text }}</span>
            </BaseButton>
          </NuxtLink>
        </div>

        <!-- Floating Highlight Card in Full-Bleed mode -->
        <div
          v-if="currentSlide.highlight_title"
          class="hero-carousel-anim-el mt-4 bg-slate-950/80 backdrop-blur-xl border border-white/15 p-3.5 rounded-2xl shadow-2xl flex items-center gap-3.5 max-w-md"
        >
          <div class="w-10 h-10 rounded-xl bg-guaiqui-primary/20 border border-guaiqui-primary/40 flex items-center justify-center text-emerald-400 text-lg shrink-0">
            <i class="bi bi-trophy-fill"></i>
          </div>
          <div class="min-w-0 flex-1 text-left">
            <div class="flex items-center gap-2">
              <span v-if="currentSlide.highlight_badge" class="text-[9px] font-bold uppercase px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300">
                {{ currentSlide.highlight_badge }}
              </span>
              <span class="text-xs font-bold text-white truncate">{{ currentSlide.highlight_title }}</span>
            </div>
            <p v-if="currentSlide.highlight_subtitle" class="text-[11px] text-slate-300 truncate">
              {{ currentSlide.highlight_subtitle }}
            </p>
          </div>
        </div>

        <!-- Trust Badges (Dynamic) -->
        <div
          v-if="currentSlide.show_guarantees !== false"
          class="hero-carousel-anim-el flex flex-wrap items-center gap-6 text-xs text-emerald-200/90 pt-3 font-medium"
          :class="isCenterAligned ? 'justify-center' : 'justify-start'"
        >
          <span v-if="currentSlide.guarantee_1" class="flex items-center gap-1.5">
            <i class="bi bi-check-lg text-emerald-400"></i> {{ currentSlide.guarantee_1 }}
          </span>
          <span v-if="currentSlide.guarantee_2" class="flex items-center gap-1.5">
            <i class="bi bi-shield-check text-emerald-400"></i> {{ currentSlide.guarantee_2 }}
          </span>
          <span v-if="currentSlide.guarantee_3" class="flex items-center gap-1.5">
            <i class="bi bi-gem text-emerald-400"></i> {{ currentSlide.guarantee_3 }}
          </span>
        </div>
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

    <!-- Bottom Controls: Dots -->
    <div
      v-if="slides.length > 1"
      class="absolute bottom-6 sm:bottom-8 left-0 right-0 z-20 flex items-center justify-center gap-4 px-4 pointer-events-none"
    >
      <div class="pointer-events-auto flex items-center gap-3 bg-black/50 backdrop-blur-md px-5 py-2.5 rounded-full shadow-xl border border-white/10">
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
          ></button>
        </div>
      </div>
    </div>
  </div>
</template>
