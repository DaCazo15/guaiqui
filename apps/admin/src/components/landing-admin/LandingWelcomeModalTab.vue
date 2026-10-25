<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { caracasInputToISO, isoToCaracasInput, nowCaracasInput } from '@guaiqui/shared'
import { supabase } from '../../lib/supabase'

interface LoginModalSlide {
  id: string
  position: number
  image_url?: string | null
  title: string
  subtitle?: string | null
  cta_label: string
  cta_url: string
  status: 'draft' | 'published'
  starts_at: string
  ends_at?: string | null
  created_at: string
}

const slides = ref<LoginModalSlide[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const uploadLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const previewDevice = ref<'desktop' | 'mobile'>('desktop')
const selectedSlide = ref<LoginModalSlide | null>(null)

const form = ref({
  id: '',
  position: 1,
  image_url: '',
  title: '',
  subtitle: '',
  cta_label: 'Ver más',
  cta_url: '/app/tienda',
  status: 'draft' as 'draft' | 'published',
  starts_at: '',
  ends_at: ''
})

const publishedCount = computed(() => slides.value.filter(s => s.status === 'published').length)

const currentPreview = computed(() => {
  return {
    title: form.value.title,
    subtitle: form.value.subtitle,
    image_url: form.value.image_url,
    cta_label: form.value.cta_label
  }
})

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
  successMessage.value = null

  try {
    const payload = {
      position: form.value.position,
      image_url: form.value.image_url.trim() || null,
      title: form.value.title.trim(),
      subtitle: form.value.subtitle.trim() || null,
      cta_label: form.value.cta_label.trim() || 'Ver más',
      cta_url: form.value.cta_url.trim() || '/app/tienda',
      status: form.value.status,
      starts_at: form.value.starts_at ? caracasInputToISO(form.value.starts_at) : caracasInputToISO(nowCaracasInput()),
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
      const { error } = await supabase
        .from('login_modal_slides')
        .insert([payload])

      if (error) throw error
      successMessage.value = 'Diapositiva creada con éxito.'
    }

    await fetchSlides()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar la diapositiva.'
  } finally {
    actionLoading.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('¿Estás seguro de que deseas eliminar esta diapositiva?')) return

  actionLoading.value = true
  errorMessage.value = null

  try {
    const { error } = await supabase
      .from('login_modal_slides')
      .delete()
      .eq('id', id)

    if (error) throw error

    selectedSlide.value = null
    await fetchSlides()
    successMessage.value = 'Diapositiva eliminada correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al eliminar la diapositiva.'
  } finally {
    actionLoading.value = false
  }
}

async function handleFileUpload(e: Event) {
  const target = e.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

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
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4">
          <div class="flex items-center justify-between border-b border-slate-800 pb-3 mb-3">
            <h4 class="text-xs font-semibold text-slate-300 uppercase tracking-wider">
              Diapositivas ({{ slides.length }}/5)
            </h4>
            <span class="text-[11px] font-mono text-emerald-400 bg-emerald-950 px-2 py-0.5 rounded border border-emerald-800">
              {{ publishedCount }} publicadas
            </span>
          </div>

          <div v-if="loading" class="p-6 text-center text-slate-500 text-xs">
            <i class="bi bi-arrow-repeat animate-spin text-lg mb-1 block"></i>
            <span>Cargando lista...</span>
          </div>

          <div v-else-if="slides.length === 0" class="p-6 text-center text-slate-500 text-xs">
            No hay diapositivas registradas. Haz clic en "Nueva Diapositiva".
          </div>

          <div v-else class="space-y-2">
            <div
              v-for="slide in slides"
              :key="slide.id"
              @click="selectSlide(slide)"
              :class="[
                'p-3 rounded-xl border transition-all cursor-pointer flex items-center justify-between gap-3',
                selectedSlide?.id === slide.id ? 'bg-slate-800 border-emerald-500 shadow-md' : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
              ]"
            >
              <div class="flex items-center gap-3 min-w-0">
                <span class="w-6 h-6 rounded-md bg-slate-800 text-emerald-400 font-mono text-xs font-bold flex items-center justify-center shrink-0 border border-slate-700">
                  #{{ slide.position }}
                </span>
                <div class="min-w-0">
                  <p class="text-xs font-bold text-white truncate">{{ slide.title }}</p>
                  <p class="text-[11px] text-slate-400 truncate">{{ slide.cta_url }}</p>
                </div>
              </div>

              <div class="flex items-center gap-2 shrink-0">
                <span :class="['px-2 py-0.5 text-[10px] font-semibold rounded', slide.status === 'published' ? 'bg-emerald-950 text-emerald-300 border border-emerald-800' : 'bg-slate-800 text-slate-400']">
                  {{ slide.status === 'published' ? 'Publicado' : 'Borrador' }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Column 2: Form & Live Preview (8 cols) -->
      <div class="lg:col-span-8 space-y-6">
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-5">
          <h4 class="text-sm font-semibold text-white border-b border-slate-800 pb-3">
            {{ form.id ? 'Editar Diapositiva' : 'Nueva Diapositiva' }}
          </h4>

          <form @submit.prevent="handleSave" class="space-y-4">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Posición (1 a 5)
                </label>
                <input
                  v-model.number="form.position"
                  type="number"
                  min="1"
                  max="5"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
                  required
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Estado de Publicación
                </label>
                <select
                  v-model="form.status"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                >
                  <option value="draft">Borrador (Oculto)</option>
                  <option value="published">Publicado (Visible)</option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Título Destacado
              </label>
              <input
                v-model="form.title"
                type="text"
                maxlength="100"
                class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                required
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Subtítulo / Mensaje Informativo
              </label>
              <textarea
                v-model="form.subtitle"
                rows="2"
                maxlength="250"
                class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 resize-none"
              ></textarea>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Texto del Botón (CTA)
                </label>
                <input
                  v-model="form.cta_label"
                  type="text"
                  maxlength="30"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                  required
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Ruta / Enlace Destino
                </label>
                <input
                  v-model="form.cta_url"
                  type="text"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
                  required
                />
              </div>
            </div>

            <!-- Image Upload -->
            <div>
              <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                Imagen de la Diapositiva
              </label>
              <div class="flex items-center gap-3">
                <input
                  v-model="form.image_url"
                  type="text"
                  placeholder="https://..."
                  class="flex-1 px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500 font-mono"
                />
                <label class="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium rounded-xl cursor-pointer transition border border-slate-700 shrink-0 flex items-center gap-1.5">
                  <i v-if="uploadLoading" class="bi bi-arrow-repeat animate-spin"></i>
                  <i v-else class="bi bi-upload"></i>
                  <span>Subir</span>
                  <input
                    type="file"
                    accept="image/*"
                    class="hidden"
                    @change="handleFileUpload"
                    :disabled="uploadLoading"
                  />
                </label>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Válido Desde — Hora de Caracas (GMT-4)
                </label>
                <input
                  v-model="form.starts_at"
                  type="datetime-local"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Válido Hasta (Opcional) — Hora de Caracas (GMT-4)
                </label>
                <input
                  v-model="form.ends_at"
                  type="datetime-local"
                  class="w-full px-3.5 py-2 bg-slate-950 border border-slate-800 rounded-xl text-white text-xs focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>

            <div class="pt-4 border-t border-slate-800 flex items-center justify-between">
              <button
                v-if="form.id"
                type="button"
                @click="handleDelete(form.id)"
                class="px-4 py-2 bg-red-950 hover:bg-red-900 text-red-300 font-semibold text-xs rounded-xl border border-red-800 transition-all flex items-center gap-1.5"
              >
                <i class="bi bi-trash"></i>
                <span>Eliminar</span>
              </button>

              <div class="flex items-center gap-3 ml-auto">
                <button
                  type="submit"
                  :disabled="actionLoading"
                  class="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-sm rounded-xl transition-all flex items-center gap-2 shadow-lg shadow-emerald-950/50 disabled:opacity-50"
                >
                  <i v-if="actionLoading" class="bi bi-arrow-repeat animate-spin"></i>
                  <i v-else class="bi bi-floppy-fill"></i>
                  <span>Guardar Diapositiva</span>
                </button>
              </div>
            </div>
          </form>
        </div>

        <!-- Live Preview Section -->
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-4">
          <div class="flex items-center justify-between border-b border-slate-800 pb-3">
            <h4 class="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-2">
              <i class="bi bi-eye"></i> Vista Previa en Tiempo Real
            </h4>
            <div class="flex items-center gap-2 bg-slate-950 p-1 rounded-lg border border-slate-800">
              <button
                @click="previewDevice = 'desktop'"
                :class="['px-2.5 py-1 text-xs font-semibold rounded-md transition', previewDevice === 'desktop' ? 'bg-slate-800 text-emerald-400' : 'text-slate-400']"
              >
                <i class="bi bi-display mr-1"></i> Escritorio
              </button>
              <button
                @click="previewDevice = 'mobile'"
                :class="['px-2.5 py-1 text-xs font-semibold rounded-md transition', previewDevice === 'mobile' ? 'bg-slate-800 text-emerald-400' : 'text-slate-400']"
              >
                <i class="bi bi-phone mr-1"></i> Móvil
              </button>
            </div>
          </div>

          <!-- Preview Frame -->
          <div class="flex items-center justify-center p-4 bg-slate-950 rounded-xl">
            <div
              :class="[
                'bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-2xl space-y-4 p-5 transition-all',
                previewDevice === 'desktop' ? 'w-full max-w-[560px]' : 'w-[280px]'
              ]"
            >
              <div class="w-full aspect-video bg-gradient-to-br from-emerald-950 via-slate-900 to-slate-950 rounded-xl overflow-hidden relative flex items-center justify-center border border-slate-800">
                <img
                  v-if="currentPreview.image_url"
                  :src="currentPreview.image_url"
                  class="w-full h-full object-cover"
                />
                <div v-else class="p-4 text-center">
                  <span class="text-xs text-slate-500 font-mono">Sin imagen (Fondo de marca)</span>
                </div>
              </div>

              <div class="space-y-2">
                <span class="text-[10px] font-mono text-emerald-400 uppercase font-bold">Novedades del Club</span>
                <h5 class="text-base font-bold text-white uppercase tracking-wide leading-tight">
                  {{ currentPreview.title || 'Título de ejemplo' }}
                </h5>
                <p class="text-xs text-slate-300 leading-relaxed">
                  {{ currentPreview.subtitle || 'Subtítulo descriptivo de la diapositiva...' }}
                </p>
              </div>

              <div class="pt-3 border-t border-slate-800 flex items-center justify-between">
                <div class="flex gap-1">
                  <span class="w-4 h-1.5 bg-emerald-400 rounded-full"></span>
                  <span class="w-1.5 h-1.5 bg-slate-700 rounded-full"></span>
                </div>
                <button class="px-4 py-1.5 bg-emerald-600 text-white font-bold text-[11px] uppercase tracking-wider rounded-lg">
                  {{ currentPreview.cta_label || 'Ver más' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
