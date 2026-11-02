<script setup lang="ts">
import { BaseCard } from '@guaiqui/ui'
import type { UserFollowUserItem } from '@guaiqui/shared'

defineProps<{
  title: string
  subtitle: string
  users: UserFollowUserItem[]
  loading?: boolean
  emptyMessage?: string
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
    <!-- Encabezado de la Sección -->
    <div class="flex items-center justify-between pb-3.5 mb-3.5 border-b border-guaiqui-border/80">
      <div>
        <div class="flex items-center gap-2">
          <h2 class="font-display font-black text-base text-guaiqui-text uppercase tracking-wide leading-tight">
            {{ title }}
          </h2>
          <span
            v-if="users && users.length > 0"
            class="bg-emerald-50 text-emerald-800 border border-emerald-200/80 text-xs font-extrabold px-2 py-0.5 rounded-full"
          >
            {{ users.length }}
          </span>
        </div>
        <p class="text-xs text-guaiqui-text-muted mt-0.5">
          {{ subtitle }}
        </p>
      </div>

      <button
        type="button"
        @click="emit('close')"
        class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-slate-500 hover:text-slate-800 bg-slate-100 hover:bg-slate-200/80 rounded-lg transition-colors cursor-pointer"
        title="Cerrar y volver al perfil"
      >
        <span>Volver</span>
        <i class="bi bi-x-lg text-[10px]"></i>
      </button>
    </div>

    <!-- Estado de Carga -->
    <div v-if="loading" class="py-10 text-center text-guaiqui-text-muted">
      <div class="w-8 h-8 border-3 border-guaiqui-primary border-t-transparent rounded-full animate-spin mx-auto mb-2.5"></div>
      <p class="text-xs font-medium">Cargando lista...</p>
    </div>

    <!-- Estado Vacío -->
    <div v-else-if="!users || users.length === 0" class="py-8 text-center text-guaiqui-text-muted">
      <div class="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center text-xl mx-auto mb-2">
        <i class="bi bi-people"></i>
      </div>
      <p class="text-xs font-semibold text-guaiqui-text">{{ emptyMessage || 'No hay usuarios en esta lista aún.' }}</p>
    </div>

    <!-- Grid de Usuarios -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
      <NuxtLink
        v-for="u in users"
        :key="u.id"
        :to="`/u/${u.id}`"
        class="p-3 flex items-center justify-between gap-3 bg-white hover:bg-emerald-50/40 rounded-guaiqui-xl border border-guaiqui-border/80 hover:border-emerald-500/40 transition-all shadow-2xs group"
      >
        <div class="flex items-center gap-3 min-w-0">
          <img
            v-if="u.avatar_url"
            :src="u.avatar_url"
            :alt="u.display_name"
            class="w-10 h-10 rounded-full object-cover border border-slate-200 shrink-0 shadow-2xs"
          />
          <div
            v-else
            class="w-10 h-10 rounded-full bg-gradient-to-br from-emerald-600 to-teal-700 text-white flex items-center justify-center font-extrabold text-sm shrink-0 uppercase shadow-2xs"
          >
            {{ u.display_name?.charAt(0) || 'F' }}
          </div>

          <div class="min-w-0">
            <span class="font-display font-bold text-sm text-guaiqui-text group-hover:text-guaiqui-primary transition-colors block truncate">
              {{ u.display_name }}
            </span>
            <span v-if="u.favorite_sport" class="text-[11px] text-guaiqui-text-muted flex items-center gap-1 truncate">
              <i class="bi bi-dribbble text-[10px] text-guaiqui-primary"></i>
              <span>{{ u.favorite_sport }}</span>
            </span>
            <span v-else class="text-[11px] text-guaiqui-text-muted block truncate">Fanático</span>
          </div>
        </div>

        <i class="bi bi-chevron-right text-xs text-slate-300 group-hover:text-guaiqui-primary group-hover:translate-x-0.5 transition-all shrink-0"></i>
      </NuxtLink>
    </div>
  </BaseCard>
</template>
