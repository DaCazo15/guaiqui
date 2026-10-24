<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseInput, BaseBadge, BaseModal, EmptyState } from '@guaiqui/ui'
import { supabase } from '../../lib/supabase'
import type { HeroCarouselSlide } from '@guaiqui/shared'

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
const uploadingImage = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const errorMessage = ref<string | null>(null)
const MAX_FILE_SIZE_MB = 20

const form = ref({
  id: '',
  title: '',
  tag: 'Fan Zone',
  tag_variant: 'primary' as 'primary' | 'gold' | 'accent',
  subtitle: '',
  image_url: '',
  image_layout: 'background' as 'background' | 'right',
  text_align: 'left' as 'left' | 'center',
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

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  if (file.size > MAX_FILE_SIZE_MB * 1024 * 1024) {
    alert(`La imagen seleccionada supera el límite permitido de ${MAX_FILE_SIZE_MB}MB (${(file.size / (1024 * 1024)).toFixed(1)}MB). Por favor elige una imagen más ligera o comprimida.`)
    if (fileInput.value) fileInput.value.value = ''
    return
  }

  uploadingImage.value = true
  try {
    const ext = file.name.split('.').pop()
    const fileName = `hero-post-${Date.now()}-${Math.random().toString(36).substring(2, 7)}.${ext}`
    const path = `hero-carousel/${fileName}`

    const { error: uploadErr } = await supabase.storage.from('site-media').upload(path, file, {
      cacheControl: '3600',
      upsert: true
    })
    if (uploadErr) throw uploadErr

    const { data } = supabase.storage.from('site-media').getPublicUrl(path)
    form.value.image_url = data.publicUrl
  } catch (err: any) {
    console.error('Error al subir imagen de post:', err)
    alert('Error al subir imagen: ' + (err.message || 'Error de conexión HTTP2'))
  } finally {
    uploadingImage.value = false
    if (fileInput.value) fileInput.value.value = ''
  }
}

const saveSlide = async () => {
  if (!form.value.title.trim()) {
    errorMessage.value = 'El título del post es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      title: form.value.title,
      tag: form.value.tag || null,
      tag_variant: form.value.tag_variant || 'primary',
      subtitle: form.value.subtitle || null,
      image_url: form.value.image_url || null,
      image_layout: form.value.image_layout || 'background',
      text_align: form.value.text_align || 'left',
      cta_text: form.value.cta_text || null,
      cta_url: form.value.cta_url || null,
      cta_secondary_text: form.value.cta_secondary_text || null,
      cta_secondary_url: form.value.cta_secondary_url || null,
      highlight_title: form.value.highlight_title || null,
      highlight_subtitle: form.value.highlight_subtitle || null,
      highlight_badge: form.value.highlight_badge || null,
      show_guarantees: form.value.show_guarantees,
      guarantee_1: form.value.guarantee_1 || null,
      guarantee_2: form.value.guarantee_2 || null,
      guarantee_3: form.value.guarantee_3 || null,
      order_index: form.value.order_index,
      is_published: form.value.is_published,
      updated_at: new Date().toISOString()
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
    errorMessage.value = err.message || 'Error al guardar el post del carrusel.'
  } finally {
    actionLoading.value = false
  }
}

const deleteSlide = async (id: string) => {
  if (!confirm('¿Deseas eliminar este post del carrusel del Hero?')) return
  try {
    const { error } = await supabase
      .from('hero_carousel_slides')
      .delete()
      .eq('id', id)
    if (error) throw error
    await loadSlides()
  } catch (err: any) {
    alert('Error al eliminar: ' + (err.message || 'Desconocido'))
  }
}

onMounted(loadSlides)
</script>

<template>
  <div class="space-y-6">
    <!-- Toggle Master Switch -->
    <div class="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
            <i class="bi bi-view-list text-emerald-400 text-lg"></i>
            Carrusel Interactivo en el Hero
          </span>
          <span
            :class="[
              'text-[10px] font-bold uppercase px-2 py-0.5 rounded-full border',
              carouselEnabled
                ? 'bg-emerald-950/80 border-emerald-500/50 text-emerald-300'
                : 'bg-slate-800 border-slate-700 text-slate-400'
            ]"
          >
            {{ carouselEnabled ? 'Activado' : 'Desactivado' }}
          </span>
        </div>
        <p class="text-xs text-slate-400">
          Convierte toda la sección Hero de la portada en un carrusel dinámico a pantalla completa (hasta 5 diapositivas con imagen de fondo, título, descripción y botón de acción). Si se desactiva, se muestra el Hero institucional clásico.
        </p>
      </div>

      <label class="relative inline-flex items-center cursor-pointer shrink-0">
        <input
          type="checkbox"
          :checked="carouselEnabled"
          @change="
            emit('update:carouselEnabled', ($event.target as HTMLInputElement).checked);
            emit('toggleCarousel');
          "
          class="sr-only peer"
        />
        <div class="w-12 h-6 bg-slate-800 peer-focus:outline-hidden rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
      </label>
    </div>

    <!-- Posts Section (visible if activated) -->
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-bold text-slate-200">Posts del Carrusel del Hero</h4>
          <p class="text-xs text-slate-400">
            {{ slides.length }} de 5 posts creados
          </p>
        </div>

        <BaseButton
          variant="primary"
          size="sm"
          :disabled="slides.length >= 5"
          @click="openNew"
        >
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Post ({{ 5 - slides.length }} disponibles)
        </BaseButton>
      </div>

      <!-- Empty State -->
      <EmptyState
        v-if="!loading && slides.length === 0"
        title="No hay posts en el carrusel del Hero"
        description="Agrega hasta 5 posts con imagen, título y botón de acción para destacar en la portada."
        icon="bi-images"
      />

      <!-- List of Posts -->
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
            <BaseButton variant="secondary" size="sm" @click="openEdit(slide)">
              <i class="bi bi-pencil mr-1"></i> Editar
            </BaseButton>
            <button
              type="button"
              title="Eliminar Post"
              class="w-8 h-8 rounded-lg flex items-center justify-center text-slate-400 hover:text-red-400 hover:bg-red-950/40 border border-slate-800 transition-colors"
              @click="deleteSlide(slide.id)"
            >
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal to Add / Edit Post -->
    <BaseModal
      v-if="showEditorModal"
      :is-open="showEditorModal"
      :title="form.id ? 'Editar Diapositiva del Carrusel' : 'Nueva Diapositiva para el Hero'"
      size="lg"
      @close="showEditorModal = false"
    >
      <div class="space-y-5 max-h-[75vh] overflow-y-auto pr-1">
        <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-200 text-xs rounded-lg flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
          <span>{{ errorMessage }}</span>
        </div>

        <!-- Section 1: Badge, Variant & Order -->
        <div class="grid grid-cols-1 sm:grid-cols-12 gap-3">
          <div class="sm:col-span-6">
            <BaseInput
              label="Etiqueta / Badge"
              v-model="form.tag"
              placeholder="Ej: Próximo Partido, Fan Zone, Concurso"
            />
          </div>

          <div class="sm:col-span-4 flex flex-col gap-1.5">
            <label class="text-xs font-semibold text-slate-300">Estilo de Etiqueta</label>
            <select
              v-model="form.tag_variant"
              class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
            >
              <option value="primary">Verde Tribu (Oficial)</option>
              <option value="gold">Dorado Campeón (Premios / Estrellas)</option>
              <option value="accent">Rojo Bandana (En Vivo / Urgente)</option>
            </select>
          </div>

          <div class="sm:col-span-2">
            <BaseInput
              label="Orden (1-5)"
              type="number"
              min="1"
              max="5"
              v-model.number="form.order_index"
            />
          </div>
        </div>

        <!-- Section 2: Headline & Subtitle -->
        <BaseInput
          label="Título Principal de la Diapositiva"
          v-model="form.title"
          placeholder="Ej: ¡Gran Final Oriental en el Gimnasio!"
          required
        />

        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-slate-300">Descripción / Subtítulo</label>
          <textarea
            v-model="form.subtitle"
            rows="2"
            placeholder="Ej: Acompáñanos este sábado y gana perlitas exclusivas respondiendo trivias..."
            class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
          ></textarea>
        </div>

        <!-- Section 3: Image & Layout Mode -->
        <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-white flex items-center gap-1.5">
              <i class="bi bi-image text-emerald-400"></i> Imagen y Presentación
            </label>
          </div>

          <!-- Layout selector: Full background vs Right image -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <label
              :class="[
                'p-3 rounded-xl border cursor-pointer flex items-center gap-3 transition-all',
                form.image_layout === 'background'
                  ? 'bg-emerald-950/40 border-emerald-500 text-white'
                  : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700'
              ]"
            >
              <input type="radio" value="background" v-model="form.image_layout" class="sr-only" />
              <i class="bi bi-aspect-ratio text-xl text-emerald-400"></i>
              <div>
                <div class="text-xs font-bold">Fondo Inmersivo</div>
                <div class="text-[11px] text-slate-400">Cubre todo el Hero con overlay oscuro</div>
              </div>
            </label>

            <label
              :class="[
                'p-3 rounded-xl border cursor-pointer flex items-center gap-3 transition-all',
                form.image_layout === 'right'
                  ? 'bg-emerald-950/40 border-emerald-500 text-white'
                  : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700'
              ]"
            >
              <input type="radio" value="right" v-model="form.image_layout" class="sr-only" />
              <i class="bi bi-person-workspace text-xl text-emerald-400"></i>
              <div>
                <div class="text-xs font-bold">Foto a la Derecha</div>
                <div class="text-[11px] text-slate-400">Texto a la izquierda e imagen destacada</div>
              </div>
            </label>
          </div>

          <!-- File upload -->
          <div class="flex items-center gap-3 pt-2">
            <div class="w-16 h-16 rounded-lg bg-slate-950 border border-slate-800 overflow-hidden shrink-0 flex items-center justify-center">
              <img v-if="form.image_url" :src="form.image_url" alt="Preview" class="w-full h-full object-cover" />
              <i v-else class="bi bi-image text-slate-600 text-2xl"></i>
            </div>

            <div class="flex-1 space-y-2">
              <input
                ref="fileInput"
                type="file"
                accept="image/*"
                class="hidden"
                @change="handleFileUpload"
              />
              <div class="flex items-center gap-2 flex-wrap">
                <BaseButton
                  type="button"
                  variant="secondary"
                  size="sm"
                  :loading="uploadingImage"
                  @click="triggerFileInput"
                >
                  <i class="bi bi-cloud-arrow-up mr-1.5"></i> Subir Imagen
                </BaseButton>

                <button
                  v-if="form.image_url"
                  type="button"
                  @click="form.image_url = ''"
                  class="text-xs text-red-400 hover:text-red-300 inline-flex items-center gap-1"
                >
                  <i class="bi bi-trash"></i> Quitar
                </button>
              </div>
              <input
                type="text"
                v-model="form.image_url"
                placeholder="O pega la URL de la imagen aquí..."
                class="w-full rounded-lg bg-slate-950 border border-slate-800 text-slate-300 px-2.5 py-1 text-xs focus:border-guaiqui-primary focus:outline-hidden"
              />
            </div>
          </div>
        </div>

        <!-- Section 4: Dual CTA Buttons -->
        <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
          <label class="text-xs font-bold text-white flex items-center gap-1.5">
            <i class="bi bi-cursor-fill text-emerald-400"></i> Botones de Acción (CTAs)
          </label>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <BaseInput
              label="Botón Principal (Texto)"
              v-model="form.cta_text"
              placeholder="Ej: Únete a la Tribu, Ver Más"
            />
            <BaseInput
              label="Enlace Botón Principal"
              v-model="form.cta_url"
              placeholder="Ej: /registro o /trivias"
            />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-slate-800">
            <BaseInput
              label="Botón Secundario (Opcional)"
              v-model="form.cta_secondary_text"
              placeholder="Ej: Ver Premios, Ver Cómo Funciona"
            />
            <BaseInput
              label="Enlace Botón Secundario"
              v-model="form.cta_secondary_url"
              placeholder="Ej: /tienda o #como-funciona"
            />
          </div>
        </div>

        <!-- Section 5: Floating Highlight Card (Optional) -->
        <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-white flex items-center gap-1.5">
              <i class="bi bi-card-heading text-emerald-400"></i> Micro-Tarjeta Flotante Destacada (Opcional)
            </label>
            <span class="text-[11px] text-slate-400">Aparece flotando para dar volumen y dinamismo</span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-12 gap-3">
            <div class="sm:col-span-4">
              <BaseInput
                label="Insignia / Badge"
                v-model="form.highlight_badge"
                placeholder="Ej: En Vivo, Premio, Fan"
              />
            </div>
            <div class="sm:col-span-8">
              <BaseInput
                label="Título de la Tarjeta"
                v-model="form.highlight_title"
                placeholder="Ej: Camiseta Oficial 2026 o Trotamundos vs Guaiqueríes"
              />
            </div>
          </div>

          <BaseInput
            label="Detalle / Subtítulo de la Tarjeta"
            v-model="form.highlight_subtitle"
            placeholder="Ej: Canjeable por 2,500 perlitas | Edición Limitada"
          />
        </div>

        <!-- Section 6: Trust Guarantees / Sellos de Confianza por Diapositiva -->
        <div class="space-y-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-white flex items-center gap-1.5">
              <i class="bi bi-shield-check text-emerald-400"></i> Sellos de Confianza / Beneficios (Pie del Slide)
            </label>
            <label class="flex items-center gap-2 cursor-pointer text-xs text-slate-300">
              <input
                type="checkbox"
                v-model="form.show_guarantees"
                class="w-4 h-4 accent-emerald-500 rounded"
              />
              <span>Mostrar en este slide</span>
            </label>
          </div>

          <div v-if="form.show_guarantees" class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <BaseInput
              label="Sello 1"
              v-model="form.guarantee_1"
              placeholder="Ej: 100% Gratuito o Gimnasio La Asunción"
            />
            <BaseInput
              label="Sello 2"
              v-model="form.guarantee_2"
              placeholder="Ej: Sin tarjetas o En Vivo por TV"
            />
            <BaseInput
              label="Sello 3"
              v-model="form.guarantee_3"
              placeholder="Ej: Recompensas Reales o +300 Perlitas"
            />
          </div>
        </div>

        <!-- Section 7: Opciones de Alineación y Publicación -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 p-4 bg-slate-900/80 border border-slate-700/80 rounded-xl items-center">
          <!-- Text alignment -->
          <div>
            <label class="text-xs font-semibold text-slate-300 block mb-1.5">Alineación del Texto</label>
            <div class="flex items-center gap-3">
              <label class="flex items-center gap-1.5 text-xs text-white cursor-pointer">
                <input type="radio" value="left" v-model="form.text_align" class="accent-emerald-500" />
                <span>Alineado a la Izquierda</span>
              </label>
              <label class="flex items-center gap-1.5 text-xs text-white cursor-pointer">
                <input type="radio" value="center" v-model="form.text_align" class="accent-emerald-500" />
                <span>Centrado</span>
              </label>
            </div>
          </div>

          <!-- Publication status -->
          <div class="sm:text-right">
            <label class="text-xs font-semibold text-slate-300 block mb-1.5">Estado de la Diapositiva</label>
            <label class="inline-flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                v-model="form.is_published"
                class="w-4 h-4 accent-emerald-500 rounded"
              />
              <span class="text-xs font-bold" :class="form.is_published ? 'text-emerald-400' : 'text-slate-500'">
                {{ form.is_published ? 'Publicada (Visible en Portada)' : 'Borrador (Oculta)' }}
              </span>
            </label>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveSlide">
            {{ form.id ? 'Guardar Cambios' : 'Crear Post' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
