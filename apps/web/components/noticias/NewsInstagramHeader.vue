<script setup lang="ts">
import { officialProfile } from '~/data/newsInstagramData'
</script>

<template>
  <header class="bg-white border-b border-guaiqui-border py-8 px-4 sm:px-8">
    <div class="max-w-4xl mx-auto flex flex-col sm:flex-row items-center sm:items-start gap-6 sm:gap-10">
      <!-- Profile Avatar with Ring -->
      <div class="relative shrink-0">
        <div class="w-24 h-24 sm:w-32 sm:h-32 rounded-full p-1 bg-gradient-to-tr from-amber-500 via-emerald-500 to-guaiqui-primary shadow-md">
          <div class="w-full h-full rounded-full bg-white p-1.5 flex items-center justify-center">
            <img
              :src="officialProfile.avatar"
              :alt="officialProfile.name"
              class="w-full h-full object-contain"
            />
          </div>
        </div>
      </div>

      <!-- Profile Details -->
      <div class="space-y-4 text-center sm:text-left flex-1">
        <div class="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
          <div class="flex items-center justify-center sm:justify-start gap-2">
            <h1 class="font-display font-bold text-2xl sm:text-3xl text-guaiqui-text tracking-tight">
              {{ officialProfile.username }}
            </h1>
            <i class="bi bi-patch-check-fill text-sky-500 text-lg" title="Cuenta Oficial Verificada"></i>
          </div>

          <a
            :href="officialProfile.instagram_url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center justify-center gap-2 px-5 py-2 bg-gradient-to-r from-purple-600 via-pink-600 to-amber-500 hover:opacity-90 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-opacity shadow-sm"
          >
            <i class="bi bi-instagram text-sm"></i>
            <span>Seguir en Instagram</span>
          </a>
        </div>

        <!-- Social Counts -->
        <div class="flex items-center justify-center sm:justify-start gap-6 sm:gap-8 text-sm">
          <div>
            <span class="font-bold text-guaiqui-text">{{ officialProfile.posts_count }}</span>
            <span class="text-guaiqui-text-muted ml-1 text-xs">publicaciones</span>
          </div>
          <div>
            <span class="font-bold text-guaiqui-text">{{ officialProfile.followers }}</span>
            <span class="text-guaiqui-text-muted ml-1 text-xs">seguidores</span>
          </div>
          <div>
            <span class="font-bold text-guaiqui-text">{{ officialProfile.following }}</span>
            <span class="text-guaiqui-text-muted ml-1 text-xs">seguidos</span>
          </div>
        </div>

        <!-- Bio & Tags -->
        <div class="space-y-1">
          <p class="font-display font-bold text-base text-guaiqui-text">
            {{ officialProfile.name }}
          </p>
          <p class="text-xs sm:text-sm text-guaiqui-text-muted leading-relaxed font-sans max-w-xl">
            {{ officialProfile.bio }}
          </p>
        </div>
      </div>
    </div>
  </header>
</template>
