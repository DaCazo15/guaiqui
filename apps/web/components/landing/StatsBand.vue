<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { teamStats } from '~/data/landingData'
import { useGSAP } from '~/composables/useGSAP'

const { gsap } = useGSAP()
const bandRef = ref<HTMLElement | null>(null)
let ctx: gsap.Context | null = null

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
        if (reduceMotion) return

        gsap.from('.stat-item', {
          y: 24,
          scale: 0.92,
          opacity: 0,
          duration: 0.6,
          stagger: 0.12,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: bandRef.value,
            start: 'top 85%',
            toggleActions: 'play none none none',
          },
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
      <div v-for="(stat, idx) in teamStats" :key="idx" class="stat-item pt-4 md:pt-0 px-2 space-y-1">
        <div class="font-display font-extrabold text-4xl sm:text-5xl text-amber-400 tabular-nums">
          {{ stat.value }}
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
