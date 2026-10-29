<script setup lang="ts">
import { computed } from 'vue'
import type { NotificationItem } from '~/stores/notifications'

const props = defineProps<{
  notification: NotificationItem
}>()

const emit = defineEmits<{
  (e: 'click-item', notification: NotificationItem): void
  (e: 'mark-read', id: string): void
}>()

const categoryIcon = computed(() => {
  const type = props.notification.type
  if (type.startsWith('redemption_')) return 'bi-gift-fill text-guaiqui-primary'
  if (type === 'pearls_released') return 'bi-coin text-amber-500'
  if (type === 'pearls_revoked') return 'bi-exclamation-octagon-fill text-rose-600'
  if (type === 'new_trivia') return 'bi-patch-question-fill text-blue-600'
  if (type === 'trivia_expiring') return 'bi-hourglass-split text-amber-500'
  if (type === 'match_day') return 'bi-trophy-fill text-amber-500'
  return 'bi-bell-fill text-guaiqui-text-muted'
})

const formattedDate = computed(() => {
  if (!props.notification.created_at) return ''
  const date = new Date(props.notification.created_at)
  return date.toLocaleString('es-VE', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
})
</script>

<template>
  <div
    class="bg-white border rounded-guaiqui-lg p-4 transition-all duration-150 flex items-start gap-3 cursor-pointer hover:border-guaiqui-primary/40 shadow-guaiqui-sm"
    :class="[notification.read_at ? 'border-guaiqui-border bg-white/70 opacity-90' : 'border-guaiqui-primary/30 bg-guaiqui-primary-soft/30']"
    @click="emit('click-item', notification)"
  >
    <!-- Category Icon -->
    <div class="w-10 h-10 rounded-full bg-guaiqui-surface border border-guaiqui-border flex items-center justify-center shrink-0 text-lg">
      <i :class="['bi', categoryIcon]"></i>
    </div>

    <!-- Details -->
    <div class="flex-1 min-w-0">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0">
          <h4 class="text-sm font-bold text-guaiqui-text truncate">
            {{ notification.title }}
          </h4>
          <span
            v-if="notification.team"
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-guaiqui-surface text-guaiqui-text border border-guaiqui-border shrink-0"
          >
            <img
              v-if="notification.team.logo_url"
              :src="notification.team.logo_url"
              :alt="notification.team.name"
              class="w-3 h-3 rounded-full object-contain"
            />
            <i v-else class="bi bi-shield text-[9px] text-guaiqui-primary"></i>
            <span class="max-w-[100px] truncate">{{ notification.team.name }}</span>
          </span>
        </div>
        <span class="text-[10px] text-guaiqui-text-muted shrink-0">
          {{ formattedDate }}
        </span>
      </div>

      <p class="text-xs text-guaiqui-text-muted mt-1 leading-relaxed">
        {{ notification.body }}
      </p>
    </div>

    <!-- Action indicator -->
    <div class="flex items-center gap-2 shrink-0">
      <button
        v-if="!notification.read_at"
        class="w-3 h-3 rounded-full bg-guaiqui-accent hover:scale-125 transition-transform"
        title="Marcar como leída"
        @click.stop="emit('mark-read', notification.id)"
      ></button>
      <i class="bi bi-chevron-right text-xs text-guaiqui-text-muted"></i>
    </div>
  </div>
</template>
