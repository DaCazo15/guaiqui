<script setup lang="ts">
import { BaseBadge, BaseButton, EmptyState } from '@guaiqui/ui'
import type { LandingCta } from '@guaiqui/shared'

defineProps<{
  items: LandingCta[]
  loading: boolean
  actionLoadingId: string | null
}>()

const emit = defineEmits<{
  (e: 'activate', item: LandingCta): void
  (e: 'edit', item: LandingCta): void
  (e: 'delete', item: LandingCta): void
}>()
</script>

<template>
  <div class="space-y-4">
    <!-- Empty State -->
    <EmptyState
      v-if="!loading && items.length === 0"
      title="No hay llamados a la acción creados"
      description="Crea tu primer CTA para destacar en la landing page pública."
      icon="bi-megaphone"
    />

    <!-- CTAs Cards List -->
    <div v-else class="grid grid-cols-1 gap-4">
      <div
        v-for="cta in items"
        :key="cta.id"
        :class="[
          'p-5 rounded-2xl border transition-all duration-200 flex flex-col md:flex-row md:items-center justify-between gap-4',
          cta.is_active
            ? 'bg-slate-900/90 border-emerald-500/80 shadow-lg shadow-emerald-950/40 ring-1 ring-emerald-500/30'
            : 'bg-slate-900/50 border-slate-800 hover:border-slate-700'
        ]"
      >
        <!-- Info Column -->
        <div class="space-y-2 flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-bold text-white text-base truncate">
              {{ cta.name }}
            </span>

            <!-- Placement Badge -->
            <span
              :class="[
                'text-[11px] font-semibold px-2.5 py-0.5 rounded-full border inline-flex items-center gap-1',
                cta.placement === 'after_hero'
                  ? 'bg-amber-950/60 border-amber-800/80 text-amber-300'
                  : 'bg-slate-800 border-slate-700 text-slate-300'
              ]"
            >
              <i :class="cta.placement === 'after_hero' ? 'bi-arrow-up-circle-fill' : 'bi-arrow-down-circle-fill'"></i>
              {{ cta.placement === 'after_hero' ? 'Después del Hero' : 'Antes del Footer' }}
            </span>

            <!-- Type badge -->
            <span
              :class="[
                'text-[11px] font-semibold uppercase px-2.5 py-0.5 rounded-full border',
                cta.type === 'container'
                  ? 'bg-emerald-950/60 border-emerald-800/80 text-emerald-300'
                  : 'bg-indigo-950/60 border-indigo-800/80 text-indigo-300'
              ]"
            >
              <i :class="cta.type === 'container' ? 'bi-card-heading' : 'bi-chat-square-quote'" class="mr-1"></i>
              {{ cta.type === 'container' ? 'Contenedor Completo' : 'Solo Frase' }}
            </span>

            <!-- Active badge -->
            <span
              v-if="cta.is_active"
              class="inline-flex items-center gap-1 text-[11px] font-bold uppercase px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 animate-pulse"
            >
              <i class="bi bi-broadcast"></i> Activo en Landing
            </span>
          </div>

          <!-- Content summary -->
          <div class="text-xs text-slate-400">
            <template v-if="cta.type === 'container'">
              <p class="text-slate-200 font-medium line-clamp-1">
                "{{ cta.heading }}"
              </p>
              <p class="text-slate-400 line-clamp-1 text-[11px] mt-0.5">
                Botón: <span class="text-emerald-400 font-medium">{{ cta.button_text }}</span> ({{ cta.button_url }})
              </p>
            </template>
            <template v-else>
              <p class="text-slate-200 font-medium line-clamp-1" :style="{ fontFamily: cta.font_family || 'sans-serif' }">
                "{{ cta.phrase_text }}"
              </p>
              <p class="text-slate-400 text-[11px] mt-0.5 flex items-center gap-2 flex-wrap">
                <span>Fuente: <strong class="text-slate-300">{{ cta.font_family }}</strong></span>
                <span>•</span>
                <span>Interletrado: <strong class="text-slate-300">{{ cta.letter_spacing }}</strong></span>
                <span>•</span>
                <span>Multimedia: <strong class="text-slate-300">{{ cta.media_type }}</strong></span>
              </p>
            </template>

            <!-- Background style indicator -->
            <div class="flex items-center gap-1.5 mt-1 text-[11px] text-slate-500">
              <span
                class="w-3 h-3 rounded-full border border-slate-600 inline-block"
                :style="{ backgroundColor: cta.bg_color || '#064E27' }"
              ></span>
              <span>Fondo: {{ cta.bg_color || 'Gradiente Oficial' }}</span>
            </div>
          </div>
        </div>

        <!-- Controls / Actions Column -->
        <div class="flex items-center gap-2 pt-2 md:pt-0 border-t md:border-t-0 border-slate-800 shrink-0">
          <!-- Active Toggle Button -->
          <BaseButton
            :variant="cta.is_active ? 'primary' : 'secondary'"
            size="sm"
            :loading="actionLoadingId === cta.id"
            @click="emit('activate', cta)"
          >
            <i :class="cta.is_active ? 'bi-check2-circle' : 'bi-power'" class="mr-1"></i>
            {{ cta.is_active ? 'Activo' : 'Hacer Activo' }}
          </BaseButton>

          <!-- Edit Button -->
          <BaseButton
            variant="secondary"
            size="sm"
            @click="emit('edit', cta)"
          >
            <i class="bi bi-pencil mr-1"></i>
            Editar
          </BaseButton>

          <!-- Delete Button -->
          <button
            type="button"
            title="Eliminar CTA"
            class="w-8 h-8 rounded-lg flex items-center justify-center text-slate-400 hover:text-red-400 hover:bg-red-950/40 border border-slate-800 transition-colors"
            @click="emit('delete', cta)"
          >
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
