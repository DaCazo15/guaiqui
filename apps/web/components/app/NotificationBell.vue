<script setup lang="ts">
import { onMounted } from 'vue'
import { useNotificationsStore } from '~/stores/notifications'

const notifStore = useNotificationsStore()

onMounted(() => {
  notifStore.fetchNotifications()
  notifStore.subscribeToRealtime()
})
</script>

<template>
  <NuxtLink
    to="/app/notificaciones"
    class="relative p-2 rounded-full text-guaiqui-text-muted hover:text-guaiqui-primary hover:bg-guaiqui-surface transition-colors flex items-center justify-center"
    title="Notificaciones"
  >
    <i class="bi bi-bell text-xl"></i>
    <span
      v-if="notifStore.unreadCount > 0"
      class="absolute top-1 right-1 flex items-center justify-center min-w-4 h-4 px-1 text-[10px] font-bold text-white bg-guaiqui-accent rounded-full border border-white"
    >
      {{ notifStore.unreadCount > 99 ? '99+' : notifStore.unreadCount }}
    </span>
  </NuxtLink>
</template>
