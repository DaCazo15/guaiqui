<script setup lang="ts">
import { BaseCard, BaseButton } from '@guaiqui/ui'
import type { BlockedUserItem } from '@guaiqui/shared'

defineProps<{
  blockedUsers: BlockedUserItem[]
  loading?: boolean
  actionLoading?: boolean
}>()

const emit = defineEmits<{
  (e: 'unblock', userId: string): void
}>()
</script>

<template>
  <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
    <div class="flex items-center justify-between pb-3 mb-3 border-b border-guaiqui-border">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full bg-slate-100 text-slate-700 flex items-center justify-center font-bold text-sm">
          <i class="bi bi-shield-slash-fill"></i>
        </div>
        <div>
          <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
            Usuarios Bloqueados
          </h2>
          <p class="text-xs text-guaiqui-text-muted">
            Los usuarios bloqueados no pueden encontrarte en búsquedas ni interactuar contigo.
          </p>
        </div>
      </div>
      <span
        v-if="blockedUsers.length > 0"
        class="bg-slate-200 text-slate-700 text-xs font-bold px-2 py-0.5 rounded-full"
      >
        {{ blockedUsers.length }}
      </span>
    </div>

    <div v-if="loading" class="py-6 flex items-center justify-center text-guaiqui-text-muted">
      <div class="w-6 h-6 border-2 border-guaiqui-primary border-t-transparent rounded-full animate-spin mr-2"></div>
      <span class="text-xs">Cargando usuarios bloqueados...</span>
    </div>

    <div v-else-if="blockedUsers.length === 0" class="py-6 text-center text-guaiqui-text-muted">
      <i class="bi bi-person-check text-2xl mb-1 text-slate-300 block"></i>
      <p class="text-xs font-medium">No tienes usuarios bloqueados.</p>
    </div>

    <div v-else class="divide-y divide-guaiqui-border/60">
      <div
        v-for="b in blockedUsers"
        :key="b.id"
        class="py-3 flex items-center justify-between gap-3"
      >
        <div class="flex items-center gap-3 min-w-0">
          <img
            v-if="b.avatar_url"
            :src="b.avatar_url"
            :alt="b.display_name"
            class="w-9 h-9 rounded-full object-cover border border-guaiqui-border shrink-0"
          />
          <div
            v-else
            class="w-9 h-9 rounded-full bg-slate-100 text-slate-700 flex items-center justify-center font-bold text-sm shrink-0 uppercase"
          >
            {{ b.display_name.charAt(0) }}
          </div>

          <div class="min-w-0">
            <span class="font-semibold text-sm text-guaiqui-text block truncate">
              {{ b.display_name }}
            </span>
            <span class="text-[11px] text-guaiqui-text-muted">
              Bloqueado el {{ new Date(b.blocked_at).toLocaleDateString('es-VE') }}
            </span>
          </div>
        </div>

        <BaseButton
          variant="outline"
          size="sm"
          :disabled="actionLoading"
          @click="emit('unblock', b.id)"
        >
          <i class="bi bi-unlock mr-1"></i>
          Desbloquear
        </BaseButton>
      </div>
    </div>
  </BaseCard>
</template>
