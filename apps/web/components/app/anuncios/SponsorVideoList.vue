<script setup lang="ts">
import { BaseCard, BaseBadge, PearlIcon } from '@guaiqui/ui'
import type { SponsorVideo } from '@guaiqui/shared'

defineProps<{
  videos: SponsorVideo[]
  selectedVideoId: string
  claimedVideoIds: Set<string>
}>()

const emit = defineEmits<{
  (e: 'select', video: SponsorVideo): void
}>()
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-center justify-between">
      <h3 class="font-display font-bold text-base uppercase tracking-wide text-guaiqui-text flex items-center gap-2">
        <i class="bi bi-collection-play text-guaiqui-primary"></i>
        <span>Catálogo de Videos Disponibles ({{ videos.length }})</span>
      </h3>
      <span class="text-xs text-guaiqui-text-muted">
        Selecciona un video para reproducirlo
      </span>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <button
        v-for="video in videos"
        :key="video.id"
        type="button"
        class="text-left p-4 rounded-guaiqui-xl border transition-all cursor-pointer relative overflow-hidden group focus:outline-hidden"
        :class="[
          video.id === selectedVideoId
            ? 'bg-guaiqui-primary-soft/40 border-guaiqui-primary shadow-xs ring-2 ring-guaiqui-primary/30'
            : 'bg-white border-guaiqui-border hover:border-gray-300 hover:shadow-xs'
        ]"
        @click="emit('select', video)"
      >
        <div class="flex items-start gap-3">
          <!-- Icono / Miniatura -->
          <div
            class="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 transition-colors"
            :class="[
              video.id === selectedVideoId
                ? 'bg-guaiqui-primary text-white'
                : 'bg-guaiqui-surface text-guaiqui-text-muted group-hover:bg-guaiqui-primary-soft group-hover:text-guaiqui-primary'
            ]"
          >
            <i class="bi bi-play-circle-fill text-xl"></i>
          </div>

          <div class="space-y-1 min-w-0 flex-1">
            <div class="flex items-center gap-1.5 flex-wrap">
              <span
                v-if="video.sponsor_name"
                class="text-[9px] font-bold uppercase tracking-wider text-guaiqui-primary font-mono truncate max-w-[120px]"
              >
                {{ video.sponsor_name }}
              </span>
              <BaseBadge
                v-if="claimedVideoIds.has(video.id)"
                variant="success"
                size="sm"
                class="text-[9px] py-0 px-1.5"
              >
                <i class="bi bi-check-circle-fill mr-0.5"></i> Reclamado
              </BaseBadge>
              <BaseBadge
                v-else
                variant="soft"
                size="sm"
                class="text-[9px] py-0 px-1.5"
              >
                Disponible
              </BaseBadge>
            </div>

            <h4 class="font-display font-bold text-sm text-guaiqui-text truncate group-hover:text-guaiqui-primary transition-colors">
              {{ video.title }}
            </h4>

            <div class="flex items-center justify-between text-xs pt-1 text-guaiqui-text-muted">
              <span class="flex items-center gap-1">
                <i class="bi bi-stopwatch text-[11px]"></i> {{ video.min_seconds }}s
              </span>
              <span class="font-bold text-emerald-700 flex items-center gap-1 font-mono">
                <PearlIcon size="xs" />
                +{{ video.reward_points }}
              </span>
            </div>
          </div>
        </div>
      </button>
    </div>
  </div>
</template>
