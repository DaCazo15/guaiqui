<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseTable, BaseSelect, BaseCard } from '@guaiqui/ui'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import HeroCarouselManager from '../hero/HeroCarouselManager.vue'

interface SlideRow {
  id: string
  tag?: string
  title: string
  subtitle?: string
  cta_text?: string
  cta_url?: string
  image_url?: string
  bg_gradient?: string
  badge_variant?: string
  order_index: number
  is_published: boolean
  starts_at: string
  ends_at?: string
  created_at: string
}

const activeSubTab = ref<'hero-carousel' | 'featured-carousel'>('hero-carousel')

// State for Hero Carousel
const heroCarouselEnabled = ref(true)

// State for Featured Carousel Slides
const slides = ref<SlideRow[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showEditorModal = ref(false)
const uploadingImage = ref(false)

const form = ref({
  id: '',
  tag: 'Próximo Partido',
  title: '',
  subtitle: '',
  cta_text: 'Ver Detalles',
  cta_url: '#proximo-partido',
  image_url: '',
  bg_gradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
  badge_variant: 'accent',
  order_index: 0,
  is_published: true,
  starts_at: '',
  ends_at: ''
})

const columns = [
  { key: 'order_index', label: 'Orden', align: 'center' as const, width: '80px' },
  { key: 'title', label: 'Slide / Contenido' },
  { key: 'tag', label: 'Etiqueta' },
  { key: 'is_published', label: 'Estado', align: 'center' as const },
  { key: 'actions', label: 'Acciones', align: 'right' as const }
]

const gradientOptions = [
  { value: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900', label: 'Verde Guaiquerí Intenso' },
  { value: 'from-amber-600 via-orange-800 to-slate-950', label: 'Dorado Élite Insular' },
  { value: 'from-red-900 via-slate-900 to-slate-950', label: 'Rojo Bandana Fervor' },
  { value: 'from-slate-800 via-slate-900 to-black', label: 'Noche Oscura Clásica' }
]

const badgeVariantOptions = [
  { value: 'accent', label: 'Acento (Rojo)' },
  { value: 'gold', label: 'Oro / Destacado' },
  { value: 'primary', label: 'Verde Oficial' }
]

const loadHeroSettings = async () => {
  try {
    const { data } = await supabase.from('landing_settings').select('hero_carousel_enabled').eq('id', 1).maybeSingle()
    if (data) {
      heroCarouselEnabled.value = Boolean(data.hero_carousel_enabled)
    }
  } catch (err) {
    console.error('Error fetching hero carousel enabled:', err)
  }
}

const saveHeroCarouselToggle = async () => {
  try {
    await supabase.from('landing_settings').upsert({
      id: 1,
      hero_carousel_enabled: heroCarouselEnabled.value,
      updated_at: new Date().toISOString()
    })
    successMessage.value = 'Estado del carrusel actualizado.'
  } catch (err: any) {
    errorMessage.value = err.message
  }
}

const loadSlides = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('carousel_slides')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    slides.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const openNewSlide = () => {
  form.value = {
    id: '',
    tag: 'Próximo Partido',
    title: '',
    subtitle: '',
    cta_text: 'Ver Detalles',
    cta_url: '#proximo-partido',
    image_url: '',
    bg_gradient: 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badge_variant: 'accent',
    order_index: slides.value.length + 1,
    is_published: true,
    starts_at: nowCaracasInput(),
    ends_at: ''
  }
  showEditorModal.value = true
}

const editRow = (row: SlideRow) => {
  form.value = {
    id: row.id,
    tag: row.tag || '',
    title: row.title,
    subtitle: row.subtitle || '',
    cta_text: row.cta_text || '',
    cta_url: row.cta_url || '',
    image_url: row.image_url || '',
    bg_gradient: row.bg_gradient || 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badge_variant: row.badge_variant || 'accent',
    order_index: row.order_index,
    is_published: row.is_published,
    starts_at: row.starts_at ? isoToCaracasInput(row.starts_at) : '',
    ends_at: row.ends_at ? isoToCaracasInput(row.ends_at) : ''
  }
  showEditorModal.value = true
}

const handleImageUpload = async (e: Event) => {
  const target = e.target as HTMLInputElement
  if (!target.files?.length) return

  const file = target.files[0]
  uploadingImage.value = true
  try {
    const ext = file.name.split('.').pop()
    const path = `carousel_${Date.now()}.${ext}`

    const { error } = await supabase.storage.from('site-media').upload(path, file)
    if (error) throw error

    const { data } = supabase.storage.from('site-media').getPublicUrl(path)
    form.value.image_url = data.publicUrl
    successMessage.value = 'Imagen del slide subida.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    uploadingImage.value = false
  }
}

const saveRow = async () => {
  if (!form.value.title) {
    errorMessage.value = 'El título del slide es obligatorio.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const payload = {
      tag: form.value.tag,
      title: form.value.title,
      subtitle: form.value.subtitle,
      cta_text: form.value.cta_text,
      cta_url: form.value.cta_url,
      image_url: form.value.image_url,
      bg_gradient: form.value.bg_gradient,
      badge_variant: form.value.badge_variant,
      order_index: Number(form.value.order_index),
      is_published: form.value.is_published,
      starts_at: form.value.starts_at ? caracasInputToISO(form.value.starts_at) : caracasInputToISO(nowCaracasInput()),
      ends_at: form.value.ends_at ? caracasInputToISO(form.value.ends_at) : null
    }

    if (form.value.id) {
      const { error } = await supabase.from('carousel_slides').update(payload).eq('id', form.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('carousel_slides').insert(payload)
      if (error) throw error
    }

    successMessage.value = 'Slide guardado correctamente.'
    showEditorModal.value = false
    await loadSlides()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deleteRow = async (id: string) => {
  if (!confirm('¿Desea eliminar este slide del carrusel?')) return
  actionLoading.value = true
  try {
    const { error } = await supabase.from('carousel_slides').delete().eq('id', id)
    if (error) throw error
    successMessage.value = 'Slide eliminado.'
    await loadSlides()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

onMounted(() => {
  loadHeroSettings()
  loadSlides()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Sub-navigation between Hero Carousel and Featured Carousel -->
    <div class="flex items-center gap-2 border-b border-slate-800 pb-3 flex-wrap">
      <button
        @click="activeSubTab = 'hero-carousel'"
        :class="[
          'px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all flex items-center gap-2',
          activeSubTab === 'hero-carousel'
            ? 'bg-emerald-600 text-white shadow-xs'
            : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
        ]"
      >
        <i class="bi bi-window-split"></i>
        <span>Carrusel Hero</span>
        <span
          v-if="heroCarouselEnabled"
          class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse ml-0.5"
          title="Carrusel Activo"
        ></span>
      </button>

      <button
        @click="activeSubTab = 'featured-carousel'"
        :class="[
          'px-3.5 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-all flex items-center gap-2',
          activeSubTab === 'featured-carousel'
            ? 'bg-emerald-600 text-white shadow-xs'
            : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
        ]"
      >
        <i class="bi bi-images"></i>
        <span>Carrusel de Novedades (Landing)</span>
        <span class="text-[11px] bg-slate-800 text-slate-300 px-1.5 py-0.5 rounded-full font-mono">{{ slides.length }}</span>
      </button>
    </div>

    <!-- SUB-TAB 1: Hero Carousel Manager (Full screen slides + live preview) -->
    <div v-if="activeSubTab === 'hero-carousel'" class="space-y-6">
      <HeroCarouselManager
        v-model:carousel-enabled="heroCarouselEnabled"
        @toggle-carousel="saveHeroCarouselToggle"
      />
    </div>

    <!-- SUB-TAB 2: Featured Carousel Slides Manager -->
    <div v-if="activeSubTab === 'featured-carousel'" class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h3 class="text-lg font-bold text-white flex items-center gap-2">
            <i class="bi bi-images text-emerald-400"></i> Diapositivas de Novedades
          </h3>
          <p class="text-xs text-slate-400 mt-1">Tarjetas destacadas del carrusel de novedades en la página de inicio.</p>
        </div>
        <BaseButton variant="primary" size="sm" @click="openNewSlide">
          <i class="bi bi-plus-lg mr-1.5"></i> Nuevo Slide
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <BaseTable :columns="columns" :data="slides" :loading="loading" empty-text="No hay slides configurados">
        <template #cell-order_index="{ row }">
          <span class="font-mono font-bold text-emerald-400">#{{ (row as any).order_index }}</span>
        </template>

        <template #cell-title="{ row }">
          <div class="font-semibold text-white">{{ (row as any).title }}</div>
          <div class="text-xs text-slate-400 truncate max-w-xs">{{ (row as any).subtitle }}</div>
        </template>

        <template #cell-tag="{ row }">
          <span class="text-xs font-mono text-emerald-400 font-semibold">{{ (row as any).tag }}</span>
        </template>

        <template #cell-is_published="{ row }">
          <BaseBadge :variant="(row as any).is_published ? 'success' : 'soft'">
            {{ (row as any).is_published ? 'Publicado' : 'Borrador' }}
          </BaseBadge>
        </template>

        <template #cell-actions="{ row }">
          <div class="flex items-center justify-end gap-1.5">
            <button @click="editRow(row as any)" class="p-1.5 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button @click="deleteRow((row as any).id)" class="p-1.5 text-red-400 hover:bg-red-950 rounded-lg transition-colors" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </template>
      </BaseTable>
    </div>

    <!-- Modal Editor para Diapositivas de Novedades -->
    <BaseModal v-if="showEditorModal" :is-open="showEditorModal" title="Editor de Diapositiva" @close="showEditorModal = false">
      <div class="space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <BaseInput label="Etiqueta / Badge" v-model="form.tag" placeholder="Ej: Próximo Partido" />
          <BaseSelect label="Estilo de Insignia" v-model="form.badge_variant" :options="badgeVariantOptions" />
          <BaseInput label="Orden" type="number" v-model="form.order_index" />
        </div>

        <BaseInput label="Título de la Diapositiva" v-model="form.title" placeholder="Ej: Gran Clásico Oriental" />
        <BaseInput label="Subtítulo / Mensaje Breve" v-model="form.subtitle" placeholder="Ej: Responde la trivia y canjea tus entradas" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Texto Botón de Acción" v-model="form.cta_text" placeholder="Ej: Ver Detalles" />
          <BaseInput label="Enlace Botón de Acción" v-model="form.cta_url" placeholder="#proximo-partido" />
        </div>

        <BaseSelect label="Fondo / Degradado Visual" v-model="form.bg_gradient" :options="gradientOptions" />

        <div>
          <label class="block text-xs font-semibold text-slate-300 mb-1">Imagen de Fondo (Opcional)</label>
          <input
            type="file"
            accept="image/*"
            @change="handleImageUpload"
            class="block w-full text-xs text-slate-400 file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-semibold file:bg-slate-800 file:text-emerald-400 hover:file:bg-slate-700 cursor-pointer"
          />
          <span v-if="uploadingImage" class="text-xs text-emerald-400 mt-1 block">Subiendo imagen...</span>
          <div v-if="form.image_url" class="mt-2 flex items-center gap-2">
            <img :src="form.image_url" class="h-10 w-16 object-cover rounded border border-slate-700" alt="Preview" />
            <button type="button" @click="form.image_url = ''" class="text-xs text-red-400 hover:underline">Quitar imagen</button>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <BaseInput label="Válido Desde (GMT-4)" type="datetime-local" v-model="form.starts_at" />
          <BaseInput label="Válido Hasta (Opcional)" type="datetime-local" v-model="form.ends_at" />
        </div>

        <label class="flex items-center gap-2 text-sm text-slate-300 cursor-pointer pt-2">
          <input type="checkbox" v-model="form.is_published" class="accent-emerald-500 rounded" />
          <span>Publicado inmediatamente</span>
        </label>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showEditorModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="saveRow">Guardar Diapositiva</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>
