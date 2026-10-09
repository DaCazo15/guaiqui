<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard, BaseBadge } from '@guaiqui/ui'
import { useSupabaseClient } from '#imports'

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
      // Fallback sample data if empty
      posts.value = [
        { id: '1', post_url: 'https://www.instagram.com/p/C12345/', image_url: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop', caption: '¡Victoria de la Tribu en La Asunción!' },
        { id: '2', post_url: 'https://www.instagram.com/p/C67890/', image_url: 'https://images.unsplash.com/photo-1519861531473-9200262188bf?w=600&auto=format&fit=crop', caption: 'Entrenamiento matutino oficial 💪' },
        { id: '3', post_url: 'https://www.instagram.com/p/C99999/', image_url: 'https://images.unsplash.com/photo-1504450758481-7338eba7524a?w=600&auto=format&fit=crop', caption: 'Fanáticos encendiendo las gradas 🔥' },
        { id: '4', post_url: 'https://www.instagram.com/p/C88888/', image_url: 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&auto=format&fit=crop', caption: 'Nuestra mascota oficial celebrando 🏀' }
      ]
    }
  } catch (err) {
    // Graceful fallback
  }
})
</script>

<template>
  <section class="py-16 sm:py-20 bg-slate-950 text-white px-4 sm:px-8 border-t border-slate-900">
    <div class="max-w-6xl mx-auto space-y-8">
      <div class="text-center space-y-2">
        <span class="text-xs uppercase font-bold text-pink-400 tracking-widest bg-pink-950/60 border border-pink-800/60 px-3 py-1 rounded-full inline-flex items-center gap-1.5">
          <i class="bi bi-instagram"></i> @GuaiqueriesOficial
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
        <a
          v-for="post in posts"
          :key="post.id"
          :href="post.post_url"
          target="_blank"
          rel="noopener noreferrer"
          class="group relative rounded-2xl overflow-hidden aspect-square bg-slate-900 border border-slate-800 focus:outline-none focus:ring-2 focus:ring-pink-500 shadow-lg"
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
        </a>
      </div>
    </div>
  </section>
</template>
