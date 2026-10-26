<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import { useAnalytics } from '~/composables/useAnalytics'
import type { LandingCta, CtaPlacement } from '@guaiqui/shared'

const props = withDefaults(defineProps<{
  placement?: CtaPlacement
}>(), {
  placement: 'before_footer'
})

const { trackEvent } = useAnalytics()
const supabase = useSupabaseClient()

const containerRef = ref<HTMLElement | null>(null)

const { data: activeCta } = await useAsyncData(
  `landing-cta-${props.placement}`,
  async () => {
    try {
      const { data } = await (supabase as any)
        .from('landing_ctas')
        .select('*')
        .eq('is_published', true)
        .eq('is_active', true)
        .eq('placement', props.placement)
        .limit(1)
        .maybeSingle()
      return (data as LandingCta) ?? null
    } catch (_e) {
      return null
    }
  },
  {
    default: () => null,
  }
)

// Fallback logic: only before_footer provides default container if none active; after_hero returns null if inactive
const cta = computed(() => {
  if (activeCta.value) return activeCta.value

  if (props.placement === 'before_footer') {
    return {
      id: 'default',
      name: 'Llamado Oficial de Registro',
      type: 'container' as const,
      placement: 'before_footer' as const,
      is_active: true,
      is_published: true,
      badge_text: '¡Únete a la Tribu Hoy!',
      heading: '¿Listo para ganar tu primer premio?',
      subtitle: 'El registro toma menos de 1 minuto y recibirás un bono de bienvenida de +100 puntos para comenzar.',
      button_text: 'Crear mi Cuenta Gratis',
      button_url: '/registro',
      bg_gradient: 'from-guaiqui-primary-dark via-emerald-900 to-slate-950',
      bg_color: null,
      phrase_text: null,
      font_family: null,
      font_size: null,
      letter_spacing: null,
      font_weight: null,
      text_color: null,
      media_type: null,
      media_value: null,
      created_at: '',
      updated_at: ''
    }
  }

  return null
})

const isLightBg = computed(() => {
  if (!cta.value?.bg_color) return false
  const hex = cta.value.bg_color.replace('#', '').toLowerCase()
  if (hex === 'ffffff' || hex === 'fff' || hex === 'f8fafc' || hex === 'f1f5f9') return true
  if (hex.length === 6) {
    const r = parseInt(hex.substring(0, 2), 16)
    const g = parseInt(hex.substring(2, 4), 16)
    const b = parseInt(hex.substring(4, 6), 16)
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return luminance > 0.65
  }
  return false
})

const sectionStyle = computed(() => {
  const styles: Record<string, string> = {}
  if (cta.value?.bg_color) {
    styles.backgroundColor = cta.value.bg_color
    styles.backgroundImage = 'none'
  }
  return styles
})

const phraseStyle = computed(() => {
  if (cta.value?.type !== 'phrase') return {}
  const family = cta.value.font_family || 'Barlow Condensed'
  return {
    fontFamily: `'${family}', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`
  }
})

const handleCtaClick = () => {
  trackEvent('click_register', { source: `cta_${props.placement}`, cta_id: cta.value?.id })
}

import { useGSAP } from '~/composables/useGSAP'

const { gsap, ScrollTrigger } = useGSAP()
let ctx: gsap.Context | null = null

const initAnimation = () => {
  if (!containerRef.value) return
  ctx?.revert()
  ctx = gsap.context(() => {
    const mm = gsap.matchMedia()
    mm.add('(prefers-reduced-motion: no-preference)', () => {
      gsap.from('.cta-anim-child', {
        opacity: 0,
        y: 22,
        duration: 0.7,
        stagger: 0.12,
        ease: 'power2.out',
        scrollTrigger: {
          trigger: containerRef.value,
          start: 'top 85%',
          toggleActions: 'play none none none'
        }
      })
    })
  }, containerRef.value)
  ScrollTrigger?.refresh()
}

onMounted(async () => {
  await nextTick()
  initAnimation()
})

watch(() => cta.value, async () => {
  await nextTick()
  initAnimation()
})

onUnmounted(() => {
  ctx?.revert()
})
</script>

<template>
  <section
    v-if="cta"
    ref="containerRef"
    class="py-14 sm:py-20 px-4 sm:px-8 text-center relative overflow-hidden transition-colors duration-300"
    :class="[
      !cta.bg_color ? (cta.bg_gradient || 'from-guaiqui-primary-dark via-emerald-900 to-slate-950') + ' bg-gradient-to-r' : '',
      isLightBg ? 'text-slate-900' : 'text-white'
    ]"
    :style="sectionStyle"
  >
    <!-- Background glow decoration (only on dark backgrounds) -->
    <div
      v-if="!isLightBg"
      class="absolute -top-24 left-1/2 -translate-x-1/2 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none"
    ></div>

    <!-- Mode 1: Container layout -->
    <div v-if="cta.type === 'container'" class="max-w-4xl mx-auto space-y-6 relative z-10">
      <div
        v-if="cta.badge_text"
        class="cta-anim-child inline-flex items-center gap-2 text-xs font-bold uppercase px-3.5 py-1.5 rounded-full border shadow-xs"
        :class="isLightBg ? 'bg-emerald-100 text-emerald-900 border-emerald-300' : 'bg-amber-400/20 text-amber-300 border-amber-400/30'"
      >
        <PearlIcon size="xs" /> {{ cta.badge_text }}
      </div>

      <h2
        class="cta-anim-child font-display font-extrabold text-3xl sm:text-5xl uppercase tracking-tight leading-none drop-shadow-sm"
        :class="isLightBg ? 'text-slate-900' : 'text-white'"
      >
        {{ cta.heading }}
      </h2>

      <p
        class="cta-anim-child text-base sm:text-lg max-w-xl mx-auto leading-relaxed"
        :class="isLightBg ? 'text-slate-600' : 'text-emerald-100'"
      >
        {{ cta.subtitle }}
      </p>

      <div class="cta-anim-child pt-2">
        <NuxtLink :to="cta.button_url || '/registro'">
          <BaseButton variant="primary" size="lg" @click="handleCtaClick">
            {{ cta.button_text || 'Crear mi Cuenta Gratis' }}
          </BaseButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Mode 2: Phrase layout -->
    <div v-else class="max-w-5xl mx-auto flex flex-col items-center justify-center space-y-4 relative z-10">
      <!-- Media: Logo -->
      <div v-if="cta.media_type === 'logo'" class="cta-anim-child mb-2">
        <img
          src="/logo.png"
          alt="Guaiqueríes de Margarita"
          class="h-16 w-16 sm:h-24 sm:w-24 object-contain drop-shadow-xl"
        />
      </div>

      <!-- Media: Icon -->
      <div
        v-else-if="cta.media_type === 'icon' && cta.media_value"
        class="cta-anim-child mb-2 inline-flex items-center justify-center w-16 h-16 sm:w-20 sm:h-20 rounded-2xl border text-3xl sm:text-4xl shadow-inner"
        :class="isLightBg ? 'bg-slate-100 border-slate-300 text-emerald-800' : 'bg-white/10 backdrop-blur-xs border-white/20 text-amber-300'"
      >
        <i :class="['bi', cta.media_value]"></i>
      </div>

      <!-- Media: Image -->
      <div
        v-else-if="cta.media_type === 'image' && cta.media_value"
        class="cta-anim-child mb-2 max-w-xs sm:max-w-md rounded-2xl overflow-hidden border shadow-2xl"
        :class="isLightBg ? 'border-slate-300' : 'border-white/20'"
      >
        <img
          :src="cta.media_value"
          alt="Media Guaiqueríes"
          class="w-full max-h-48 object-cover"
        />
      </div>

      <!-- Phrase text -->
      <p
        class="cta-anim-child leading-tight drop-shadow-md transition-all duration-300"
        :class="[
          cta.font_size || 'text-4xl sm:text-6xl',
          cta.letter_spacing || 'tracking-tight',
          cta.font_weight || 'font-extrabold',
          isLightBg ? 'text-slate-900' : (cta.text_color || 'text-white')
        ]"
        :style="phraseStyle"
      >
        {{ cta.phrase_text }}
      </p>
    </div>
  </section>
</template>
