<script setup lang="ts">
import { BaseButton, EmptyState } from '@guaiqui/ui'
import type { HeroCarouselSlide } from '@guaiqui/shared'

defineProps<{
  slides: HeroCarouselSlide[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'edit', slide: HeroCarouselSlide): void
  (e: 'delete', id: string): void
}>()
</script>

<template>
  <div v-if="loading" class="text-center py-12 text-slate-400">
    <i class="bi bi-arrow-repeat animate-spin text-2xl inline-block mb-2"></i>
    <p class="text-xs">Cargando diapositivas del carrusel...</p>
  </div>

  <EmptyState
    v-else-if="slides.length === 0"
    title="No hay posts en el carrusel"
    description="Agrega hasta 5 posts con imagen, título y botón de acción para destacar en la portada."
    icon="bi-images"
  />

  <div v-else class="grid grid-cols-1 gap-3">
    <div
      v-for="slide in slides"
      :key="slide.id"
      class="p-4 rounded-xl bg-slate-900/60 border border-slate-800 hover:border-slate-700 flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition-all"
    >
      <!-- Info Column -->
      <div class="flex items-center gap-3.5 min-w-0">
        <!-- Thumbnail preview -->
        <div class="w-14 h-14 rounded-lg bg-slate-950 border border-slate-800 overflow-hidden shrink-0 flex items-center justify-center">
          <img
            v-if="slide.image_url"
            :src="slide.image_url"
            :alt="slide.title"
            class="w-full h-full object-cover"
          />
          <i v-else class="bi bi-image text-slate-600 text-xl"></i>
        </div>

        <div class="min-w-0 space-y-0.5">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-bold text-xs font-mono text-emerald-400">#{{ slide.order_index }}</span>
            <span
              v-if="slide.tag"
              :class="[
                'text-[10px] font-semibold uppercase px-2 py-0.5 rounded border',
                slide.tag_variant === 'gold' ? 'bg-amber-400/10 text-amber-300 border-amber-400/30' :
                slide.tag_variant === 'accent' ? 'bg-red-400/10 text-red-300 border-red-400/30' :
                'bg-emerald-400/10 text-emerald-300 border-emerald-400/30'
              ]"
            >
              {{ slide.tag }}
            </span>
            <span
              class="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-800 text-slate-400"
            >
              {{ slide.image_layout === 'right' ? 'Foto Derecha' : 'Fondo Completo' }}
            </span>
            <span
              :class="[
                'text-[10px] font-semibold px-1.5 py-0.5 rounded',
                slide.is_published ? 'bg-emerald-950 text-emerald-400 border border-emerald-500/30' : 'bg-slate-800 text-slate-500'
              ]"
            >
              {{ slide.is_published ? 'Publicado' : 'Borrador' }}
            </span>
            <span class="text-sm font-bold text-white truncate">{{ slide.title }}</span>
          </div>
          <p class="text-xs text-slate-400 truncate max-w-md">{{ slide.subtitle || 'Sin descripción' }}</p>
          <div class="text-[11px] text-slate-500 flex items-center gap-2 flex-wrap">
            <span>CTA: <strong class="text-slate-300">{{ slide.cta_text || 'Ver Más' }}</strong></span>
            <span v-if="slide.cta_secondary_text">• 2do: <strong class="text-slate-300">{{ slide.cta_secondary_text }}</strong></span>
            <span v-if="slide.highlight_title">• Tarjeta: <strong class="text-emerald-400">{{ slide.highlight_title }}</strong></span>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex items-center gap-2 shrink-0 self-end sm:self-center">
        <BaseButton variant="secondary" size="sm" @click="emit('edit', slide)">
          <i class="bi bi-pencil mr-1"></i> Editar
        </BaseButton>
        <button
          type="button"
          title="Eliminar Post"
          class="w-8 h-8 rounded-lg flex items-center justify-center text-slate-400 hover:text-red-400 hover:bg-red-950/40 border border-slate-800 transition-colors"
          @click="emit('delete', slide.id)"
        >
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>
  </div>
</template>
