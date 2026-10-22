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
const showAdvancedOptions = ref(false)
const fileInputRef = ref<HTMLInputElement | null>(null)
const selectedImageFile = ref<File | null>(null)
const previewImageUrl = ref<string | null>(null)

const postForm = ref({
  post_url: '',
  caption: '',
  image_url: '',
})

const DEFAULT_POST_IMAGE = 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop'

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
  showAdvancedOptions.value = false
  postForm.value = {
    post_url: '',
    caption: '',
    image_url: '',
  }
  showAddModal.value = false
}

const addPost = async () => {
  const cleanUrl = postForm.value.post_url.trim()
  if (!cleanUrl) {
    errorMessage.value = 'Ingrese una URL válida de publicación de Instagram.'
    return
  }

  if (posts.value.length >= 8) {
    errorMessage.value = 'Ha alcanzado el límite máximo de 8 publicaciones de Instagram.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null

  try {
    const shortcode = parseShortcode(cleanUrl)
    let finalImageUrl = postForm.value.image_url.trim() || DEFAULT_POST_IMAGE

    // Si el usuario adjuntó una imagen personalizada, subirla a Supabase Storage
    if (selectedImageFile.value) {
      const ext = selectedImageFile.value.type.includes('png') ? 'png' : 'webp'
      const filePath = `instagram/${shortcode || crypto.randomUUID()}_${Date.now()}.${ext}`

      const { error: uploadErr } = await supabase.storage
        .from('site-media')
        .upload(filePath, selectedImageFile.value, {
          contentType: selectedImageFile.value.type || 'image/webp',
          upsert: true,
        })

      if (!uploadErr) {
        const { data: pubData } = supabase.storage
          .from('site-media')
          .getPublicUrl(filePath)
        if (pubData?.publicUrl) {
          finalImageUrl = pubData.publicUrl
        }
      }
    }

    const finalCaption = postForm.value.caption.trim() || 'Publicación oficial en Instagram @guaiqueriesbbc'

    const { error } = await supabase.from('instagram_posts').insert({
      post_url: cleanUrl,
      shortcode: shortcode || undefined,
      image_url: finalImageUrl,
      caption: finalCaption,
      order_index: posts.value.length + 1,
      is_published: true,
    })

    if (error) throw error

    successMessage.value = 'Publicación de Instagram agregada exitosamente.'
    resetForm()
    await loadPosts()
  } catch (err: any) {
    errorMessage.value = err.message
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
    const target = posts.value[targetIndex]

    await supabase.from('instagram_posts').update({ order_index: target.order_index }).eq('id', current.id)
    await supabase.from('instagram_posts').update({ order_index: current.order_index }).eq('id', target.id)

    await loadPosts()
    successMessage.value = 'Orden actualizado correctamente.'
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const deletePost = async (id: string) => {
  if (!confirm('¿Desea eliminar esta publicación de las noticias / mosaico?')) return
  actionLoading.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.from('instagram_posts').delete().eq('id', id)
    if (error) throw error

    successMessage.value = 'Publicación eliminada.'
    await loadPosts()
  } catch (err: any) {
    errorMessage.value = err.message
  } finally {
    actionLoading.value = false
  }
}

const onImageError = (e: Event) => {
  const img = e.target as HTMLImageElement
  img.src = DEFAULT_POST_IMAGE
}

onMounted(loadPosts)
</script>

<template>
  <AdminLayout>
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold font-title text-white flex items-center gap-2">
            <i class="bi bi-instagram text-pink-400"></i> Mosaico de Instagram y Noticias
          </h1>
          <p class="text-sm text-slate-400 mt-0.5">
            Agrega los enlaces oficiales de las publicaciones de Instagram de Guaiqueríes. Las primeras 6 publicaciones nutren la sección de Noticias.
          </p>
        </div>
        <BaseButton variant="primary" :disabled="posts.length >= 8" @click="showAddModal = true">
          <i class="bi bi-plus-lg mr-1.5"></i> Agregar Publicación
        </BaseButton>
      </div>

      <!-- Messages -->
      <div v-if="errorMessage" class="p-4 bg-red-950/60 border border-red-800 text-red-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ errorMessage }}</span>
        <button @click="errorMessage = null" class="text-red-400 hover:text-red-200"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="successMessage" class="p-4 bg-emerald-950/60 border border-emerald-800 text-emerald-200 rounded-xl text-sm flex items-center justify-between">
        <span>{{ successMessage }}</span>
        <button @click="successMessage = null" class="text-emerald-400 hover:text-emerald-200"><i class="bi bi-x-lg"></i></button>
      </div>

      <!-- Mosaic Grid Preview -->
      <div v-if="loading" class="text-center py-12 text-slate-500">
        <i class="bi bi-arrow-repeat animate-spin text-2xl"></i>
      </div>

      <div v-else-if="posts.length === 0" class="text-center py-16 bg-slate-900 rounded-2xl border border-slate-800 shadow-xl">
        <div class="w-16 h-16 rounded-full bg-pink-950/60 border border-pink-800/60 text-pink-400 flex items-center justify-center text-3xl mx-auto mb-3">
          <i class="bi bi-instagram"></i>
        </div>
        <h3 class="text-lg font-bold text-white">Sin publicaciones registradas</h3>
        <p class="text-xs text-slate-400 mt-1 max-w-md mx-auto">
          Pega el enlace de las publicaciones de Instagram oficiales (@guaiqueriesbbc) para que aparezcan en la app y la landing.
        </p>
      </div>

      <div v-else class="space-y-4">
        <div class="p-3 bg-emerald-950/50 border border-emerald-800 rounded-xl text-xs text-emerald-300 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <i class="bi bi-check-circle-fill text-emerald-400"></i>
            <span>
              <strong>Noticias Oficiales:</strong> Los primeros 6 posts se sincronizan en vivo en la Landing y en la app de fanáticos (/app/noticias).
            </span>
          </div>
          <span class="font-bold bg-emerald-900/80 text-emerald-300 border border-emerald-700 px-2 py-0.5 rounded text-[11px]">{{ posts.length }} / 8 posts</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <BaseCard
            v-for="(post, index) in posts"
            :key="post.id"
            class="bg-slate-900 border-slate-800 shadow-xl overflow-hidden group relative flex flex-col justify-between rounded-xl"
          >
            <div class="relative h-48 bg-slate-950 overflow-hidden">
              <img
                :src="post.image_url"
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                referrerpolicy="no-referrer"
                @error="onImageError"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent opacity-80" />

              <!-- Badge con posición de noticia -->
              <div
                class="absolute top-2 left-2 px-2 py-0.5 rounded text-[10px] font-bold flex items-center gap-1 shadow-sm"
                :class="index < 6 ? 'bg-emerald-600 text-white' : 'bg-slate-700 text-white'"
              >
                <i class="bi" :class="index < 6 ? 'bi-newspaper' : 'bi-instagram'"></i>
                <span>{{ index < 6 ? `Noticia #${index + 1}` : `Extra #${index + 1}` }}</span>
              </div>

              <!-- Flechas de reordenamiento -->
              <div class="absolute top-2 right-2 flex items-center gap-1 bg-black/60 backdrop-blur-md rounded-lg p-0.5">
                <button
                  type="button"
                  :disabled="index === 0"
                  @click="movePost(index, 'up')"
                  class="p-1 text-white hover:text-emerald-400 disabled:opacity-30 disabled:hover:text-white transition-colors"
                  title="Subir prioridad"
                >
                  <i class="bi bi-chevron-up"></i>
                </button>
                <button
                  type="button"
                  :disabled="index === posts.length - 1"
                  @click="movePost(index, 'down')"
                  class="p-1 text-white hover:text-emerald-400 disabled:opacity-30 disabled:hover:text-white transition-colors"
                  title="Bajar prioridad"
                >
                  <i class="bi bi-chevron-down"></i>
                </button>
              </div>
            </div>

            <div class="p-3.5 space-y-2 bg-slate-900 flex-1 flex flex-col justify-between">
              <div>
                <p class="text-xs font-semibold text-slate-200 line-clamp-2">{{ post.caption || 'Publicación oficial en Instagram' }}</p>
                <span v-if="post.shortcode" class="text-[10px] text-slate-500 font-mono mt-1 block">
                  ID: {{ post.shortcode }}
                </span>
              </div>

              <div class="flex items-center justify-between pt-2.5 border-t border-slate-800 mt-2">
                <a
                  :href="post.post_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-[11px] text-pink-400 hover:text-pink-300 font-bold flex items-center gap-1"
                >
                  <i class="bi bi-instagram"></i>
                  <span>Ver Post</span>
                  <i class="bi bi-box-arrow-up-right text-[10px]"></i>
                </a>
                <button
                  @click="deletePost(post.id)"
                  class="text-red-400 hover:text-red-300 p-1 text-xs"
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

    <!-- Modal Simplificado: Solo URL de Instagram -->
    <BaseModal
      v-if="showAddModal"
      :is-open="showAddModal"
      title="Agregar Post de Instagram"
      @close="resetForm"
    >
      <div class="space-y-4">
        <div>
          <BaseInput
            label="URL de la Publicación de Instagram"
            v-model="postForm.post_url"
            placeholder="https://www.instagram.com/p/DA_5rXbM-c1/"
          />
          <span v-if="parseShortcode(postForm.post_url)" class="text-[11px] text-emerald-400 font-mono mt-1 block">
            <i class="bi bi-check-circle-fill"></i> ID identificado: {{ parseShortcode(postForm.post_url) }}
          </span>
          <p class="text-[11px] text-slate-400 mt-1">
            Copia y pega el enlace del post del perfil oficial @guaiqueriesbbc.
          </p>
        </div>

        <!-- Toggle Opciones Personalizadas (Opcional) -->
        <div class="pt-2 border-t border-slate-800">
          <button
            type="button"
            class="text-xs text-slate-400 hover:text-white font-semibold flex items-center gap-1"
            @click="showAdvancedOptions = !showAdvancedOptions"
          >
            <i :class="showAdvancedOptions ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
            <span>Personalizar Título o Foto (Opcional)</span>
          </button>

          <div v-if="showAdvancedOptions" class="mt-3 space-y-3 bg-slate-950/60 p-3 rounded-xl border border-slate-800">
            <BaseInput
              label="Titular para la noticia (Opcional)"
              v-model="postForm.caption"
              placeholder="Ej: PRÓXIMOS ENCUENTROS VS PIRATAS"
            />

            <div>
              <label class="block text-xs font-semibold text-slate-300 mb-1">
                Foto representativa (Opcional)
              </label>
              <input
                ref="fileInputRef"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                class="hidden"
                @change="handleFileSelect"
              />
              <div
                @click="triggerFileInput"
                class="border border-dashed border-slate-700 hover:border-emerald-500 rounded-lg p-3 text-center cursor-pointer bg-slate-900 text-xs text-slate-300"
              >
                <span v-if="selectedImageFile">{{ selectedImageFile.name }}</span>
                <span v-else><i class="bi bi-upload mr-1"></i> Subir imagen personalizada (PNG / JPG / WebP)</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="resetForm">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="addPost">
            <i class="bi bi-check2 mr-1.5"></i> Agregar Publicación
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
