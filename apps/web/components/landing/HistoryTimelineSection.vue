<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useGSAP } from '~/composables/useGSAP'
import { historyMilestones as defaultMilestones } from '~/data/landingData'
import HistoryTimelineHeader from './history/HistoryTimelineHeader.vue'
import HistoryTimelineCard from './history/HistoryTimelineCard.vue'
import HistoryTimelineFooter from './history/HistoryTimelineFooter.vue'

interface MilestoneItem {
  id: string
  year: string
  title: string
  description: string
  badge?: string
  isChampionship?: boolean
}

const supabase = useSupabaseClient()
const { gsap, ScrollTrigger } = useGSAP()

const sectionContainer = ref<HTMLElement | null>(null)
const trackWrapperRef = ref<HTMLElement | null>(null)
const trackEl = ref<HTMLElement | null>(null)

const scrollProgress = ref(0)
const currentIndex = ref(0)
const milestones = ref<MilestoneItem[]>([])
const loading = ref(true)

let mm: gsap.MatchMedia | null = null
let tween: gsap.core.Tween | null = null

const championshipYears = ['1978 - 1982', '1997', '2007', '2021', '2024']

const activeYear = computed(() => milestones.value[currentIndex.value]?.year)

const formatMilestones = (rawItems: any[]): MilestoneItem[] => {
  return rawItems.map((m, idx) => {
    const isChamp = championshipYears.some((cy) => m.year?.includes(cy) || cy.includes(m.year))
    let badge = 'Hito Insular'
    if (m.year?.includes('1977')) badge = 'Nacimiento de la Tribu'
    else if (isChamp) badge = 'Título de Campeón'
    else if (m.year?.includes('2026')) badge = 'Nueva Era Digital'

    return {
      id: m.id || `m-${idx}`,
      year: m.year,
      title: m.title,
      description: m.text || m.description,
      badge,
      isChampionship: isChamp,
    }
  })
}

// Navegación interactiva por índice (teclado, flechas o píldoras de año)
const goToIndex = (index: number) => {
  const targetIdx = Math.max(0, Math.min(milestones.value.length - 1, index))
  currentIndex.value = targetIdx

  if (process.client && window.innerWidth >= 1024 && tween?.scrollTrigger) {
    const st = tween.scrollTrigger
    const progress = targetIdx / Math.max(1, milestones.value.length - 1)
    const targetScroll = st.start + progress * (st.end - st.start)
    window.scrollTo({ top: targetScroll, behavior: 'smooth' })
  } else if (trackEl.value) {
    const cardEl = trackEl.value.children[targetIdx] as HTMLElement | undefined
    if (cardEl) {
      cardEl.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' })
    }
  }
}

const handlePrev = () => goToIndex(currentIndex.value - 1)
const handleNext = () => goToIndex(currentIndex.value + 1)
const handleSelectYear = (_year: string, index: number) => goToIndex(index)

// En móvil: calcular progreso a partir del scroll nativo del track
const handleMobileTrackScroll = (e: Event) => {
  if (process.client && window.innerWidth < 1024) {
    const target = e.target as HTMLElement
    if (!target) return
    const maxScroll = target.scrollWidth - target.clientWidth
    if (maxScroll > 0) {
      const progress = target.scrollLeft / maxScroll
      scrollProgress.value = Math.round(progress * 100)
      const cardIdx = Math.round(progress * (milestones.value.length - 1))
      currentIndex.value = Math.min(milestones.value.length - 1, Math.max(0, cardIdx))
    }
  }
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await supabase
      .from('history_milestones')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      const items = formatMilestones(data)
      if (!items.some((i) => i.year.includes('2026'))) {
        items.push({
          id: 'm-2026',
          year: '2026',
          title: 'Plataforma Fan Zone Oficial',
          description: 'Lanzamiento de la plataforma digital con economía inmutable de puntos y fidelización directa para la Tribu.',
          badge: 'Nueva Era Digital',
          isChampionship: false,
        })
      }
      milestones.value = items
    } else {
      milestones.value = formatMilestones(defaultMilestones)
    }
  } catch {
    milestones.value = formatMilestones(defaultMilestones)
  } finally {
    loading.value = false
  }

  await nextTick()

  // Inicializar GSAP ScrollTrigger con Pinned Horizontal Scroll según Guía GSAP
  if (sectionContainer.value && trackEl.value && process.client) {
    mm = gsap.matchMedia()

    mm.add(
      {
        isDesktop: '(min-width: 1024px)',
        isMobile: '(max-width: 1023px)',
        reduceMotion: '(prefers-reduced-motion: reduce)',
      },
      (context) => {
        const { isDesktop, reduceMotion } = context.conditions as {
          isDesktop: boolean
          isMobile: boolean
          reduceMotion: boolean
        }

        if (isDesktop && !reduceMotion) {
          const track = trackEl.value
          const container = sectionContainer.value
          if (!track || !container) return

          // Calcular distancia exacta de desplazamiento horizontal
          const getScrollDistance = () => {
            const viewportW = window.innerWidth
            return Math.max(0, track.scrollWidth - viewportW + 180)
          }

          tween = gsap.to(track, {
            x: () => -getScrollDistance(),
            ease: 'none', // Regla estricta de guia-gsap: ease "none" para sincronizar scroll
            scrollTrigger: {
              trigger: container,
              pin: true,
              scrub: 1,
              start: 'top top',
              end: () => `+=${getScrollDistance()}`,
              invalidateOnRefresh: true,
              anticipatePin: 1,
              onUpdate: (self) => {
                scrollProgress.value = Math.round(self.progress * 100)
                const cardIndex = Math.round(self.progress * (milestones.value.length - 1))
                currentIndex.value = Math.min(milestones.value.length - 1, Math.max(0, cardIndex))
              },
            },
          })
        }
      }
    )

    ScrollTrigger?.refresh()
  }
})

onUnmounted(() => {
  mm?.revert()
})
</script>

<template>
  <section
    id="historia"
    ref="sectionContainer"
    class="relative bg-gradient-to-b from-slate-950 via-[#031d10] to-slate-950 text-white overflow-hidden"
  >
    <!-- Efectos lumínicos de cancha y atmósfera nocturna -->
    <div class="absolute inset-0 bg-[radial-gradient(ellipse_80%_60%_at_50%_-20%,rgba(16,185,129,0.18),rgba(255,255,255,0))] pointer-events-none" />
    <div class="absolute -left-40 top-1/3 w-96 h-96 bg-emerald-600/10 rounded-full blur-3xl pointer-events-none" />
    <div class="absolute -right-40 bottom-1/4 w-96 h-96 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />

    <!-- CONTENEDOR PRINCIPAL: En Desktop se fija (Pin) a pantalla completa -->
    <div class="h-full min-h-[580px] lg:h-screen flex flex-col justify-between pt-20 pb-10 px-4 sm:px-8 max-w-7xl mx-auto w-full relative z-10">
      
      <!-- 1. HEADER MODULAR: Título, Píldoras de Años, Progreso y Flechas -->
      <HistoryTimelineHeader
        :scroll-progress="scrollProgress"
        :milestones="milestones"
        :active-year="activeYear"
        @prev="handlePrev"
        @next="handleNext"
        @select-year="handleSelectYear"
      />

      <!-- 2. TRACK HORIZONTAL (Animado con GSAP en Desktop / Swipe Nativo en Móvil) -->
      <div
        ref="trackWrapperRef"
        class="my-auto py-6 overflow-x-auto lg:overflow-visible scrollbar-none snap-x snap-mandatory lg:snap-none"
        @scroll="handleMobileTrackScroll"
      >
        <div
          ref="trackEl"
          class="flex items-stretch gap-6 sm:gap-8 px-2 sm:px-4 w-max"
        >
          <HistoryTimelineCard
            v-for="(m, idx) in milestones"
            :key="m.id"
            :milestone="m"
            :index="idx"
            :is-active="idx === currentIndex"
          />
        </div>
      </div>

      <!-- 3. FOOTER MODULAR: Metadatos y Campeonatos -->
      <HistoryTimelineFooter />

    </div>
  </section>
</template>

<style scoped>
/* Ocultar barra de scroll para navegación swipe móvil */
.scrollbar-none::-webkit-scrollbar {
  display: none;
}
.scrollbar-none {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
