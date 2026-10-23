<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useGSAP } from '~/composables/useGSAP'
import { historyMilestones as defaultMilestones, type Milestone } from '~/data/landingData'

interface MilestoneItem {
  id: string
  year: string
  title: string
  description: string
  badge?: string
  isChampionship?: boolean
}

const supabase = useSupabaseClient()
const { gsap } = useGSAP()

const sectionContainer = ref<HTMLElement | null>(null)
const trackEl = ref<HTMLElement | null>(null)
const scrollProgress = ref(0)
const milestones = ref<MilestoneItem[]>([])
const loading = ref(true)

let mm: gsap.MatchMedia | null = null

const championshipYears = ['1978 - 1982', '1997', '2007', '2021', '2024']

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
      // Asegurar que el hito de la Fan Zone 2026 cierre la saga
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

  // Inicializar GSAP ScrollTrigger con Pinned Horizontal Scroll
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

          const totalDistance = Math.max(0, track.scrollWidth - window.innerWidth + 200)

          gsap.to(track, {
            x: () => -totalDistance,
            ease: 'none',
            scrollTrigger: {
              trigger: container,
              pin: true,
              scrub: 1,
              start: 'top top',
              end: () => `+=${totalDistance}`,
              invalidateOnRefresh: true,
              onUpdate: (self) => {
                scrollProgress.value = Math.round(self.progress * 100)
              },
            },
          })
        }
      },
      sectionContainer.value
    )
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
    <div class="h-full min-h-[580px] lg:h-screen flex flex-col justify-between py-12 lg:py-14 px-4 sm:px-8 max-w-7xl mx-auto w-full relative z-10">
      
      <!-- 1. HEADER DE LA SECCIÓN CON CONTADOR DE PROGRESO CINÉTICO -->
      <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 border-b border-emerald-900/60 pb-6 shrink-0">
        <div class="space-y-2">
          <div class="inline-flex items-center gap-2 bg-emerald-950/80 border border-emerald-500/30 px-3.5 py-1 rounded-full text-xs font-mono font-bold text-emerald-400 uppercase tracking-widest">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            49 Años de Tradición Insular
          </div>
          <h2 class="font-display font-black text-3xl sm:text-4xl lg:text-5xl uppercase tracking-tight text-white">
            Línea del Tiempo <span class="text-emerald-400">Histórica</span>
          </h2>
          <p class="text-xs sm:text-sm text-slate-300 max-w-xl">
            De La Asunción a la inmortalidad. Desliza para revivir las gestas y títulos que consagraron a Guaiqueríes de Margarita.
          </p>
        </div>

        <!-- Indicador de Desplazamiento Horizontal con Barra y Porcentaje -->
        <div class="hidden lg:flex flex-col items-end gap-1.5 min-w-[200px]">
          <div class="flex items-center justify-between w-full text-xs font-mono">
            <span class="text-slate-400">Progreso Histórico</span>
            <span class="font-bold text-amber-400 tabular-nums">{{ scrollProgress }}%</span>
          </div>
          <div class="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden border border-white/10">
            <div
              class="h-full bg-gradient-to-r from-emerald-500 via-emerald-400 to-amber-400 rounded-full transition-all duration-150"
              :style="{ width: `${scrollProgress}%` }"
            />
          </div>
          <span class="text-[10px] text-slate-400 flex items-center gap-1">
            <i class="bi bi-mouse text-emerald-400"></i> Desplaza verticalmente para navegar
          </span>
        </div>
      </div>

      <!-- 2. TRACK HORIZONTAL (Animado con GSAP en Desktop / Swipe Nativo en Móvil) -->
      <div class="my-auto py-6 overflow-x-auto lg:overflow-visible scrollbar-none snap-x snap-mandatory lg:snap-none">
        <div
          ref="trackEl"
          class="flex items-stretch gap-6 sm:gap-8 px-2 sm:px-4 w-max"
        >
          <div
            v-for="(m, idx) in milestones"
            :key="m.id"
            class="snap-center w-[300px] sm:w-[380px] lg:w-[420px] shrink-0 bg-slate-900/80 backdrop-blur-xl border rounded-guaiqui-2xl p-6 sm:p-7 flex flex-col justify-between relative overflow-hidden transition-all duration-300 group hover:border-emerald-400/80 hover:shadow-[0_10px_35px_-10px_rgba(16,185,129,0.3)]"
            :class="[
              m.isChampionship
                ? 'border-amber-400/50 bg-gradient-to-b from-slate-900/95 via-emerald-950/40 to-slate-900/95'
                : 'border-white/15',
            ]"
          >
            <!-- Marca de agua gigante con el Año en el fondo -->
            <div class="font-display font-black text-7xl sm:text-8xl text-white/[0.04] absolute -right-2 -bottom-2 select-none pointer-events-none group-hover:text-emerald-400/10 transition-colors">
              {{ m.year.split(' ')[0] }}
            </div>

            <!-- Cabecera de la Tarjeta -->
            <div class="space-y-3 relative z-10">
              <div class="flex items-center justify-between gap-2">
                <!-- Badge de Tipo de Hito -->
                <span
                  class="text-[10px] font-extrabold uppercase tracking-wider px-2.5 py-1 rounded-md border"
                  :class="[
                    m.isChampionship
                      ? 'bg-amber-400/20 text-amber-300 border-amber-400/40'
                      : 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
                  ]"
                >
                  <i v-if="m.isChampionship" class="bi bi-trophy-fill mr-1 text-amber-400"></i>
                  {{ m.badge }}
                </span>

                <!-- Número de Orden -->
                <span class="text-xs font-mono font-bold text-slate-500">
                  #0{{ idx + 1 }}
                </span>
              </div>

              <!-- Año Destacado -->
              <div class="font-display font-black text-3xl sm:text-4xl text-amber-400 tracking-tight flex items-baseline gap-2">
                <span>{{ m.year }}</span>
                <span v-if="m.isChampionship" class="text-xs font-normal text-amber-300 font-body">
                  ★ Corona Nacional
                </span>
              </div>

              <!-- Título del Hito -->
              <h3 class="font-display font-bold text-lg sm:text-xl text-white uppercase tracking-wide leading-snug group-hover:text-emerald-300 transition-colors">
                {{ m.title }}
              </h3>

              <!-- Narrativa Histórica -->
              <p class="text-xs sm:text-sm text-slate-300 leading-relaxed pt-1">
                {{ m.description }}
              </p>
            </div>

            <!-- Pie de la Tarjeta con Detalle de Identidad Insular -->
            <div class="mt-6 pt-4 border-t border-white/10 flex items-center justify-between text-[11px] text-slate-400 relative z-10">
              <span class="flex items-center gap-1.5">
                <i class="bi bi-geo-alt-fill text-emerald-400"></i>
                La Asunción, Nva. Esparta
              </span>
              <span class="font-mono text-emerald-400/80 font-semibold uppercase">
                Tribu Verde
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- 3. FOOTER DEL PANEL CON LÍNEA DE TIEMPO INTERACTIVA -->
      <div class="pt-4 border-t border-emerald-900/40 flex items-center justify-between text-xs text-slate-400 shrink-0">
        <div class="flex items-center gap-2">
          <i class="bi bi-shield-check text-emerald-400 text-base"></i>
          <span>Archivo Histórico Oficial de Guaiqueríes de Margarita</span>
        </div>
        <div class="flex items-center gap-3">
          <span class="hidden sm:inline">1977 — 2026</span>
          <span class="px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 font-mono text-[10px] uppercase font-bold">
            9 Campeonatos
          </span>
        </div>
      </div>

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
