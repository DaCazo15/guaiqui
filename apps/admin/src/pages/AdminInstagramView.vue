<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '../components/layout/AdminLayout.vue'
import { BaseButton, BaseBadge, BaseInput, BaseModal, BaseCard } from '@guaiqui/ui'
import { supabase } from '../lib/supabase'

interface InstagramPost {
  id: string
  post_url: string
  shortcode?: string
  image_url?: string
  caption?: string
  order_index: number
  is_published: boolean
  created_at: string
}

const posts = ref<InstagramPost[]>([])
const loading = ref(true)
const actionLoading = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const showAddModal = ref(false)
const fileInputRef = ref<HTMLInputElement | null>(null)
const selectedImageFile = ref<File | null>(null)
const previewImageUrl = ref<string | null>(null)

const postForm = ref({
  post_url: '',
  caption: '',
  image_url: '',
})

const loadPosts = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('instagram_posts')
      .select('*')
      .order('order_index', { ascending: true })

    if (error) throw error
    posts.value = data || []
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    loading.value = false
  }
}

const parseShortcode = (url: string) => {
  if (!url) return ''
  const match = url.match(/\/(p|reel)\/([^/?#]+)/)
  return match ? match[2] : ''
}

const triggerFileInput = () => {
  fileInputRef.value?.click()
}

const handleFileSelect = (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (file) {
    selectedImageFile.value = file
    if (previewImageUrl.value && previewImageUrl.value.startsWith('blob:')) {
      URL.revokeObjectURL(previewImageUrl.value)
    }
    previewImageUrl.value = URL.createObjectURL(file)
  }
}

const resetForm = () => {
  if (previewImageUrl.value && previewImageUrl.value.startsWith('blob:')) {
    URL.revokeObjectURL(previewImageUrl.value)
  }
  selectedImageFile.value = null
  previewImageUrl.value = null
  postForm.value = {
    post_url: '',
    caption: '',
    image_url: '',
  }
  showAddModal.value = false
}

const addPost = async () => {
  if (!postForm.value.post_url) {
    errorMessage.value = 'Ingrese una URL válida de publicación de Instagram.'
    return
  }

  if (posts.value.length >= 8) {
    errorMessage.value = 'Ha alcanzado el límite máximo de 8 publicaciones de Instagram.'
    return
  }

  const hasImage = selectedImageFile.value || postForm.value.image_url.trim()
  if (!hasImage) {
    errorMessage.value = 'Debes subir una foto para la publicación o ingresar una URL de imagen.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const shortcode = parseShortcode(postForm.value.post_url)
    let finalImageUrl = postForm.value.image_url.trim()

    // Si el admin seleccionó un archivo local, subirlo a Supabase Storage (site-media)
    if (selectedImageFile.value) {
      const ext = selectedImageFile.value.type.includes('png') ? 'png' : 'webp'
      const filePath = `instagram/${shortcode || crypto.randomUUID()}_${Date.now()}.${ext}`

      const { error: uploadErr } = await supabase.storage
        .from('site-media')
        .upload(filePath, selectedImageFile.value, {
          contentType: selectedImageFile.value.type || 'image/webp',
          upsert: true,
        })

      if (uploadErr) throw uploadErr

      const { data: urlData } = supabase.storage
        .from('site-media')
        .getPublicUrl(filePath)

      finalImageUrl = urlData.publicUrl
    }

    const { error } = await supabase.from('instagram_posts').insert({
      post_url: postForm.value.post_url.trim(),
      shortcode: shortcode || undefined,
      image_url: finalImageUrl,
      caption: postForm.value.caption.trim() || 'Publicación oficial de Guaiqueríes de Margarita',
      order_index: posts.value.length + 1,
      is_published: true,
    })

    if (error) throw error

    successMessage.value = 'Publicación de Instagram agregada al mosaico exitosamente.'
    resetForm()
    await loadPosts()
  } catch (err: any) {
    errorMessage.value = err.message || 'Error al guardar la publicación de Instagram.'
  } finally {
    actionLoading.value = false
  }
}

const movePost = async (index: number, direction: 'up' | 'down') => {
  const targetIndex = direction === 'up' ? index - 1 : index + 1
  if (targetIndex < 0 || targetIndex >= posts.value.length) return

  actionLoading.value = true
  errorMessage.value = null
  try {
    const current = posts.value[index]
    const other = posts.value[targetIndex]

    await supabase.from('instagram_posts').update({ order_index: other.order_index }).eq('id', current.id)
    await supabase.from('instagram_posts').update({ order_index: current.order_index }).eq('id', other.id)

    await loadPosts()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deletePost = async (id: string) => {
  if (!confirm('¿Desea eliminar esta publicación del mosaico de Instagram?')) return
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.from('instagram_posts').delete().eq('id', id)
    if (error) throw error

    successMessage.value = 'Publicación removida del mosaico.'
    await loadPosts()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

function onImageError(e: Event) {
  const target = e.target as HTMLImageElement
  if (target && !target.src.includes('noticia-1.jpg')) {
    target.src = '/images/noticias/noticia-1.jpg'
  }
}

onMounted(loadPosts)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-instagram text-pink-500"></i> Mosaico de Instagram Landing (Máx 8)
          </h1>
          <p class="text-sm text-slate-400">Pegue el enlace oficial de una publicación de Instagram para renderizarla en el mosaico de la landing.</p>
        </div>
        <BaseButton variant="primary" :disabled="posts.length >= 8" @click="showAddModal = true">
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Publicación
        </BaseButton>
      </div>

      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-300 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-slate-400 hover:text-white"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- Mosaic Grid Preview (Up to 8 items, Top 6 for News) -->
      <div v-if="loading" class="text-center py-12 text-slate-400">
        <i class="bi bi-arrow-repeat animate-spin text-2xl"></i>
      </div>

      <div v-else-if="posts.length === 0" class="text-center py-16 bg-slate-900 rounded-2xl border border-slate-800">
        <i class="bi bi-instagram text-4xl text-slate-600 block mb-2"></i>
        <h3 class="text-lg font-bold text-white">Mosaico de Instagram Vacío</h3>
        <p class="text-xs text-slate-400 mt-1 max-w-md mx-auto">
          Agrega los enlaces de los posts de Instagram de Guaiqueríes. Los primeros 6 se mostrarán automáticamente en la sección de Noticias.
        </p>
      </div>

      <div v-else class="space-y-4">
        <div class="p-3 bg-emerald-950/40 border border-emerald-800/60 rounded-xl text-xs text-emerald-300 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <i class="bi bi-info-circle-fill text-emerald-400"></i>
            <span>
              <strong>Noticias activas:</strong> Las primeras 6 publicaciones (#1 al #6) se sincronizan en vivo en la Landing y en la app de fanáticos (/app/noticias).
            </span>
          </div>
          <span class="font-bold bg-emerald-900/60 px-2 py-0.5 rounded text-[11px]">{{ posts.length }} / 8 posts</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <BaseCard
            v-for="(post, index) in posts"
            :key="post.id"
            class="bg-slate-900 border-slate-800 overflow-hidden group relative flex flex-col justify-between"
          >
            <div class="relative h-48 bg-slate-950 overflow-hidden">
              <img
                :src="post.image_url"
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                referrerpolicy="no-referrer"
                @error="onImageError"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-transparent to-transparent opacity-80" />
              
              <!-- Badge de Posición / Noticia -->
              <div class="absolute top-2 left-2">
                <span
                  :class="[
                    'px-2 py-0.5 rounded text-[10px] font-bold flex items-center gap-1 shadow-md',
                    index < 6 ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300'
                  ]"
                >
                  <i class="bi bi-newspaper"></i> #{{ index + 1 }} {{ index < 6 ? '(Noticia)' : '' }}
                </span>
              </div>

              <!-- Botones de Reordenamiento Rápido -->
              <div class="absolute top-2 right-2 flex items-center gap-1 bg-black/60 backdrop-blur-md rounded-lg p-0.5">
                <button
                  type="button"
                  @click="movePost(index, 'up')"
                  :disabled="index === 0 || actionLoading"
                  class="p-1 text-slate-300 hover:text-white disabled:opacity-30 transition-colors"
                  title="Subir posición"
                >
                  <i class="bi bi-chevron-left sm:bi-chevron-up"></i>
                </button>
                <button
                  type="button"
                  @click="movePost(index, 'down')"
                  :disabled="index === posts.length - 1 || actionLoading"
                  class="p-1 text-slate-300 hover:text-white disabled:opacity-30 transition-colors"
                  title="Bajar posición"
                >
                  <i class="bi bi-chevron-right sm:bi-chevron-down"></i>
                </button>
              </div>
            </div>

            <div class="p-3.5 space-y-2.5">
              <p class="text-xs text-white font-medium line-clamp-2">{{ post.caption || 'Publicación oficial' }}</p>
              
              <div class="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px]">
                <a :href="post.post_url" target="_blank" class="text-sky-400 hover:text-sky-300 flex items-center gap-1 font-semibold">
                  <i class="bi bi-instagram text-pink-400"></i> Ver Post <i class="bi bi-box-arrow-up-right text-[10px]"></i>
                </a>
                <button
                  type="button"
                  @click="deletePost(post.id)"
                  :disabled="actionLoading"
                  class="text-red-400 hover:text-red-300 p-1 transition-colors"
                  title="Eliminar publicación"
                >
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </div>
          </BaseCard>
        </div>
      </div>
    </div>

    <!-- Modal para Agregar Post de Instagram -->
    <BaseModal v-if="showAddModal" :is-open="showAddModal" title="Agregar Noticia / Post de Instagram" @close="resetForm">
      <div class="space-y-4">
        <!-- 1. Enlace de Instagram -->
        <div>
          <BaseInput
            label="URL de la publicación de Instagram"
            v-model="postForm.post_url"
            placeholder="https://www.instagram.com/p/DA_5rXbM-c1/"
          />
          <span v-if="parseShortcode(postForm.post_url)" class="text-[11px] text-pink-400 font-mono mt-1 block">
            <i class="bi bi-check-circle-fill"></i> ID de publicación: {{ parseShortcode(postForm.post_url) }}
          </span>
        </div>

        <!-- 2. Titular / Caption -->
        <BaseInput
          label="Titular / Título para la noticia"
          v-model="postForm.caption"
          placeholder="Ej: PRÓXIMOS ENCUENTROS VS PIRATAS DE LA GUAIRA"
        />

        <!-- 3. Subida de Foto del Post (Almacenamiento permanente en Supabase) -->
        <div class="space-y-2">
          <label class="block text-xs font-semibold text-slate-300">
            Foto del Post (Se almacena permanentemente en Supabase Storage)
          </label>

          <!-- Input oculto para archivo -->
          <input
            ref="fileInputRef"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            class="hidden"
            @change="handleFileSelect"
          />

          <!-- Botón o Dropzone para subir imagen -->
          <div
            @click="triggerFileInput"
            class="border-2 border-dashed border-slate-700 hover:border-emerald-500 rounded-xl p-4 text-center cursor-pointer transition-colors bg-slate-900/50 flex flex-col items-center justify-center gap-2"
          >
            <!-- Previsualización si ya hay archivo o URL -->
            <div v-if="previewImageUrl || postForm.image_url" class="relative w-full aspect-[16/10] max-h-48 rounded-lg overflow-hidden bg-slate-950 border border-slate-800">
              <img
                :src="previewImageUrl || postForm.image_url"
                alt="Vista previa"
                class="w-full h-full object-cover"
                @error="onImageError"
              />
              <div class="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                <span class="text-xs font-bold text-white bg-black/70 px-3 py-1.5 rounded-lg border border-white/20">
                  <i class="bi bi-arrow-repeat"></i> Cambiar imagen
                </span>
              </div>
            </div>

            <!-- Estado sin imagen seleccionada -->
            <div v-else class="space-y-1 py-3 text-slate-400">
              <i class="bi bi-cloud-arrow-up text-3xl text-emerald-400 block mb-1"></i>
              <span class="text-xs font-bold text-white block">Haz clic para seleccionar o arrastrar la foto del post</span>
              <span class="text-[11px] text-slate-400 block">PNG, JPG o WebP (Hasta 5 MB)</span>
            </div>
          </div>
        </div>

        <!-- Opción alternativa: URL externa si no sube archivo -->
        <div class="pt-1">
          <button
            type="button"
            class="text-[11px] text-slate-400 hover:text-slate-200 underline"
            @click="postForm.image_url = postForm.image_url ? '' : 'https://'"
          >
            {{ postForm.image_url ? 'Ocultar campo de URL directa' : 'O pegar URL directa de imagen externa' }}
          </button>
          <div v-if="postForm.image_url" class="mt-2">
            <BaseInput label="URL directa de la imagen" v-model="postForm.image_url" placeholder="https://..." />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="resetForm">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="addPost">
            <i class="bi bi-check2-circle mr-1.5"></i> Guardar Noticia
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
