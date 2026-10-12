<script setup lang="ts">
import type { InstagramNewsPost } from '~/data/newsInstagramData'

defineProps<{
  post: InstagramNewsPost | null
  isLiked?: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'toggle-like', postId: string): void
}>()

function onImageError(e: Event) {
  const target = e.target as HTMLImageElement
  if (target && !target.src.includes('noticia-spb-1.jpg')) {
    target.src = '/images/noticias/noticia-spb-1.jpg'
  }
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="post"
      class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/80 backdrop-blur-sm"
      @click.self="emit('close')"
    >
      <div class="relative w-full max-w-4xl max-h-[90vh] bg-white rounded-2xl shadow-2xl border border-guaiqui-border overflow-hidden flex flex-col md:flex-row">
        <!-- Close Button -->
        <button
          type="button"
          @click="emit('close')"
          class="absolute top-3 right-3 z-20 w-8 h-8 rounded-full bg-slate-900/60 hover:bg-red-600 text-white flex items-center justify-center transition-all cursor-pointer shadow-sm border border-white/20"
          aria-label="Cerrar modal"
        >
          <i class="bi bi-x-lg text-xs font-bold"></i>
        </button>

        <!-- Media Column -->
        <div class="relative w-full md:w-3/5 bg-slate-950 flex items-center justify-center overflow-hidden aspect-[16/10] md:aspect-auto">
          <img
            :src="post.image_url"
            :alt="post.title"
            class="w-full h-full object-cover max-h-[50vh] md:max-h-[90vh]"
            referrerpolicy="no-referrer"
            @error="onImageError"
          />

          <!-- Badge oficial SPB -->
          <div class="absolute top-3 left-3 z-10">
            <span class="bg-[#f25c05] text-white text-[11px] font-extrabold uppercase px-3 py-1 tracking-wider rounded-sm shadow-md">
              {{ post.badge || 'DESTACADOS' }}
            </span>
          </div>
        </div>

        <!-- Post Content Column -->
        <div class="w-full md:w-2/5 p-5 sm:p-6 flex flex-col justify-between overflow-y-auto space-y-4">
          <!-- Author Info -->
          <div class="space-y-4">
            <div class="flex items-center gap-3 pb-3 border-b border-guaiqui-border">
              <div class="w-10 h-10 rounded-full p-0.5 bg-gradient-to-tr from-amber-500 to-guaiqui-primary shrink-0">
                <img :src="post.author.avatar" :alt="post.author.name" class="w-full h-full rounded-full object-contain bg-white p-0.5" />
              </div>
              <div class="truncate">
                <div class="flex items-center gap-1.5">
                  <span class="font-bold text-xs text-guaiqui-text truncate">{{ post.author.username }}</span>
                  <i class="bi bi-patch-check-fill text-sky-500 text-xs shrink-0"></i>
                </div>
                <span class="text-[11px] text-guaiqui-text-muted">{{ post.author.name }}</span>
              </div>
            </div>

            <!-- Title & Caption -->
            <div class="space-y-2">
              <h2 class="font-display font-extrabold text-xl text-guaiqui-text uppercase leading-tight">
                {{ post.title }}
              </h2>
              <p class="text-xs sm:text-sm text-guaiqui-text leading-relaxed whitespace-pre-line">
                {{ post.caption }}
              </p>
            </div>

            <!-- Tags -->
            <div class="flex flex-wrap gap-1.5 pt-1">
              <span
                v-for="tag in post.tags"
                :key="tag"
                class="text-xs font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md"
              >
                {{ tag }}
              </span>
            </div>
          </div>

          <!-- Bottom Actions & Metrics -->
          <div class="pt-3 border-t border-guaiqui-border space-y-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <button
                  type="button"
                  @click="emit('toggle-like', post.id)"
                  class="flex items-center gap-1.5 text-sm font-bold transition-transform active:scale-125 cursor-pointer"
                  :class="isLiked ? 'text-rose-600' : 'text-guaiqui-text hover:text-rose-600'"
                >
                  <i :class="['bi', isLiked ? 'bi-heart-fill' : 'bi-heart', 'text-lg']"></i>
                  <span>{{ (post.likes_count + (isLiked ? 1 : 0)).toLocaleString() }}</span>
                </button>

                <div class="flex items-center gap-1.5 text-sm font-bold text-guaiqui-text-muted">
                  <i class="bi bi-chat-dots text-lg"></i>
                  <span>{{ post.comments_count }}</span>
                </div>
              </div>

              <span class="text-[11px] font-mono text-guaiqui-text-muted">
                {{ post.date_formatted }}
              </span>
            </div>

            <div class="space-y-2">
              <a
                v-if="post.post_url"
                :href="post.post_url"
                target="_blank"
                rel="noopener noreferrer"
                class="w-full py-2 bg-guaiqui-primary hover:bg-guaiqui-primary-dark text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-colors flex items-center justify-center gap-2"
              >
                <i class="bi bi-box-arrow-up-right"></i>
                <span>Leer Crónica Completa en SPB</span>
              </a>

              <a
                href="https://www.instagram.com/guaiqueriesbbc/"
                target="_blank"
                rel="noopener noreferrer"
                class="w-full py-2 bg-gradient-to-r from-purple-600 via-pink-600 to-amber-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-opacity hover:opacity-95 flex items-center justify-center gap-2"
              >
                <i class="bi bi-instagram"></i>
                <span>Ver en Instagram Oficial</span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
