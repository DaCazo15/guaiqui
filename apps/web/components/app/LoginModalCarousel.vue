<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useSupabaseClient } from '#imports'
import { useAnalytics } from '~/composables/useAnalytics'

interface ModalSlide {
  id: string
  position: number
  image_url?: string | null
  title: string
  subtitle?: string | null
  cta_label: string
  cta_url: string
}

const supabase = useSupabaseClient()
const router = useRouter()
const { trackEvent } = useAnalytics()

const isOpen = ref(false)
const slides = ref<ModalSlide[]>([])
const currentIndex = ref(0)
const failedImages = ref<Record<string, boolean>>({})

let autoAdvanceTimer: number | null = null
const isHoveredOrFocused = ref(false)
const touchStartX = ref(0)
const touchEndX = ref(0)
const modalRef = ref<HTMLElement | null>(null)
let previousFocusedElement: HTMLElement | null = null

const currentSlide = computed(() => slides.value[currentIndex.value] || null)

onMounted(async () => {
  if (typeof window === 'undefined') return

  // Check if already shown in this login session
  const alreadyShown = sessionStorage.getItem('guaiqui_login_modal_shown')
  if (alreadyShown === 'true') return

  try {
    const { data, error } = await supabase.rpc('get_login_modal')
    if (error || !data || !Array.isArray(data) || data.length === 0) return

    slides.value = data
    isOpen.value = true
    sessionStorage.setItem('guaiqui_login_modal_shown', 'true')

    previousFocusedElement = document.activeElement as HTMLElement
    trackEvent('login_modal_viewed')
    trackSlideView(0)

    nextTick(() => {
      modalRef.value?.focus()
      startAutoAdvance()
    })
  } catch (err) {
    console.warn('Error fetching login modal slides:', err)
  }
})

onUnmounted(() => {
  stopAutoAdvance()
})

const trackSlideView = (index: number) => {
  const slide = slides.value[index]
  if (slide) {
    trackEvent('login_modal_slide_viewed', { position: slide.position, title: slide.title })
  }
}

const startAutoAdvance = () => {
  stopAutoAdvance()

  // Check prefers-reduced-motion
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    return
  }

  autoAdvanceTimer = window.setInterval(() => {
    if (!isHoveredOrFocused.value && slides.value.length > 1) {
      nextSlide()
    }
  }, 6000)
}

const stopAutoAdvance = () => {
  if (autoAdvanceTimer) {
    clearInterval(autoAdvanceTimer)
    autoAdvanceTimer = null
  }
}

const goToSlide = (index: number) => {
  if (index >= 0 && index < slides.value.length) {
    currentIndex.value = index
    trackSlideView(index)
  }
}

const nextSlide = () => {
  const nextIdx = (currentIndex.value + 1) % slides.value.length
  goToSlide(nextIdx)
}

const prevSlide = () => {
  const prevIdx = (currentIndex.value - 1 + slides.value.length) % slides.value.length
  goToSlide(prevIdx)
}

const closeModal = () => {
  isOpen.value = false
  stopAutoAdvance()
  trackEvent('login_modal_closed')
  if (previousFocusedElement && typeof previousFocusedElement.focus === 'function') {
    previousFocusedElement.focus()
  }
}

const handleCtaClick = () => {
  if (!currentSlide.value) return

  const slide = currentSlide.value
  trackEvent('login_modal_cta_clicked', { position: slide.position, cta_url: slide.cta_url })

  closeModal()

  if (slide.cta_url.startsWith('/')) {
    router.push(slide.cta_url)
  } else {
    window.open(slide.cta_url, '_blank', 'noopener,noreferrer')
  }
}

const handleKeyDown = (e: KeyboardEvent) => {
  if (!isOpen.value) return

  if (e.key === 'Escape') {
    closeModal()
  } else if (e.key === 'ArrowRight') {
    nextSlide()
  } else if (e.key === 'ArrowLeft') {
    prevSlide()
  }
}

const handleTouchStart = (e: TouchEvent) => {
  touchStartX.value = e.changedTouches[0].screenX
}

const handleTouchEnd = (e: TouchEvent) => {
  touchEndX.value = e.changedTouches[0].screenX
  handleSwipe()
}

const handleSwipe = () => {
  const diff = touchStartX.value - touchEndX.value
  if (Math.abs(diff) > 40) {
    if (diff > 0) {
      nextSlide()
    } else {
      prevSlide()
    }
  }
}

const onImageError = (slideId: string) => {
  failedImages.value[slideId] = true
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && slides.length > 0"
      class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/75 backdrop-blur-md transition-opacity"
      @keydown="handleKeyDown"
    >
      <div
        ref="modalRef"
        tabindex="-1"
        role="dialog"
        aria-modal="true"
        aria-label="Novedades del Club"
        class="relative w-[92vw] sm:w-full max-w-[720px] max-h-[75vh] bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden flex flex-col focus:outline-none"
        @mouseenter="isHoveredOrFocused = true"
        @mouseleave="isHoveredOrFocused = false"
        @focusin="isHoveredOrFocused = true"
        @focusout="isHoveredOrFocused = false"
        @touchstart="handleTouchStart"
        @touchend="handleTouchEnd"
      >
        <!-- Close Button X -->
        <button
          @click="closeModal"
          class="absolute top-3 right-3 z-30 w-9 h-9 rounded-full bg-slate-950/70 border border-white/20 text-white hover:bg-red-600 flex items-center justify-center transition-all focus:ring-2 focus:ring-emerald-400"
          title="Cerrar ventana"
          aria-label="Cerrar modal de bienvenida"
        >
          <i class="bi bi-x-lg text-sm"></i>
        </button>

        <!-- Slide Media Area (16:9) -->
        <div class="relative w-full aspect-video bg-gradient-to-br from-emerald-950 via-slate-900 to-emerald-900 overflow-hidden flex items-center justify-center">
          <img
            v-if="currentSlide?.image_url && !failedImages[currentSlide.id]"
            :src="currentSlide.image_url"
            :alt="currentSlide.title"
            :loading="currentIndex === 0 ? 'eager' : 'lazy'"
            class="w-full h-full object-cover transition-opacity duration-300"
            @error="onImageError(currentSlide.id)"
          />
          <div v-else class="p-6 text-center space-y-2">
            <img src="/logo.png" alt="Guaiqueríes" class="w-16 h-16 mx-auto object-contain mb-2 opacity-90" />
            <h3 class="font-display text-2xl font-bold uppercase tracking-wider text-amber-400">
              {{ currentSlide?.title }}
            </h3>
          </div>

          <!-- Overlay gradient for text legibility -->
          <div class="absolute inset-0 bg-gradient-to-t from-slate-900 via-slate-900/30 to-transparent"></div>
        </div>

        <!-- Content Body & CTA -->
        <div class="p-5 sm:p-6 space-y-4 flex-1 flex flex-col justify-between overflow-y-auto">
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-[11px] font-mono font-bold uppercase text-emerald-400 tracking-wider">
                Novedades del Club • {{ currentIndex + 1 }} de {{ slides.length }}
              </span>
            </div>
            <h2 class="font-display text-xl sm:text-2xl font-bold text-white uppercase tracking-wide leading-tight">
              {{ currentSlide?.title }}
            </h2>
            <p v-if="currentSlide?.subtitle" class="text-xs sm:text-sm text-slate-300 leading-relaxed">
              {{ currentSlide.subtitle }}
            </p>
          </div>

          <!-- Bottom Bar: Indicators & CTA Button -->
          <div class="pt-3 border-t border-slate-800 flex flex-col sm:flex-row items-center justify-between gap-4">
            <!-- Dots Indicators -->
            <div class="flex items-center gap-2">
              <button
                v-for="(slide, idx) in slides"
                :key="slide.id"
                @click="goToSlide(idx)"
                :class="[
                  'h-2 rounded-full transition-all',
                  idx === currentIndex ? 'w-6 bg-emerald-400' : 'w-2 bg-slate-700 hover:bg-slate-500'
                ]"
                :aria-label="`Ir a la diapositiva ${idx + 1}`"
              ></button>
            </div>

            <!-- Navigation Arrows & CTA Button -->
            <div class="flex items-center gap-2 w-full sm:w-auto justify-end">
              <button
                v-if="slides.length > 1"
                @click="prevSlide"
                class="w-9 h-9 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 flex items-center justify-center transition border border-slate-700"
                aria-label="Anterior diapositiva"
              >
                <i class="bi bi-chevron-left text-xs"></i>
              </button>
              <button
                v-if="slides.length > 1"
                @click="nextSlide"
                class="w-9 h-9 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 flex items-center justify-center transition border border-slate-700"
                aria-label="Siguiente diapositiva"
              >
                <i class="bi bi-chevron-right text-xs"></i>
              </button>

              <button
                @click="handleCtaClick"
                class="flex-1 sm:flex-initial px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition shadow-lg shadow-emerald-950/50 flex items-center justify-center gap-2"
              >
                <span>{{ currentSlide?.cta_label || 'Ver más' }}</span>
                <i class="bi bi-arrow-right text-sm"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
