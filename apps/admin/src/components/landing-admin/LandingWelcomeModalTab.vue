<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'
import type { LoginModalSlide, WelcomeSlideFormData } from './welcome-modal/types'
import WelcomeSlideList from './welcome-modal/WelcomeSlideList.vue'
import WelcomeSlideForm from './welcome-modal/WelcomeSlideForm.vue'
import WelcomeSlidePreview from './welcome-modal/WelcomeSlidePreview.vue'

const slides = ref<LoginModalSlide[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const uploadLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const selectedSlide = ref<LoginModalSlide | null>(null)

const form = ref<WelcomeSlideFormData>({
  id: '',
  position: 1,
  image_url: '',
  title: '',
  subtitle: '',
  cta_label: 'Ver más',
  cta_url: '/app/tienda',
  status: 'draft',
  starts_at: '',
  ends_at: ''
})

const publishedCount = computed(() => slides.value.filter(s => s.status === 'published').length)

const currentPreview = computed(() => ({
  title: form.value.title,
  subtitle: form.value.subtitle,
  image_url: form.value.image_url,
  cta_label: form.value.cta_label
}))

onMounted(async () => {
  await fetchSlides()
})

async function fetchSlides() {
  loading.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('login_modal_slides')
      .select('*')
      .order('position', { ascending: true })

    if (error) throw error
    slides.value = data || []
    if (slides.value.length > 0 && !selectedSlide.value) {
      selectSlide(slides.value[0])
    }
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al cargar diapositivas del modal.'
  } finally {
    loading.value = false
  }
}

function selectSlide(slide: LoginModalSlide) {
  selectedSlide.value = slide
  form.value = {
    id: slide.id,
    position: slide.position,
    image_url: slide.image_url || '',
    title: slide.title,
    subtitle: slide.subtitle || '',
    cta_label: slide.cta_label || 'Ver más',
    cta_url: slide.cta_url || '/app/tienda',
    status: slide.status,
    starts_at: slide.starts_at ? isoToCaracasInput(slide.starts_at) : '',
    ends_at: slide.ends_at ? isoToCaracasInput(slide.ends_at) : ''
  }
}

function openNewSlide() {
  if (slides.value.length >= 5) {
    errorMessage.value = 'Se ha alcanzado el límite máximo de 5 diapositivas creadas.'
    return
  }

  selectedSlide.value = null
  const nextPos = slides.value.length + 1
  form.value = {
    id: '',
    position: nextPos,
    image_url: '',
    title: '¡Nueva Novedad para Fanáticos!',
    subtitle: 'Aprovecha las promociones de la tienda oficial.',
    cta_label: 'Ver más',
    cta_url: '/app/tienda',
    status: 'draft',
    starts_at: nowCaracasInput(),
    ends_at: ''
  }
}

async function handleSave() {
  if (!form.value.title.trim()) {
    errorMessage.value = 'El título de la diapositiva es obligatorio.'
    return
  }

  if (form.value.position < 1 || form.value.position > 5) {
    errorMessage.value = 'La posición debe estar entre 1 y 5.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const payload = {
      position: form.value.position,
      title: form.value.title.trim(),
      subtitle: form.value.subtitle.trim() || null,
      image_url: form.value.image_url.trim() || null,
      cta_label: form.value.cta_label.trim(),
      cta_url: form.value.cta_url.trim(),
      status: form.value.status,
      starts_at: form.value.starts_at ? caracasInputToISO(form.value.starts_at) : new Date().toISOString(),
      ends_at: form.value.ends_at ? caracasInputToISO(form.value.ends_at) : null
    }

    if (form.value.id) {
      const { error } = await supabase
        .from('login_modal_slides')
        .update(payload)
        .eq('id', form.value.id)

      if (error) throw error
      successMessage.value = 'Diapositiva actualizada correctamente.'
    } else {
      const { data, error } = await supabase
        .from('login_modal_slides')
        .insert([payload])
        .select()
        .single()

      if (error) throw error
      successMessage.value = 'Diapositiva creada correctamente.'
      if (data) selectedSlide.value = data
    }

    await fetchSlides()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar diapositiva.'
  } finally {
    actionLoading.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('¿Estás seguro de eliminar esta diapositiva?')) return

  actionLoading.value = true
  errorMessage.value = null

  try {
    const { error } = await supabase
      .from('login_modal_slides')
      .delete()
      .eq('id', id)

    if (error) throw error
    successMessage.value = 'Diapositiva eliminada correctamente.'
    selectedSlide.value = null
    await fetchSlides()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar diapositiva.'
  } finally {
    actionLoading.value = false
  }
}

async function handleFileUpload(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  if (file.size > 5 * 1024 * 1024) {
    errorMessage.value = 'La imagen no debe superar los 5MB.'
    return
  }

  uploadLoading.value = true
  errorMessage.value = null

  try {
    const ext = file.name.split('.').pop()
    const filePath = `modal-slides/${Date.now()}-${Math.random().toString(36).substring(2, 8)}.${ext}`

    const { error: uploadErr } = await supabase.storage
      .from('site-media')
      .upload(filePath, file)

    if (uploadErr) throw uploadErr

    const { data } = supabase.storage
      .from('site-media')
      .getPublicUrl(filePath)

    form.value.image_url = data.publicUrl
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al subir la imagen.'
  } finally {
    uploadLoading.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-4 border-b border-slate-800">
      <div>
        <h3 class="text-lg font-bold font-display uppercase tracking-wide text-white flex items-center gap-2">
          <i class="bi bi-window-stack text-emerald-400"></i>
          Pop-up de Bienvenida
        </h3>
        <p class="text-xs text-slate-400 mt-1">
          Modal visual que se muestra al usuario al iniciar sesión con carrusel de novedades (máx. 5 diapositivas).
        </p>
      </div>

      <button
        @click="openNewSlide"
        :disabled="slides.length >= 5"
        class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-semibold text-xs rounded-xl transition-all flex items-center gap-1.5 shadow-lg shadow-emerald-950/50 self-start sm:self-auto"
      >
        <i class="bi bi-plus-lg"></i>
        <span>Nueva Diapositiva</span>
      </button>
    </div>

    <!-- Alerts -->
    <div v-if="successMessage" class="p-3 bg-emerald-950/80 border border-emerald-800 text-emerald-300 rounded-xl text-xs flex items-center justify-between">
      <span>{{ successMessage }}</span>
      <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <div v-if="errorMessage" class="p-3 bg-red-950/80 border border-red-800 text-red-300 rounded-xl text-xs flex items-center justify-between">
      <span>{{ errorMessage }}</span>
      <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
    </div>

    <!-- Main Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
      <!-- Column 1: List (4 cols) -->
      <div class="lg:col-span-4 space-y-4">
        <WelcomeSlideList
          :slides="slides"
          :selected-slide="selectedSlide"
          :loading="loading"
          :published-count="publishedCount"
          @select="selectSlide"
        />
      </div>

      <!-- Column 2: Form & Live Preview (8 cols) -->
      <div class="lg:col-span-8 space-y-6">
        <WelcomeSlideForm
          :form="form"
          :action-loading="actionLoading"
          :upload-loading="uploadLoading"
          @save="handleSave"
          @delete="handleDelete"
          @upload="handleFileUpload"
        />

        <WelcomeSlidePreview :preview="currentPreview" />
      </div>
    </div>
  </div>
</template>
