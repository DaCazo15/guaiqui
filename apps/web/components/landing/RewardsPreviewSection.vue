<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { BaseCard, BaseBadge, BaseButton, PearlAmount, Skeleton } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'
import { useGSAP } from '~/composables/useGSAP'

const { trackEvent } = useAnalytics()
const supabase = useSupabaseClient()
const { gsap, ScrollTrigger } = useGSAP()

const sectionRef = ref<HTMLElement | null>(null)
let ctx: gsap.Context | null = null

const products = ref<any[]>([])
const loading = ref(true)

const initAnimations = () => {
  if (!sectionRef.value || products.value.length === 0) return
  ctx?.revert()
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

        gsap.from('.reward-card', {
          y: 35,
          opacity: 0,
          duration: 0.65,
          stagger: 0.1,
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
  ScrollTrigger?.refresh()
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await supabase
      .from('products')
      .select('*')
      .eq('active', true)
      .order('created_at', { ascending: false })
      .limit(6)
    products.value = data || []
  } catch (_err) {
    products.value = []
  } finally {
    loading.value = false
    await nextTick()
    initAnimations()
  }
})

onUnmounted(() => {
  ctx?.revert()
})

const handleRewardClick = (name: string) => {
  trackEvent('click_reward_preview', { rewardName: name })
}
</script>

<template>
  <section id="premios" ref="sectionRef" class="py-16 sm:py-24 bg-white px-4 sm:px-8 scroll-mt-20">
    <div class="max-w-6xl mx-auto space-y-12">
      <!-- Section Header -->
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <span class="text-xs uppercase font-bold text-guaiqui-primary tracking-widest bg-guaiqui-primary-soft px-3 py-1 rounded-full">
            Catálogo de Canje
          </span>
          <h2 class="font-display font-extrabold text-3xl sm:text-4xl text-guaiqui-text uppercase tracking-tight mt-2">
            Premios Exclusivos de la Tribu
          </h2>
        </div>

        <NuxtLink :to="{ name: 'registro' }">
          <BaseButton variant="primary" size="md">
            {{ products.length > 0 ? `Ver Todos los Premios (${products.length}+)` : 'Explorar la Tribu' }}
          </BaseButton>
        </NuxtLink>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <Skeleton v-for="i in 3" :key="i" class="h-64 rounded-guaiqui-xl bg-guaiqui-surface" />
      </div>

      <!-- Empty State: Zero products in database -->
      <div
        v-else-if="products.length === 0"
        class="text-center py-16 px-6 bg-guaiqui-surface rounded-guaiqui-xl border border-guaiqui-border shadow-guaiqui-sm max-w-2xl mx-auto space-y-4"
      >
        <div class="w-16 h-16 rounded-full bg-guaiqui-primary-soft text-guaiqui-primary flex items-center justify-center text-3xl mx-auto">
          <i class="bi bi-gift"></i>
        </div>
        <h3 class="font-display font-bold text-2xl text-guaiqui-text uppercase">
          Catálogo en Preparación
        </h3>
        <p class="text-sm text-guaiqui-text-muted leading-relaxed">
          Los artículos oficiales, indumentaria y experiencias exclusivas para canje con puntos serán anunciados próximamente por la directiva del club. ¡Acumula puntos jugando trivias desde ahora!
        </p>
        <div class="pt-2">
          <NuxtLink :to="{ name: 'registro' }">
            <BaseButton variant="primary" size="sm">
              Registrarme para Acumular Puntos
            </BaseButton>
          </NuxtLink>
        </div>
      </div>

      <!-- Real Products Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="item in products"
          :key="item.id"
          variant="interactive"
          padding="md"
          :spotlight="true"
          class="reward-card flex flex-col justify-between"
          @click="handleRewardClick(item.title)"
        >
          <template #image>
            <div class="w-full h-44 bg-gradient-to-br from-emerald-800 to-guaiqui-primary-dark flex items-center justify-center p-4 relative overflow-hidden">
              <img
                v-if="item.image_url"
                :src="item.image_url"
                :alt="item.title"
                class="w-full h-full object-cover"
              />
              <div v-else class="w-16 h-16 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center text-white text-3xl font-bold border border-white/30 shadow-md">
                <i class="bi bi-gift-fill"></i>
              </div>

              <BaseBadge v-if="item.category" variant="perlita" size="sm" class="absolute top-3 left-3 shadow-xs">
                {{ item.category }}
              </BaseBadge>
            </div>
          </template>

          <div class="space-y-3 pt-2 flex-1 flex flex-col justify-between">
            <div>
              <h3 class="font-display font-bold text-lg text-guaiqui-text uppercase leading-snug">
                {{ item.title }}
              </h3>
              <p class="text-xs text-guaiqui-text-muted mt-1">
                Disponibles: <strong class="text-guaiqui-text">{{ item.stock }} unidades</strong>
              </p>
            </div>

            <div class="flex items-center justify-between pt-3 border-t border-guaiqui-border">
              <PearlAmount :amount="item.points_cost || item.price_points || 0" size="lg" show-label />
              <BaseButton variant="ghost" size="sm">
                Canjear
              </BaseButton>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </section>
</template>
