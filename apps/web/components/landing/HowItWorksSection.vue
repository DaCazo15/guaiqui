<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { howItWorksSteps } from '~/data/landingData'
import { useGSAP } from '~/composables/useGSAP'

const { gsap } = useGSAP()
const sectionRef = ref<HTMLElement | null>(null)
let ctx: gsap.Context | null = null

onMounted(async () => {
  await nextTick()
  if (!sectionRef.value) return

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

        gsap.from('.step-card', {
          y: 35,
          opacity: 0,
          duration: 0.7,
          stagger: 0.14,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: sectionRef.value,
            start: 'top 80%',
            toggleActions: 'play none none none',
          },
        })
      }
    )
  }, sectionRef.value)
})

onUnmounted(() => {
  ctx?.revert()
})
</script>

<template>
  <section id="como-funciona" ref="sectionRef" class="py-16 sm:py-24 bg-white px-4 sm:px-8 scroll-mt-20">
    <div class="max-w-6xl mx-auto space-y-12">
      <!-- Section Header -->
      <div class="text-center max-w-3xl mx-auto space-y-3">
        <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
          Paso a Paso
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight">
          ¿Cómo funciona el Fan Zone?
        </h2>
        <p class="text-guaiqui-text-muted text-base">
          4 sencillos pasos para convertir tu pasión insular en recompensas reales sin pagar un solo bolívar.
        </p>
      </div>

      <!-- Steps Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <BaseCard
          v-for="step in howItWorksSteps"
          :key="step.step"
          variant="outline"
          :spotlight="true"
          class="step-card relative hover:border-guaiqui-primary hover:shadow-guaiqui-md transition-all duration-200"
        >
          <div class="space-y-4">
            <!-- Step Number Badge -->
            <div class="w-12 h-12 rounded-full bg-guaiqui-primary text-white font-display font-bold text-xl flex items-center justify-center shadow-sm">
              0{{ step.step }}
            </div>

            <h3 class="font-display font-bold text-xl text-guaiqui-text uppercase">
              {{ step.title }}
            </h3>

            <p class="text-sm text-guaiqui-text-muted leading-relaxed">
              {{ step.description }}
            </p>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
