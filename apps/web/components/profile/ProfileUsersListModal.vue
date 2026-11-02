<script setup lang="ts">
import { BaseModal, BaseButton } from '@guaiqui/ui'
import type { UserFollowUserItem } from '@guaiqui/shared'

defineProps<{
  isOpen: boolean
  title: string
  users: UserFollowUserItem[]
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()
</script>

<template>
  <BaseModal :is-open="isOpen" :title="title" @close="emit('close')">
    <div v-if="loading" class="py-8 flex flex-col items-center justify-center text-guaiqui-text-muted">
      <div class="w-7 h-7 border-3 border-guaiqui-primary border-t-transparent rounded-full animate-spin mb-2"></div>
      <p class="text-xs">Cargando lista...</p>
    </div>

    <div v-else-if="users.length === 0" class="py-8 text-center text-guaiqui-text-muted">
      <i class="bi bi-people text-3xl mb-2 text-slate-300 block"></i>
      <p class="text-sm font-medium">No hay usuarios en esta lista aún.</p>
    </div>

    <div v-else class="space-y-2.5 max-h-88 overflow-y-auto pr-1">
      <div
        v-for="u in users"
        :key="u.id"
        class="p-3 flex items-center justify-between gap-3 bg-white hover:bg-slate-50/80 rounded-2xl border border-slate-200/80 transition-all shadow-2xs group"
      >
        <div class="flex items-center gap-3 min-w-0">
          <NuxtLink :to="`/u/${u.id}`" @click="emit('close')" class="shrink-0">
            <img
              v-if="u.avatar_url"
              :src="u.avatar_url"
              :alt="u.display_name"
              class="w-11 h-11 rounded-xl object-cover border border-slate-200 ring-2 ring-emerald-500/10 group-hover:ring-emerald-500/30 transition-all shadow-2xs"
            />
            <div
              v-else
              class="w-11 h-11 rounded-xl bg-gradient-to-br from-emerald-600 to-teal-700 text-white flex items-center justify-center font-extrabold text-sm shadow-2xs uppercase"
            >
              {{ u.display_name?.charAt(0) || 'F' }}
            </div>
          </NuxtLink>

          <div class="min-w-0">
            <div class="flex items-center gap-1.5">
              <NuxtLink
                :to="`/u/${u.id}`"
                class="font-bold text-sm text-slate-900 group-hover:text-emerald-700 transition-colors block truncate"
                @click="emit('close')"
              >
                {{ u.display_name }}
              </NuxtLink>
              <i class="bi bi-patch-check-fill text-emerald-600 text-xs shrink-0"></i>
            </div>
            <p v-if="u.favorite_sport" class="text-xs text-slate-500 truncate flex items-center gap-1 mt-0.5">
              <i class="bi bi-dribbble text-[10px] text-emerald-600"></i>
              <span>{{ u.favorite_sport }}</span>
            </p>
            <p v-else class="text-[11px] text-slate-400 truncate mt-0.5">
              Fanático de La Tribu
            </p>
          </div>
        </div>

        <NuxtLink
          :to="`/u/${u.id}`"
          @click="emit('close')"
          class="shrink-0 inline-flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 hover:text-slate-900 transition-all select-none cursor-pointer"
        >
          <span>Ver Perfil</span>
          <i class="bi bi-chevron-right text-[10px] text-slate-400"></i>
        </NuxtLink>
      </div>
    </div>
  </BaseModal>
</template>
