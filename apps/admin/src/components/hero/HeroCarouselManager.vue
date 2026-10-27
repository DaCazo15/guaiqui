<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { HeroCarouselSlide } from '@guaiqui/shared'
import HeroSlideList from './HeroSlideList.vue'
import HeroSlideModal, { type HeroSlideFormData } from './HeroSlideModal.vue'

const props = defineProps<{
  carouselEnabled: boolean
}>()

const emit = defineEmits<{
  (e: 'update:carouselEnabled', value: boolean): void
  (e: 'toggleCarousel'): void
}>()

const slides = ref<HeroCarouselSlide[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const showEditorModal = ref(false)
const errorMessage = ref<string | null>(null)

const form = ref<HeroSlideFormData>({
  id: '',
  title: '',
  tag: 'Fan Zone',
  tag_variant: 'primary',
  subtitle: '',
  image_url: '',
  image_layout: 'background',
  text_align: 'left',
  cta_text: 'Ver Más',
  cta_url: '/registro',
  cta_secondary_text: '',
  cta_secondary_url: '',
  highlight_title: '',
  highlight_subtitle: '',
  highlight_badge: '',
  show_guarantees: true,
  guarantee_1: '100% Gratuito',
  guarantee_2: 'Sin tarjetas ni pagos',
  guarantee_3: 'Recompensas Reales',
  order_index: 1,
  is_published: true
})

const loadSlides = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('hero_carousel_slides')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    slides.value = (data as HeroCarouselSlide[]) || []
  } catch (err: any) {
    console.error('Error al cargar posts del carrusel del hero:', err)
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  if (slides.value.length >= 5) {
    alert('Has alcanzado el límite máximo de 5 posts en el carrusel del Hero.')
    return
  }
  form.value = {
    id: '',
    title: '',
    tag: 'Fan Zone',
    tag_variant: 'primary',
    subtitle: '',
    image_url: '',
    image_layout: 'background',
    text_align: 'left',
    cta_text: 'Ver Más',
    cta_url: '/registro',
    cta_secondary_text: '',
    cta_secondary_url: '',
    highlight_title: '',
    highlight_subtitle: '',
    highlight_badge: '',
    show_guarantees: true,
    guarantee_1: '100% Gratuito',
    guarantee_2: 'Sin tarjetas ni pagos',
    guarantee_3: 'Recompensas Reales',
    order_index: slides.value.length + 1,
    is_published: true
  }
  errorMessage.value = null
  showEditorModal.value = true
}

const openEdit = (slide: HeroCarouselSlide) => {
  form.value = {
    id: slide.id,
    title: slide.title,
    tag: slide.tag || '',
    tag_variant: (slide.tag_variant as any) || 'primary',
    subtitle: slide.subtitle || '',
    image_url: slide.image_url || '',
    image_layout: (slide.image_layout as any) || 'background',
    text_align: (slide.text_align as any) || 'left',
    cta_text: slide.cta_text || 'Ver Más',
    cta_url: slide.cta_url || '/registro',
    cta_secondary_text: slide.cta_secondary_text || '',
    cta_secondary_url: slide.cta_secondary_url || '',
    highlight_title: slide.highlight_title || '',
    highlight_subtitle: slide.highlight_subtitle || '',
    highlight_badge: slide.highlight_badge || '',
    show_guarantees: slide.show_guarantees !== false,
    guarantee_1: slide.guarantee_1 || '100% Gratuito',
    guarantee_2: slide.guarantee_2 || 'Sin tarjetas ni pagos',
    guarantee_3: slide.guarantee_3 || 'Recompensas Reales',
    order_index: slide.order_index,
    is_published: slide.is_published
  }
  errorMessage.value = null
  showEditorModal.value = true
}

const saveSlide = async () => {
  if (!form.value.title.trim()) {
    errorMessage.value = 'El título principal de la diapositiva es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const payload = {
      title: form.value.title.trim(),
      tag: form.value.tag ? form.value.tag.trim() : null,
      tag_variant: form.value.tag_variant,
      subtitle: form.value.subtitle ? form.value.subtitle.trim() : null,
      image_url: form.value.image_url ? form.value.image_url.trim() : null,
      image_layout: form.value.image_layout,
      text_align: form.value.text_align,
      cta_text: form.value.cta_text ? form.value.cta_text.trim() : 'Ver Más',
      cta_url: form.value.cta_url ? form.value.cta_url.trim() : '/registro',
      cta_secondary_text: form.value.cta_secondary_text ? form.value.cta_secondary_text.trim() : null,
      cta_secondary_url: form.value.cta_secondary_url ? form.value.cta_secondary_url.trim() : null,
      highlight_title: form.value.highlight_title ? form.value.highlight_title.trim() : null,
      highlight_subtitle: form.value.highlight_subtitle ? form.value.highlight_subtitle.trim() : null,
      highlight_badge: form.value.highlight_badge ? form.value.highlight_badge.trim() : null,
      show_guarantees: form.value.show_guarantees,
      guarantee_1: form.value.guarantee_1 ? form.value.guarantee_1.trim() : null,
      guarantee_2: form.value.guarantee_2 ? form.value.guarantee_2.trim() : null,
      guarantee_3: form.value.guarantee_3 ? form.value.guarantee_3.trim() : null,
      order_index: Number(form.value.order_index) || 1,
      is_published: form.value.is_published
    }

    if (form.value.id) {
      const { error } = await supabase
        .from('hero_carousel_slides')
        .update(payload)
        .eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase
        .from('hero_carousel_slides')
        .insert([payload])
      if (error) throw error
    }

    showEditorModal.value = false
    await loadSlides()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar la diapositiva.'
  } finally {
    actionLoading.value = false
  }
}

const deleteSlide = async (id: string) => {
  if (!confirm('¿Estás seguro de que deseas eliminar esta diapositiva del carrusel?')) return

  try {
    const { error } = await supabase
      .from('hero_carousel_slides')
      .delete()
      .eq('id', id)

    if (error) throw error
    await loadSlides()
  } catch (err: any) {
    alert(err.message || 'No se pudo eliminar la diapositiva.')
  }
}

onMounted(() => {
  loadSlides()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header switch & actions -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900/80 border border-slate-800">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <h2 class="text-base font-bold text-white flex items-center gap-2">
            <i class="bi bi-collection-play text-guaiqui-primary"></i>
            Carrusel de Novedades del Hero
          </h2>
          <BaseBadge :variant="carouselEnabled ? 'success' : 'soft'" size="sm">
            {{ carouselEnabled ? 'Activo en Portada' : 'Hero Clásico Fijo' }}
          </BaseBadge>
        </div>
        <p class="text-xs text-slate-400 max-w-xl">
          Convierte la cabecera principal de la landing en un slider de noticias, partidos y promociones. Cuando está apagado, se muestra el Hero clásico de bienvenida.
        </p>
      </div>

      <div class="flex items-center gap-3">
        <BaseButton
          :variant="carouselEnabled ? 'secondary' : 'primary'"
          size="sm"
          @click="emit('toggleCarousel')"
        >
          <i :class="['bi mr-1.5', carouselEnabled ? 'bi-toggle-on text-emerald-400' : 'bi-toggle-off text-slate-400']"></i>
          {{ carouselEnabled ? 'Desactivar Carrusel' : 'Activar Carrusel' }}
        </BaseButton>

        <BaseButton
          variant="primary"
          size="sm"
          :disabled="slides.length >= 5"
          @click="openNew"
        >
          <i class="bi bi-plus-lg mr-1.5"></i>
          Nuevo Post ({{ slides.length }}/5)
        </BaseButton>
      </div>
    </div>

    <!-- Subcomponent: Slide List -->
    <HeroSlideList
      :slides="slides"
      :loading="loading"
      @edit="openEdit"
      @delete="deleteSlide"
    />

    <!-- Subcomponent: Slide Modal -->
    <HeroSlideModal
      :is-open="showEditorModal"
      :form="form"
      :action-loading="actionLoading"
      :error-message="errorMessage"
      @close="showEditorModal = false"
      @save="saveSlide"
    />
  </div>
</template>
