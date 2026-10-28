<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { teamStats } from '~/data/landingData'
import { useGSAP } from '~/composables/useGSAP'

const { gsap } = useGSAP()
const bandRef = ref<HTMLElement | null>(null)
let ctx: gsap.Context | null = null

// Reactive displayed values for animated counter numbers (Receta 2 de docs/guia-gsap.md)
const displayedStats = ref(
  teamStats.map((s) => ({
    ...s,
    numericTarget: parseFloat(s.value.replace(/[^0-9.]/g, '')) || 0,
    prefix: s.value.startsWith('$') ? '$' : '',
    suffix: s.value.endsWith('+') ? '+' : s.value.endsWith('%') ? '%' : '',
    currentDisplay: s.value.startsWith('$') ? '$0' : '0',
  }))
)

onMounted(async () => {
  await nextTick()
  if (!bandRef.value) return

  ctx = gsap.context(() => {
    const mm = gsap.matchMedia()
    mm.add(
      {
        reduceMotion: '(prefers-reduced-motion: reduce)',
        all: '(min-width: 0px)',
      },
      (context) => {
        const { reduceMotion } = context.conditions as { reduceMotion: boolean }

        // Si el usuario prefiere movimiento reducido, mostrar valores finales directamente
        if (reduceMotion) {
          displayedStats.value.forEach((st) => {
            st.currentDisplay = st.value
          })
          return
        }

        // 1. Animación de entrada de las tarjetas con stagger
        gsap.from('.stat-item', {
          y: 28,
          scale: 0.94,
          autoAlpha: 0,
          duration: 0.7,
          stagger: 0.12,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: bandRef.value,
            start: 'top 85%',
            once: true,
          },
        })

        // 2. Receta 2 de docs/guia-gsap.md: Cifras que suben al entrar en pantalla con snap
        displayedStats.value.forEach((stat, idx) => {
          if (stat.numericTarget === 0) {
            stat.currentDisplay = stat.value
            return
          }

          const counterObj = { v: 0 }
          gsap.to(counterObj, {
            v: stat.numericTarget,
            duration: 1.8,
            ease: 'power2.out',
            snap: { v: 1 },
            scrollTrigger: {
              trigger: bandRef.value,
              start: 'top 85%',
              once: true,
            },
            onUpdate: () => {
              stat.currentDisplay = `${stat.prefix}${counterObj.v}${stat.suffix}`
            },
            onComplete: () => {
              stat.currentDisplay = stat.value
            },
          })
        })
      }
    )
  }, bandRef.value)
})

onUnmounted(() => {
  ctx?.revert()
})
</script>

<template>
  <section ref="bandRef" class="py-16 bg-gradient-to-r from-guaiqui-primary-dark via-guaiqui-primary to-emerald-950 text-white px-4 sm:px-8 shadow-inner overflow-hidden">
    <div class="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8 text-center divide-y md:divide-y-0 md:divide-x divide-emerald-700/60">
      <div v-for="(stat, idx) in displayedStats" :key="idx" class="stat-item pt-4 md:pt-0 px-2 space-y-1">
        <div class="font-display font-extrabold text-4xl sm:text-5xl text-amber-400 tabular-nums">
          {{ stat.currentDisplay }}
        </div>
        <div class="font-display font-bold text-lg text-white uppercase tracking-tight">
          {{ stat.label }}
        </div>
        <div class="text-xs text-emerald-200/80">
          {{ stat.note }}
        </div>
      </div>
    </div>
  </section>
</template>

