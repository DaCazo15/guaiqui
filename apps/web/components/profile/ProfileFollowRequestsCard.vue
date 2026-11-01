<script setup lang="ts">
import { BaseCard, BaseButton } from '@guaiqui/ui'
import type { FollowRequestItem } from '@guaiqui/shared'

defineProps<{
  requests: FollowRequestItem[]
  loading?: boolean
  actionLoading?: boolean
}>()

const emit = defineEmits<{
  (e: 'respond', payload: { followerId: string; accept: boolean }): void
}>()
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
    <div class="flex items-center justify-between pb-3 mb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-sm">
          <i class="bi bi-person-plus-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Solicitudes de Seguimiento
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Gestiona los fanáticos que quieren seguirte y ver tus estadísticas.
          </p>
        </div>
      </div>
      <span
        v-if="requests.length > 0"
        class="bg-emerald-600 text-white text-xs font-bold px-2 py-0.5 rounded-full"
      >
        {{ requests.length }}
      </span>
    </div>

    <div v-if="loading" class="py-6 flex items-center justify-center text-guaiqui-text-muted">
      <div class="w-6 h-6 border-2 border-guaiqui-primary border-t-transparent rounded-full animate-spin mr-2"></div>
      <span class="text-xs">Cargando solicitudes...</span>
    </div>

    <div v-else-if="requests.length === 0" class="py-6 text-center text-guaiqui-text-muted">
      <i class="bi bi-inbox text-2xl mb-1 text-slate-300 block"></i>
      <p class="text-xs font-medium">No tienes solicitudes de seguimiento pendientes.</p>
    </div>

    <div v-else class="divide-y divide-guaiqui-border/60">
      <div
        v-for="req in requests"
        :key="req.follower_id"
        class="py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
      >
        <div class="flex items-center gap-3 min-w-0">
          <img
            v-if="req.avatar_url"
            :src="req.avatar_url"
            :alt="req.display_name"
            class="w-10 h-10 rounded-full object-cover border border-guaiqui-border shrink-0"
          />
          <div
            v-else
            class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-800 flex items-center justify-center font-bold text-sm shrink-0 uppercase"
          >
            {{ req.display_name.charAt(0) }}
          </div>

          <div class="min-w-0">
            <NuxtLink
              :to="`/u/${req.follower_id}`"
              class="font-semibold text-sm text-guaiqui-text hover:text-guaiqui-primary transition-colors block truncate"
            >
              {{ req.display_name }}
            </NuxtLink>
            <p v-if="req.favorite_sport" class="text-xs text-guaiqui-text-muted truncate">
              <i class="bi bi-dribbble text-[10px] mr-1"></i>{{ req.favorite_sport }}
            </p>
          </div>
        </div>

        <div class="flex items-center gap-2 shrink-0 self-end sm:self-center">
          <BaseButton
            variant="primary"
            size="sm"
            :disabled="actionLoading"
            @click="emit('respond', { followerId: req.follower_id, accept: true })"
          >
            <i class="bi bi-check-lg mr-1"></i>
            Aceptar
          </BaseButton>
          <BaseButton
            variant="outline"
            size="sm"
            :disabled="actionLoading"
            @click="emit('respond', { followerId: req.follower_id, accept: false })"
          >
            <i class="bi bi-x-lg mr-1"></i>
            Rechazar
          </BaseButton>
        </div>
      </div>
    </div>
  </BaseCard>
</template>
