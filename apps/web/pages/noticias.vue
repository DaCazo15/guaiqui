<script setup lang="ts">
import { ref, computed } from 'vue'
import Navbar from '~/components/landing/Navbar.vue'
import SiteFooter from '~/components/landing/SiteFooter.vue'
import NewsInstagramHeader from '~/components/noticias/NewsInstagramHeader.vue'
import NewsInstagramModal from '~/components/noticias/NewsInstagramModal.vue'
import { newsInstagramPosts, type InstagramNewsPost } from '~/data/newsInstagramData'

useSeoMeta({
  title: 'Noticias y Actualidad — Guaiqueríes de Margarita',
  description: 'Sigue todas las noticias oficiales, resultados de playoffs, fichajes y coberturas de la Tribu Verde en formato Instagram.',
})

const activeFilter = ref<'all' | 'playoffs' | 'roster' | 'clasico' | 'community'>('all')
const selectedPost = ref<InstagramNewsPost | null>(null)
const likedPosts = ref<Record<string, boolean>>({})

const filteredPosts = computed(() => {
  if (activeFilter.value === 'all') return newsInstagramPosts
  return newsInstagramPosts.filter((p) => p.category === activeFilter.value)
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
  if (target && !target.src.includes('noticia-1.jpg')) {
    target.src = '/images/noticias/noticia-1.jpg'
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
            Todas ({{ newsInstagramPosts.length }})
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

        <!-- Instagram Grid (3 columns on desktop, 2 on mobile) -->
        <div class="grid grid-cols-2 md:grid-cols-3 gap-3 sm:gap-6">
          <div
            v-for="post in filteredPosts"
            :key="post.id"
            class="group relative aspect-square bg-slate-900 rounded-xl overflow-hidden cursor-pointer shadow-sm hover:shadow-md transition-all border border-guaiqui-border"
            @click="openPostModal(post)"
          >
            <img
              :src="post.image_url"
              :alt="post.title"
              class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              loading="lazy"
              referrerpolicy="no-referrer"
              @error="onImageError"
            />

            <!-- Hover Overlay -->
            <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-3 sm:p-4 text-white">
              <div class="flex justify-between items-start">
                <span class="text-[10px] font-mono uppercase bg-emerald-600/90 px-2 py-0.5 rounded-full font-bold">
                  {{ post.date_formatted }}
                </span>
                <i class="bi bi-instagram text-sm text-pink-400"></i>
              </div>

              <div class="space-y-1">
                <p class="font-display font-bold text-xs sm:text-sm uppercase leading-tight line-clamp-2">
                  {{ post.title }}
                </p>
                <div class="flex items-center gap-3 text-xs font-semibold pt-1">
                  <span class="flex items-center gap-1">
                    <i class="bi bi-heart-fill text-rose-500"></i>
                    {{ (post.likes_count + (likedPosts[post.id] ? 1 : 0)).toLocaleString() }}
                  </span>
                  <span class="flex items-center gap-1">
                    <i class="bi bi-chat-fill"></i>
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
