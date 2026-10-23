<script setup lang="ts">
import { onMounted } from 'vue'
import { useNotificationsStore } from '~/stores/notifications'

withDefaults(
  defineProps<{
    variant?: 'default' | 'on-green'
  }>(),
  {
    variant: 'default',
  }
)

const notifStore = useNotificationsStore()

onMounted(() => {
  notifStore.fetchNotifications()
  notifStore.subscribeToRealtime()
})
</script>

<template>
  <NuxtLink
    to="/app/notificaciones"
    class="relative p-2 rounded-full transition-colors flex items-center justify-center"
    :class="[
      variant === 'on-green'
        ? 'text-white hover:text-white hover:bg-white/20'
        : 'text-guaiqui-text-muted hover:text-guaiqui-primary hover:bg-guaiqui-surface'
    ]"
    title="Notificaciones"
  >
    <i class="bi bi-bell text-xl"></i>
    <span
      v-if="notifStore.unreadCount > 0"
      class="absolute top-1 right-1 flex items-center justify-center min-w-4 h-4 px-1 text-[10px] font-bold text-white bg-[#C8102E] rounded-full border border-white shadow-xs"
    >
      {{ notifStore.unreadCount > 99 ? '99+' : notifStore.unreadCount }}
    </span>
  </NuxtLink>
</template>
