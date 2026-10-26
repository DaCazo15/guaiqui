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

let ctx: gsap.Context | null = null

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

// Actualizar porcentaje y tarjeta activa en tiempo real
const updateScrollState = () => {
  const wrapper = trackWrapperRef.value
  if (!wrapper) return
  const maxScroll = wrapper.scrollWidth - wrapper.clientWidth
  if (maxScroll > 0) {
    const progress = Math.max(0, Math.min(1, wrapper.scrollLeft / maxScroll))
    scrollProgress.value = Math.round(progress * 100)
    const cardIdx = Math.round(progress * (milestones.value.length - 1))
    currentIndex.value = Math.min(milestones.value.length - 1, Math.max(0, cardIdx))
  } else {
    scrollProgress.value = 0
    currentIndex.value = 0
  }
}

// Navegar suavemente con GSAP hacia una tarjeta por índice
const scrollToCard = (index: number) => {
  const targetIdx = Math.max(0, Math.min(milestones.value.length - 1, index))
  currentIndex.value = targetIdx
  const wrapper = trackWrapperRef.value
  const track = trackEl.value
  if (!wrapper || !track) return

  const card = track.children[targetIdx] as HTMLElement | undefined
  if (card) {
    const targetLeft = card.offsetLeft - (wrapper.clientWidth - card.clientWidth) / 2
    gsap.to(wrapper, {
      scrollLeft: Math.max(0, targetLeft),
      duration: 0.5,
      ease: 'power2.out',
      onUpdate: updateScrollState,
      onComplete: updateScrollState,
    })
  }
}

const handlePrev = () => scrollToCard(currentIndex.value - 1)
const handleNext = () => scrollToCard(currentIndex.value + 1)
const handleSelectYear = (_year: string, index: number) => scrollToCard(index)

// 1. Manejador de la Rueda del Ratón (Mouse Wheel) para desplazamiento horizontal fluido
const handleWheel = (e: WheelEvent) => {
  const wrapper = trackWrapperRef.value
  if (!wrapper) return

  const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY
  if (Math.abs(delta) < 4) return

  const maxScroll = wrapper.scrollWidth - wrapper.clientWidth
  if (maxScroll <= 0) return

  const atStart = wrapper.scrollLeft <= 5
  const atEnd = wrapper.scrollLeft >= maxScroll - 5

  // Si se desliza hacia adelante y no ha llegado al final, o hacia atrás y no está al inicio:
  // Convertir el desplazamiento vertical de la rueda en scroll horizontal interactivo
  if ((delta > 0 && !atEnd) || (delta < 0 && !atStart)) {
    e.preventDefault()
    wrapper.scrollLeft += delta * 1.3
    updateScrollState()
  }
}

// 2. Manejador de Arrastre con el Ratón / Touch (Mouse Drag)
let isDragging = false
let startX = 0
let scrollLeftStart = 0
let hasMoved = false

const handlePointerDown = (e: PointerEvent) => {
  const wrapper = trackWrapperRef.value
  if (!wrapper) return
  isDragging = true
  hasMoved = false
  startX = e.pageX - wrapper.offsetLeft
  scrollLeftStart = wrapper.scrollLeft
  wrapper.style.cursor = 'grabbing'
}

const handlePointerMove = (e: PointerEvent) => {
  if (!isDragging) return
  const wrapper = trackWrapperRef.value
  if (!wrapper) return
  const x = e.pageX - wrapper.offsetLeft
  const walk = (x - startX) * 1.4
  if (Math.abs(walk) > 4) {
    hasMoved = true
    wrapper.scrollLeft = scrollLeftStart - walk
    updateScrollState()
  }
}

const handlePointerUp = () => {
  isDragging = false
  const wrapper = trackWrapperRef.value
  if (wrapper) {
    wrapper.style.cursor = 'grab'
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

  // Inicializar GSAP ScrollTrigger para animar la entrada de la sección
  if (sectionContainer.value && trackEl.value && process.client) {
    ctx = gsap.context(() => {
      const mm = gsap.matchMedia()
      mm.add(
        {
          reduceMotion: '(prefers-reduced-motion: reduce)',
          all: '(min-width: 0px)',
        },
        (context) => {
          const { reduceMotion } = context.conditions as { reduceMotion: boolean }
          if (reduceMotion) return

          gsap.from('.history-card', {
            y: 35,
            autoAlpha: 0,
            duration: 0.8,
            stagger: 0.12,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: sectionContainer.value,
              start: 'top 80%',
              once: true,
            },
          })
        }
      )
    }, sectionContainer.value)

    updateScrollState()
    ScrollTrigger?.refresh()
  }
})

onUnmounted(() => {
  ctx?.revert()
})
</script>

<template>
  <section
    id="historia"
    ref="sectionContainer"
    class="relative bg-gradient-to-b from-slate-950 via-[#031d10] to-slate-950 text-white overflow-hidden py-10 sm:py-14 px-4 sm:px-8"
  >
    <!-- Efectos lumínicos de cancha y atmósfera nocturna -->
    <div class="absolute inset-0 bg-[radial-gradient(ellipse_80%_60%_at_50%_-20%,rgba(16,185,129,0.18),rgba(255,255,255,0))] pointer-events-none" />
    <div class="absolute -left-40 top-1/3 w-96 h-96 bg-emerald-600/10 rounded-full blur-3xl pointer-events-none" />
    <div class="absolute -right-40 bottom-1/4 w-96 h-96 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />

    <!-- CONTENEDOR PRINCIPAL -->
    <div class="max-w-7xl mx-auto w-full flex flex-col justify-between gap-6 relative z-10">
      
      <!-- 1. HEADER MODULAR: Título, Píldoras de Años, Progreso y Flechas -->
      <HistoryTimelineHeader
        :scroll-progress="scrollProgress"
        :milestones="milestones"
        :active-year="activeYear"
        @prev="handlePrev"
        @next="handleNext"
        @select-year="handleSelectYear"
      />

      <!-- 2. TRACK HORIZONTAL INTERACTIVO: Soporta Rueda del Ratón, Arrastre Drag y Swipe -->
      <div
        ref="trackWrapperRef"
        class="py-4 overflow-x-auto scrollbar-none cursor-grab active:cursor-grabbing select-none"
        @scroll.passive="updateScrollState"
        @wheel="handleWheel"
        @pointerdown="handlePointerDown"
        @pointermove="handlePointerMove"
        @pointerup="handlePointerUp"
        @pointercancel="handlePointerUp"
        @mouseleave="handlePointerUp"
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
/* Ocultar barra de scroll estándar para experiencia inmersiva */
.scrollbar-none::-webkit-scrollbar {
  display: none;
}
.scrollbar-none {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
