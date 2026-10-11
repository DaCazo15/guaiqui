<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseBadge } from '@guaiqui/ui'
import { useSupabaseClient } from '#imports'

import { newsInstagramPosts } from '~/data/newsInstagramData'

interface InstagramPost {
  id: string
  post_url: string
  image_url?: string
  caption?: string
  shortcode?: string
}

const supabase = useSupabaseClient()
const posts = ref<InstagramPost[]>([])

onMounted(async () => {
  try {
    const { data } = await supabase
      .from('instagram_posts')
      .select('*')
      .eq('is_published', true)
      .order('order_index', { ascending: true })
      .limit(8)

    if (data && data.length > 0) {
      posts.value = data
    } else {
      // Use official SPB news dataset as fallback
      posts.value = newsInstagramPosts.slice(0, 4).map((p) => ({
        id: p.id,
        post_url: 'https://www.instagram.com/guaiqueriesbbc/',
        image_url: p.image_url,
        caption: p.title,
      }))
    }
  } catch {
    posts.value = newsInstagramPosts.slice(0, 4).map((p) => ({
      id: p.id,
      post_url: 'https://www.instagram.com/guaiqueriesbbc/',
      image_url: p.image_url,
      caption: p.title,
    }))
  }
})
</script>

<template>
  <section class="py-16 sm:py-20 bg-slate-950 text-white px-4 sm:px-8 border-t border-slate-900">
    <div class="max-w-6xl mx-auto space-y-8">
      <div class="text-center space-y-2">
        <span class="text-xs uppercase font-bold text-pink-400 tracking-widest bg-pink-950/60 border border-pink-800/60 px-3 py-1 rounded-full inline-flex items-center gap-1.5">
          <i class="bi bi-instagram"></i> @guaiqueriesbbc
        </span>
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl uppercase tracking-tight">
          La Tribu en Instagram
        </h2>
        <p class="text-slate-400 text-xs sm:text-sm max-w-xl mx-auto">
          Sigue las últimas novedades, mejores jugadas e historias de Guaiqueríes de Margarita en redes sociales.
        </p>
      </div>

      <!-- Instagram Mosaic Grid (Flex / Grid up to 8 items) -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <NuxtLink
          v-for="post in posts"
          :key="post.id"
          to="/noticias"
          class="group relative rounded-2xl overflow-hidden aspect-square bg-slate-900 border border-slate-800 focus:outline-none focus:ring-2 focus:ring-pink-500 shadow-lg cursor-pointer"
        >
          <img
            :src="post.image_url"
            :alt="post.caption || 'Instagram Post Guaiqueríes'"
            class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
          />

          <!-- Overlay gradient on hover -->
          <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent opacity-60 group-hover:opacity-90 transition-opacity flex flex-col justify-end p-3">
            <span class="text-xs font-semibold text-white line-clamp-2 drop-shadow-md">
              {{ post.caption }}
            </span>
            <span class="text-[10px] text-pink-400 font-bold flex items-center gap-1 mt-1">
              <i class="bi bi-instagram"></i> Ver publicación
            </span>
          </div>
        </NuxtLink>
      </div>

      <!-- Bottom Action -->
      <div class="text-center pt-2">
        <NuxtLink
          to="/noticias"
          class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-white text-xs font-bold uppercase tracking-wider transition-all"
        >
          <i class="bi bi-newspaper"></i>
          <span>Explorar Todas las Noticias en Feed</span>
          <i class="bi bi-arrow-right"></i>
        </NuxtLink>
      </div>
    </div>
  </section>
</template>
