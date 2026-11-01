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

    <div v-else class="divide-y divide-guaiqui-border/60 max-h-80 overflow-y-auto -mx-1 pr-1">
      <div
        v-for="u in users"
        :key="u.id"
        class="py-3 flex items-center justify-between gap-3 hover:bg-slate-50 px-2 rounded-lg transition-colors"
      >
        <div class="flex items-center gap-3 min-w-0">
          <img
            v-if="u.avatar_url"
            :src="u.avatar_url"
            :alt="u.display_name"
            class="w-10 h-10 rounded-full object-cover border border-guaiqui-border shrink-0"
          />
          <div
            v-else
            class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-sm shrink-0 uppercase"
          >
            {{ u.display_name.charAt(0) }}
          </div>

          <div class="min-w-0">
            <NuxtLink
              :to="`/u/${u.id}`"
              class="font-semibold text-sm text-guaiqui-text hover:text-guaiqui-primary transition-colors block truncate"
              @click="emit('close')"
            >
              {{ u.display_name }}
            </NuxtLink>
            <p v-if="u.favorite_sport" class="text-xs text-guaiqui-text-muted truncate">
              <i class="bi bi-dribbble text-[10px] mr-1"></i>{{ u.favorite_sport }}
            </p>
          </div>
        </div>

        <NuxtLink :to="`/u/${u.id}`" @click="emit('close')" class="shrink-0">
          <BaseButton variant="outline" size="sm">
            Ver Perfil
          </BaseButton>
        </NuxtLink>
      </div>
    </div>
  </BaseModal>
</template>
