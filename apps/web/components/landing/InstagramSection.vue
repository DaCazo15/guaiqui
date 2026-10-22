<script setup lang="ts">
import { ref, onMounted } from 'vue'
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
      .limit(6)

    if (data && data.length > 0) {
      posts.value = data.map((d: any) => ({
        id: d.id,
        post_url: d.post_url,
        image_url: d.image_url,
        caption: d.caption,
        badge: 'OFICIAL',
        date_formatted: d.created_at
          ? new Date(d.created_at).toLocaleDateString('es-VE', {
              day: 'numeric',
              month: 'long',
              year: 'numeric',
            })
          : 'Reciente',
      }))
    } else {
      // Usar las noticias oficiales de la SPB scrapeadas
      posts.value = newsInstagramPosts.map((p) => ({
        id: p.id,
        post_url: p.post_url || 'https://www.instagram.com/guaiqueriesbbc/',
        image_url: p.image_url,
        caption: p.title,
        badge: p.badge,
        date_formatted: p.date_formatted,
      }))
    }
  } catch {
    posts.value = newsInstagramPosts.map((p) => ({
      id: p.id,
      post_url: p.post_url || 'https://www.instagram.com/guaiqueriesbbc/',
      image_url: p.image_url,
      caption: p.title,
      badge: p.badge,
      date_formatted: p.date_formatted,
    }))
  }
})

function onImageError(e: Event) {
  const target = e.target as HTMLImageElement
  if (target && !target.src.includes('noticia-spb-1.jpg')) {
    target.src = '/images/noticias/noticia-spb-1.jpg'
  }
}
</script>

<template>
  <section class="py-16 sm:py-20 bg-slate-950 text-white px-4 sm:px-8 border-t border-slate-900">
    <div class="max-w-6xl mx-auto space-y-8">
      <div class="text-center space-y-2">
        <h2 class="font-display font-extrabold text-3xl sm:text-4xl uppercase tracking-tight">
          Noticias de la <span class="text-guaiqui-primary">Tribu</span>
        </h2>
        <p class="text-slate-400 text-xs sm:text-sm max-w-xl mx-auto">
          Coberturas oficiales, resultados de partidos y actualidad de Guaiqueríes de Margarita en la Superliga Profesional de Baloncesto.
        </p>
      </div>

      <!-- Noticias Grid: 3 columnas x 2 filas (diseño idéntico a la captura) -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <NuxtLink
          v-for="post in posts"
          :key="post.id"
          to="/noticias"
          class="group relative rounded-xl overflow-hidden aspect-[16/10] bg-slate-900 border border-slate-800 focus:outline-none focus:ring-2 focus:ring-guaiqui-primary shadow-xl cursor-pointer transition-all duration-300 hover:-translate-y-1 hover:border-slate-700"
        >
          <!-- Imagen de la noticia -->
          <img
            :src="post.image_url"
            :alt="post.caption || 'Noticia Guaiqueríes'"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            referrerpolicy="no-referrer"
            @error="onImageError"
          />

          <!-- Badge superior derecho (naranja como en la captura) -->
          <div class="absolute top-3 right-3 z-10">
            <span class="bg-[#f25c05]/50 text-white text-[10px] font-extrabold uppercase px-2.5 py-1 tracking-wider rounded-sm shadow-md">
              {{ (post as any).badge || 'DESTACADOS' }}
            </span>
          </div>

          <!-- Degradado oscuro inferior con Título y Fecha -->
          <div class="absolute inset-0 bg-gradient-to-t from-black/95 via-black/55 to-transparent flex flex-col justify-end p-4">
            <h3 class="font-display font-bold text-sm sm:text-base text-white uppercase tracking-tight leading-snug line-clamp-2 drop-shadow-md group-hover:text-amber-300 transition-colors">
              {{ post.caption }}
            </h3>
            <span class="text-[11px] text-slate-300 mt-1.5 font-normal tracking-normal drop-shadow">
              {{ (post as any).date_formatted || 'martes, 16 de junio del 2026' }}
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
