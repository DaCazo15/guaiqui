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
  subtitle: '',
  image_url: '',
  cta_text: 'Ver Más',
  cta_url: '/registro',
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
    subtitle: '',
    image_url: '',
    cta_text: 'Ver Más',
    cta_url: '/registro',
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
    subtitle: slide.subtitle || '',
    image_url: slide.image_url || '',
    cta_text: slide.cta_text || 'Ver Más',
    cta_url: slide.cta_url || '/registro',
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
      subtitle: form.value.subtitle || null,
      image_url: form.value.image_url || null,
      cta_text: form.value.cta_text || null,
      cta_url: form.value.cta_url || null,
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
              <div class="flex items-center gap-2">
                <span class="font-bold text-xs font-mono text-emerald-400">#{{ slide.order_index }}</span>
                <span v-if="slide.tag" class="text-[10px] font-semibold uppercase px-2 py-0.5 rounded bg-amber-400/10 text-amber-300 border border-amber-400/20">
                  {{ slide.tag }}
                </span>
                <span class="text-sm font-bold text-white truncate">{{ slide.title }}</span>
              </div>
              <p class="text-xs text-slate-400 truncate max-w-md">{{ slide.subtitle || 'Sin descripción' }}</p>
              <div class="text-[11px] text-slate-500 flex items-center gap-2">
                <span>Botón: <strong class="text-slate-400">{{ slide.cta_text || 'Ver Más' }}</strong></span>
                <span>•</span>
                <span class="truncate">{{ slide.cta_url || '/registro' }}</span>
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
      :title="form.id ? 'Editar Post del Carrusel' : 'Nuevo Post para el Hero'"
      size="lg"
      @close="showEditorModal = false"
    >
      <div class="space-y-4">
        <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-200 text-xs rounded-lg flex items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill text-red-400"></i>
          <span>{{ errorMessage }}</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BaseInput
            label="Etiqueta / Badge"
            v-model="form.tag"
            placeholder="Ej: Próximo Partido, Concurso"
            class="sm:col-span-2"
          />
          <BaseInput
            label="Orden (1 al 5)"
            type="number"
            min="1"
            max="5"
            v-model.number="form.order_index"
          />
        </div>

        <BaseInput
          label="Título del Post"
          v-model="form.title"
          placeholder="Ej: ¡Gran Final Oriental en el Gimnasio!"
          required
        />

        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-slate-300">Descripción Breve</label>
          <textarea
            v-model="form.subtitle"
            rows="2"
            placeholder="Ej: Acompáñanos este sábado y participa por premios exclusivos..."
            class="w-full rounded-lg bg-slate-900 border border-slate-700 text-white px-3 py-2 text-sm focus:border-guaiqui-primary focus:outline-hidden"
          ></textarea>
        </div>

        <!-- Image Upload -->
        <div class="space-y-2 p-3 bg-slate-900/80 border border-slate-700/80 rounded-xl">
          <label class="text-xs font-semibold text-slate-300 block">Imagen del Post</label>
          <div class="flex items-center gap-3">
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

        <!-- CTA Button -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <BaseInput
            label="Texto del Botón (CTA)"
            v-model="form.cta_text"
            placeholder="Ej: Ver Más, Comprar Entradas"
          />
          <BaseInput
            label="Enlace del Botón"
            v-model="form.cta_url"
            placeholder="Ej: /registro o #premios"
          />
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
