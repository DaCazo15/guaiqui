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
const postForm = ref({
  post_url: '',
  caption: '',
  image_url: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop'
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
  const match = url.match(/\/(p|reel)\/([^/]+)/)
  return match ? match[2] : ''
}

const addPost = async () => {
  if (!postForm.value.post_url) {
    errorMessage.value = 'Ingrese una URL válida de publicación de Instagram.'
    return
  }

  if (posts.value.length >= 8) {
    errorMessage.value = 'Ha alcanzado el límite máximo de 8 publicaciones de Instagram para el mosaico de la landing.'
    return
  }

  actionLoading.value = true
  errorMessage.value = null
  try {
    const shortcode = parseShortcode(postForm.value.post_url)
    const { error } = await supabase.from('instagram_posts').insert({
      post_url: postForm.value.post_url,
      shortcode: shortcode || undefined,
      image_url: postForm.value.image_url || 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop',
      caption: postForm.value.caption || 'Publicación oficial de Guaiqueríes de Margarita en Instagram',
      order_index: posts.value.length + 1,
      is_published: true
    })

    if (error) throw error

    successMessage.value = 'Publicación de Instagram agregada al mosaico exitosamente.'
    showAddModal.value = false
    postForm.value = { post_url: '', caption: '', image_url: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop' }
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

      <!-- Mosaic Grid Preview (Up to 8 items) -->
      <div v-if="loading" class="text-center py-12 text-slate-400">
        <i class="bi bi-arrow-repeat animate-spin text-2xl"></i>
      </div>

      <div v-else-if="posts.length === 0" class="text-center py-16 bg-slate-900 rounded-2xl border border-slate-800">
        <i class="bi bi-instagram text-4xl text-slate-600 block mb-2"></i>
        <h3 class="text-lg font-bold text-white">Mosaico de Instagram Vacío</h3>
        <p class="text-xs text-slate-400 mt-1 max-w-md mx-auto">Agregue hasta 8 enlaces de publicaciones de Instagram para mostrarlas en la landing.</p>
      </div>

      <div v-else class="grid grid-cols-2 sm:grid-cols-4 gap-4">
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
            <div class="absolute top-2 right-2 bg-black/60 backdrop-blur-md px-2 py-0.5 rounded text-[10px] text-pink-400 font-bold flex items-center gap-1">
              <i class="bi bi-instagram"></i> #{{ index + 1 }}
            </div>
          </div>

          <div class="p-3 space-y-2">
            <p class="text-xs text-slate-300 line-clamp-2">{{ post.caption || 'Publicación de Instagram' }}</p>
            <div class="flex items-center justify-between pt-2 border-t border-slate-800">
              <a :href="post.post_url" target="_blank" class="text-[11px] text-sky-400 hover:underline flex items-center gap-1">
                Ver en Instagram <i class="bi bi-box-arrow-up-right"></i>
              </a>
              <button @click="deletePost(post.id)" class="text-red-400 hover:text-red-300 text-xs">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>

    <!-- Add Instagram Modal -->
    <BaseModal v-if="showAddModal" :is-open="showAddModal" title="Agregar Publicación de Instagram" @close="showAddModal = false">
      <div class="space-y-4">
        <BaseInput label="URL de la publicación de Instagram" v-model="postForm.post_url" placeholder="https://www.instagram.com/p/C12345/" />
        <BaseInput label="Leyenda / Título corto para el mosaico" v-model="postForm.caption" placeholder="Ej: Gran victoria de la tribu ante Marinos" />
        <BaseInput label="URL de Imagen de Vista Previa" v-model="postForm.image_url" placeholder="https://..." />

        <div class="p-3 rounded-lg bg-slate-900 text-xs text-slate-400 border border-slate-800 space-y-1">
          <p class="font-semibold text-slate-200">Viabilidad y Formato:</p>
          <p>Se extrae el identificador de la URL para crear la tarjeta interactiva de mosaico (máximo 8 publicaciones activas en grid de flex/grid).</p>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-3">
          <BaseButton variant="secondary" @click="showAddModal = false">Cancelar</BaseButton>
          <BaseButton variant="primary" :loading="actionLoading" @click="addPost">Agregar al Mosaico</BaseButton>
        </div>
      </template>
    </BaseModal>
  </AdminLayout>
</template>
