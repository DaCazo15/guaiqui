<script setup lang="ts">
import { computed } from 'vue'
import { BaseButton, PearlIcon } from '@guaiqui/ui'
import type { CtaFormData } from './ctaTypes'

const props = defineProps<{
  cta: CtaFormData
  compact?: boolean
}>()

const fontFamilyStyle = computed(() => {
  if (props.cta.type !== 'phrase') return {}
  const family = props.cta.font_family || 'Barlow Condensed'
  return {
    fontFamily: `'${family}', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`
  }
})
</script>

<template>
  <div class="w-full rounded-2xl overflow-hidden border border-slate-700/80 shadow-2xl relative">
    <!-- Live Preview Header Tag -->
    <div class="bg-slate-900/90 backdrop-blur-xs px-4 py-2 border-b border-slate-700/60 flex items-center justify-between text-xs text-slate-400">
      <span class="inline-flex items-center gap-1.5 font-medium text-emerald-400">
        <i class="bi bi-eye-fill"></i> Previsualización en Vivo
      </span>
      <span class="uppercase tracking-wider font-semibold text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-300">
        {{ cta.type === 'container' ? 'Contenedor Completo' : 'Solo Frase' }}
      </span>
    </div>

    <!-- Mode 1: Container Preview -->
    <div
      v-if="cta.type === 'container'"
      class="py-12 sm:py-16 px-4 sm:px-8 text-center text-white relative overflow-hidden bg-gradient-to-r"
      :class="cta.bg_gradient || 'from-guaiqui-primary-dark via-emerald-900 to-slate-950'"
    >
      <div class="max-w-3xl mx-auto space-y-5 relative z-10">
        <!-- Badge -->
        <div
          v-if="cta.badge_text"
          class="inline-flex items-center gap-2 bg-amber-400/20 text-amber-300 text-xs font-bold uppercase px-3 py-1 rounded-full border border-amber-400/30 shadow-xs"
        >
          <PearlIcon size="xs" /> {{ cta.badge_text }}
        </div>

        <!-- Heading -->
        <h2 class="font-display font-extrabold text-2xl sm:text-4xl lg:text-5xl uppercase tracking-tight leading-none drop-shadow-sm">
          {{ cta.heading || 'Título del Llamado a la Acción' }}
        </h2>

        <!-- Subtitle -->
        <p class="text-emerald-100 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
          {{ cta.subtitle || 'Subtítulo o descripción atractiva para los fanáticos.' }}
        </p>

        <!-- Button -->
        <div class="pt-2">
          <BaseButton variant="primary" size="lg" class="shadow-lg shadow-emerald-950/50">
            {{ cta.button_text || 'Crear mi Cuenta Gratis' }}
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Mode 2: Phrase Preview -->
    <div
      v-else
      class="py-12 sm:py-16 px-4 sm:px-8 text-center relative overflow-hidden bg-gradient-to-r from-guaiqui-primary-dark via-emerald-900 to-slate-950 text-white"
    >
      <div class="max-w-4xl mx-auto flex flex-col items-center justify-center space-y-4 relative z-10">
        <!-- Media: Logo -->
        <div v-if="cta.media_type === 'logo'" class="mb-2">
          <img
            src="/logo.png"
            alt="Logo Guaiqueríes de Margarita"
            class="h-16 w-16 sm:h-20 sm:w-20 object-contain drop-shadow-lg"
          />
        </div>

        <!-- Media: Icon -->
        <div
          v-else-if="cta.media_type === 'icon' && cta.media_value"
          class="mb-2 inline-flex items-center justify-center w-14 h-14 sm:w-16 sm:h-16 rounded-2xl bg-white/10 backdrop-blur-xs border border-white/20 text-amber-300 text-3xl sm:text-4xl shadow-inner"
        >
          <i :class="['bi', cta.media_value]"></i>
        </div>

        <!-- Media: Image -->
        <div
          v-else-if="cta.media_type === 'image' && cta.media_value"
          class="mb-2 max-w-xs rounded-xl overflow-hidden border border-white/20 shadow-xl"
        >
          <img
            :src="cta.media_value"
            alt="Media CTA"
            class="w-full max-h-36 object-cover"
          />
        </div>

        <!-- Phrase Text with selected typography -->
        <p
          class="leading-tight transition-all duration-200"
          :class="[
            cta.font_size || 'text-4xl sm:text-6xl',
            cta.letter_spacing || 'tracking-tight',
            cta.font_weight || 'font-extrabold',
            cta.text_color || 'text-white'
          ]"
          :style="fontFamilyStyle"
        >
          {{ cta.phrase_text || '¡ESCRIBE AQUÍ TU FRASE O LEMA!' }}
        </p>
      </div>
    </div>
  </div>
</template>
