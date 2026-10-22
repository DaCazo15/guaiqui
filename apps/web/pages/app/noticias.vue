<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { BaseCard, BaseButton } from '@guaiqui/ui'
import { newsInstagramPosts, type InstagramNewsPost } from '~/data/newsInstagramData'
import { useSupabaseClient } from '#imports'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Noticias y Feed de la Tribu — Guaiqueríes de Margarita',
  description: 'Actualidad oficial, partidos, coberturas de playoffs y anuncios del equipo en formato social.',
})

const supabase = useSupabaseClient()
const dbPosts = ref<InstagramNewsPost[]>([])
const activeFilter = ref<'all' | 'playoffs' | 'roster' | 'clasico' | 'community'>('all')
const likedPosts = ref<Record<string, boolean>>({})
const savedPosts = ref<Record<string, boolean>>({})
const expandedCaptions = ref<Record<string, boolean>>({})
const shareFeedback = ref<string | null>(null)

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
        likes_count: 1540 + idx * 160,
        comments_count: 88 + idx * 12,
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

function toggleLike(id: string) {
  likedPosts.value[id] = !likedPosts.value[id]
}

function toggleSave(id: string) {
  savedPosts.value[id] = !savedPosts.value[id]
}

function toggleCaption(id: string) {
  expandedCaptions.value[id] = !expandedCaptions.value[id]
}

async function sharePost(post: InstagramNewsPost) {
  if (typeof navigator !== 'undefined' && navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(`https://www.instagram.com/guaiqueriesbbc/`)
      shareFeedback.value = '¡Enlace copiado al portapapeles!'
      setTimeout(() => {
        shareFeedback.value = null
      }, 2500)
    } catch {
      // Graceful fallback
    }
  }
}

function onImageError(e: Event) {
  const target = e.target as HTMLImageElement
  if (target && !target.src.includes('noticia-spb-1.jpg')) {
    target.src = '/images/noticias/noticia-spb-1.jpg'
  }
}
</script>

<template>
  <div class="space-y-6 max-w-2xl mx-auto">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-guaiqui-border pb-4">
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="text-xs font-mono font-bold uppercase tracking-wider text-guaiqui-primary bg-guaiqui-primary-soft px-2.5 py-0.5 rounded-full border border-guaiqui-primary/20">
            Feed Oficial
          </span>
        </div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Noticias de la <span class="text-guaiqui-primary">Tribu</span>
        </h1>
        <p class="text-xs sm:text-sm text-guaiqui-text-muted">
          La actualidad de Guaiqueríes de Margarita directamente desde la cancha y redes oficiales.
        </p>
      </div>

      <NuxtLink to="/app/trivias" class="shrink-0">
        <BaseButton variant="primary" size="sm">
          <i class="bi bi-patch-question-fill mr-1.5"></i>
          <span>Trivia de Hoy</span>
        </BaseButton>
      </NuxtLink>
    </div>

    <!-- Category Filters -->
    <div class="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
      <button
        type="button"
        @click="activeFilter = 'all'"
        :class="[
          'px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap cursor-pointer',
          activeFilter === 'all'
            ? 'bg-guaiqui-primary text-white shadow-xs'
            : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
        ]"
      >
        Todas
      </button>
      <button
        type="button"
        @click="activeFilter = 'playoffs'"
        :class="[
          'px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap cursor-pointer',
          activeFilter === 'playoffs'
            ? 'bg-guaiqui-primary text-white shadow-xs'
            : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
        ]"
      >
        Playoffs
      </button>
      <button
        type="button"
        @click="activeFilter = 'clasico'"
        :class="[
          'px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap cursor-pointer',
          activeFilter === 'clasico'
            ? 'bg-guaiqui-primary text-white shadow-xs'
            : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
        ]"
      >
        Clásico Oriental
      </button>
      <button
        type="button"
        @click="activeFilter = 'roster'"
        :class="[
          'px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap cursor-pointer',
          activeFilter === 'roster'
            ? 'bg-guaiqui-primary text-white shadow-xs'
            : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
        ]"
      >
        Fichajes
      </button>
      <button
        type="button"
        @click="activeFilter = 'community'"
        :class="[
          'px-3.5 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap cursor-pointer',
          activeFilter === 'community'
            ? 'bg-guaiqui-primary text-white shadow-xs'
            : 'bg-white text-guaiqui-text-muted border border-guaiqui-border hover:text-guaiqui-text'
        ]"
      >
        Comunidad
      </button>
    </div>

    <!-- Share Toast Alert -->
    <div
      v-if="shareFeedback"
      class="p-3 bg-emerald-500 text-white rounded-xl text-xs font-bold text-center shadow-lg transition-all"
    >
      {{ shareFeedback }}
    </div>

    <!-- Feed List -->
    <div class="space-y-6">
      <BaseCard
        v-for="post in filteredPosts"
        :key="post.id"
        class="p-0 overflow-hidden bg-white border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm"
      >
        <!-- Author Top Bar -->
        <div class="p-3.5 flex items-center justify-between border-b border-guaiqui-border">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-full p-0.5 bg-gradient-to-tr from-amber-500 to-guaiqui-primary shrink-0">
              <img
                :src="post.author.avatar"
                :alt="post.author.name"
                class="w-full h-full rounded-full object-contain bg-white p-0.5"
              />
            </div>
            <div>
              <div class="flex items-center gap-1.5">
                <span class="font-bold text-xs text-guaiqui-text">{{ post.author.username }}</span>
                <i class="bi bi-patch-check-fill text-sky-500 text-xs"></i>
              </div>
              <span class="text-[10px] text-guaiqui-text-muted">{{ post.date_formatted }}</span>
            </div>
          </div>

          <a
            :href="post.post_url || 'https://www.instagram.com/guaiqueriesbbc/'"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-guaiqui-primary hover:text-guaiqui-primary-dark font-bold flex items-center gap-1"
          >
            <i class="bi bi-instagram"></i>
            <span class="hidden sm:inline">Ver Post</span>
          </a>
        </div>

        <!-- Post Image (Aspect 16:10 como en la captura) -->
        <div class="relative aspect-[16/10] w-full bg-slate-950 overflow-hidden">
          <img
            :src="post.image_url"
            :alt="post.title"
            class="w-full h-full object-cover"
            loading="lazy"
            referrerpolicy="no-referrer"
            @error="onImageError"
          />

          <!-- Badge naranja de categoría oficial SPB -->
          <div class="absolute top-3 right-3 z-10">
            <span class="bg-[#f25c05] text-white text-[10px] font-extrabold uppercase px-2.5 py-1 tracking-wider rounded-sm shadow-md">
              {{ post.badge }}
            </span>
          </div>
        </div>

        <!-- Action Icons Bar -->
        <div class="p-4 space-y-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <!-- Like Button -->
              <button
                type="button"
                @click="toggleLike(post.id)"
                class="flex items-center gap-1.5 text-base font-bold transition-transform active:scale-125 cursor-pointer"
                :class="likedPosts[post.id] ? 'text-rose-600' : 'text-guaiqui-text hover:text-rose-600'"
              >
                <i :class="['bi', likedPosts[post.id] ? 'bi-heart-fill' : 'bi-heart', 'text-xl']"></i>
              </button>

              <!-- <button
                type="button"
                @click="toggleCaption(post.id)"
                class="text-guaiqui-text hover:text-guaiqui-primary text-xl cursor-pointer"
                title="Comentarios"
              >
                <i class="bi bi-chat"></i>
              </button> -->

              <!-- Share Button -->
              <button
                type="button"
                @click="sharePost(post)"
                class="text-guaiqui-text hover:text-guaiqui-primary text-xl cursor-pointer"
                title="Compartir"
              >
                <i class="bi bi-send"></i>
              </button>
            </div>

            <!-- Save Bookmark Button -->
            <button
              type="button"
              @click="toggleSave(post.id)"
              class="cursor-pointer text-xl transition-colors"
              :class="savedPosts[post.id] ? 'text-guaiqui-primary' : 'text-guaiqui-text hover:text-guaiqui-primary'"
            >
              <i :class="['bi', savedPosts[post.id] ? 'bi-bookmark-fill' : 'bi-bookmark']"></i>
            </button>
          </div>

          <!-- Likes Count -->
          <div>
            <span class="text-xs font-bold text-guaiqui-text">
              {{ (post.likes_count + (likedPosts[post.id] ? 1 : 0)).toLocaleString() }} me gusta
            </span>
          </div>

          <!-- Caption & Title -->
          <div class="space-y-1 text-xs sm:text-sm text-guaiqui-text leading-relaxed">
            <p class="font-display font-bold text-base text-guaiqui-text uppercase">
              {{ post.title }}
            </p>
            <p :class="[!expandedCaptions[post.id] && 'line-clamp-2']">
              <span class="font-bold mr-1">{{ post.author.username }}</span>
              <span>{{ post.caption }}</span>
            </p>
            <button
              type="button"
              @click="toggleCaption(post.id)"
              class="text-xs text-guaiqui-text-muted hover:text-guaiqui-text font-semibold cursor-pointer block"
            >
              {{ expandedCaptions[post.id] ? 'Ver menos' : 'más' }}
            </button>
          </div>

          <!-- Hashtags -->
          <div class="flex flex-wrap gap-1.5 pt-1">
            <span
              v-for="tag in post.tags"
              :key="tag"
              class="text-[11px] font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md"
            >
              {{ tag }}
            </span>
          </div>
        </div>
      </BaseCard>
    </div>

    <!-- Trivias Promo Banner -->
    <BaseCard class="bg-gradient-to-r from-guaiqui-primary to-emerald-900 text-white p-5 rounded-guaiqui-xl shadow-guaiqui-md flex flex-col sm:flex-row items-center justify-between gap-4">
      <div class="flex items-center gap-3">
        <div class="w-11 h-11 rounded-xl bg-white/10 flex items-center justify-center text-2xl text-amber-300 shrink-0">
          <i class="bi bi-patch-question-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-bold text-base uppercase">¿Sigues la actualidad de la Tribu?</h2>
          <p class="text-xs text-emerald-100">Juega las trivias diarias y gana puntos para la tienda oficial.</p>
        </div>
      </div>
      <NuxtLink to="/app/trivias" class="shrink-0 w-full sm:w-auto">
        <BaseButton variant="secondary" size="sm" block>
          <span>Jugar Trivia</span>
          <i class="bi bi-arrow-right ml-1.5"></i>
        </BaseButton>
      </NuxtLink>
    </BaseCard>
  </div>
</template>
