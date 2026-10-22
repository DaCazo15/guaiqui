<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import NewsInstagramHeader from '~/components/noticias/NewsInstagramHeader.vue'
import NewsInstagramModal from '~/components/noticias/NewsInstagramModal.vue'
import { newsInstagramPosts, type InstagramNewsPost } from '~/data/newsInstagramData'
import { useSupabaseClient } from '#imports'

useSeoMeta({
  title: 'Noticias y Actualidad — Guaiqueríes de Margarita',
  description: 'Sigue todas las noticias oficiales, resultados de playoffs, fichajes y coberturas de la Tribu Verde en formato Instagram.',
})

const supabase = useSupabaseClient()
const dbPosts = ref<InstagramNewsPost[]>([])
const activeFilter = ref<'all' | 'playoffs' | 'roster' | 'clasico' | 'community'>('all')
const selectedPost = ref<InstagramNewsPost | null>(null)
const likedPosts = ref<Record<string, boolean>>({})

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('instagram_posts')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })

    if (data && data.length > 0) {
      dbPosts.value = data.map((d: any, idx: number) => ({
        id: d.id,
        title: d.caption,
        badge: 'OFICIAL',
        caption: d.caption,
        image_url: d.image_url,
        date_formatted: d.created_at
          ? new Date(d.created_at).toLocaleDateString('es-VE', {
              day: 'numeric',
              month: 'long',
              year: 'numeric',
            })
          : 'Reciente',
        timestamp: d.created_at || new Date().toISOString(),
        category: 'playoffs',
        post_url: d.post_url,
        likes_count: 1420 + idx * 180,
        comments_count: 94 + idx * 14,
        tags: ['#Guaiqueríes', '#LaTribuVerde', '#SomosLaTribu'],
        is_verified: true,
        author: {
          username: 'guaiqueriesbbc',
          name: 'Guaiqueríes de Margarita',
          avatar: '/logo.png',
        },
      }))
    }
  } catch {
    // Keep fallback
  }
})

const postsList = computed(() => {
  return dbPosts.value.length > 0 ? dbPosts.value : newsInstagramPosts
})

const filteredPosts = computed(() => {
  if (activeFilter.value === 'all') return postsList.value
  return postsList.value.filter((p) => p.category === activeFilter.value)
})

function toggleLike(postId: string) {
  likedPosts.value[postId] = !likedPosts.value[postId]
}

function openPostModal(post: InstagramNewsPost) {
  selectedPost.value = post
}

function closePostModal() {
  selectedPost.value = null
}

function onImageError(e: Event) {
  const target = e.target as HTMLImageElement
  if (target && !target.src.includes('noticia-spb-1.jpg')) {
    target.src = '/images/noticias/noticia-spb-1.jpg'
  }
}
</script>

<template>
  <div class="min-h-screen bg-guaiqui-bg text-guaiqui-text">
    <Navbar />

    <main>
      <!-- Profile Header -->
      <NewsInstagramHeader />

      <!-- Feed Container -->
      <div class="max-w-4xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        <!-- Category Filter Tabs -->
        <div class="flex items-center justify-center gap-2 flex-wrap border-b border-guaiqui-border pb-4">
          <button
            type="button"
            @click="activeFilter = 'all'"
            :class="[
              'px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
              activeFilter === 'all'
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
            ]"
          >
            Todas ({{ postsList.length }})
          </button>
          <button
            type="button"
            @click="activeFilter = 'playoffs'"
            :class="[
              'px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
              activeFilter === 'playoffs'
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
            ]"
          >
            Playoffs & Gran Final
          </button>
          <button
            type="button"
            @click="activeFilter = 'clasico'"
            :class="[
              'px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
              activeFilter === 'clasico'
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
            ]"
          >
            Clásico Oriental
          </button>
          <button
            type="button"
            @click="activeFilter = 'roster'"
            :class="[
              'px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
              activeFilter === 'roster'
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
            ]"
          >
            Fichajes
          </button>
          <button
            type="button"
            @click="activeFilter = 'community'"
            :class="[
              'px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all cursor-pointer',
              activeFilter === 'community'
                ? 'bg-guaiqui-primary text-white shadow-xs'
                : 'bg-white text-guaiqui-text-muted hover:text-guaiqui-text border border-guaiqui-border'
            ]"
          >
            Comunidad & Fanáticos
          </button>
        </div>

        <!-- Grid de Noticias oficiales SPB (3 columnas en desktop, adaptado al formato exacto) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-5">
          <div
            v-for="post in filteredPosts"
            :key="post.id"
            class="group relative aspect-[16/10] bg-slate-900 rounded-xl overflow-hidden cursor-pointer shadow-lg hover:shadow-2xl transition-all duration-300 border border-slate-800 hover:border-slate-700 hover:-translate-y-1"
            @click="openPostModal(post)"
          >
            <!-- Imagen oficial en alta definición -->
            <img
              :src="post.image_url"
              :alt="post.title"
              class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
              loading="lazy"
              referrerpolicy="no-referrer"
              @error="onImageError"
            />

            <!-- Badge superior derecho (naranja idéntico a la captura) -->
            <div class="absolute top-3 right-3 z-10">
              <span class="bg-[#f25c05] text-white text-[10px] font-extrabold uppercase px-2.5 py-1 tracking-wider rounded-sm shadow-md">
                {{ post.badge }}
              </span>
            </div>

            <!-- Gradiente oscuro inferior con Título en Mayúsculas y Fecha -->
            <div class="absolute inset-0 bg-gradient-to-t from-black/95 via-black/55 to-transparent flex flex-col justify-end p-4 text-white">
              <h3 class="font-display font-extrabold text-sm sm:text-base text-white uppercase tracking-tight leading-snug line-clamp-2 drop-shadow-md group-hover:text-amber-300 transition-colors">
                {{ post.title }}
              </h3>
              
              <div class="flex items-center justify-between pt-1.5 border-t border-white/10 mt-2">
                <span class="text-[11px] text-slate-300 font-normal tracking-normal drop-shadow">
                  {{ post.date_formatted }}
                </span>
                
                <div class="flex items-center gap-2.5 text-xs font-semibold text-slate-300 group-hover:text-white transition-colors">
                  <span class="flex items-center gap-1">
                    <i class="bi bi-heart-fill text-rose-500 text-[11px]"></i>
                    {{ (post.likes_count + (likedPosts[post.id] ? 1 : 0)).toLocaleString() }}
                  </span>
                  <span class="flex items-center gap-1">
                    <i class="bi bi-chat-fill text-sky-400 text-[11px]"></i>
                    {{ post.comments_count }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Modal Lightbox -->
    <NewsInstagramModal
      :post="selectedPost"
      :is-liked="selectedPost ? !!likedPosts[selectedPost.id] : false"
      @close="closePostModal"
      @toggle-like="toggleLike"
    />

    <SiteFooter />
  </div>
</template>
