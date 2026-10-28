<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useNotificationsStore, type NotificationItem as NotifItemType } from '~/stores/notifications'
import NotificationItem from '~/components/notifications/NotificationItem.vue'

definePageMeta({
  layout: 'app',
  middleware: 'auth',
})

const notifStore = useNotificationsStore()
const router = useRouter()
const activeTab = ref<'all' | 'unread'>('all')

onMounted(() => {
  notifStore.fetchNotifications()
  notifStore.subscribeToRealtime()
})

const filteredNotifications = computed(() => {
  if (activeTab.value === 'unread') {
    return notifStore.notifications.filter((n) => !n.read_at)
  }
  return notifStore.notifications
})

const handleItemClick = async (item: NotifItemType) => {
  if (!item.read_at) {
    await notifStore.markAsRead(item.id)
  }
  if (item.data && item.data.url) {
    router.push(item.data.url)
  }
}

const handleMarkAllRead = async () => {
  await notifStore.markAllAsRead()
}
</script>

<template>
  <div class="space-y-6">
    <!-- Page Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="font-display text-2xl font-bold text-guaiqui-text uppercase tracking-wider flex items-center gap-2">
          <i class="bi bi-bell-fill text-guaiqui-primary"></i>
          <span>Bandeja de Notificaciones</span>
        </h1>
        <p class="text-xs text-guaiqui-text-muted mt-1">
          Historial de avisos sobre tus canjes, trivias y novedades del equipo.
        </p>
      </div>

      <button
        v-if="notifStore.unreadCount > 0"
        class="px-3 py-1.5 bg-guaiqui-surface hover:bg-guaiqui-border border border-guaiqui-border text-guaiqui-text text-xs font-semibold rounded-guaiqui-md transition-colors flex items-center gap-1.5 shrink-0 self-start sm:self-auto"
        @click="handleMarkAllRead"
      >
        <i class="bi bi-check2-all text-sm text-guaiqui-primary"></i>
        <span>Marcar todas como leídas</span>
      </button>
    </div>

    <!-- Filter Tabs -->
    <div class="flex items-center gap-2 border-b border-guaiqui-border pb-3">
      <button
        class="px-4 py-1.5 text-xs font-bold rounded-full transition-colors flex items-center gap-1.5"
        :class="[activeTab === 'all' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text']"
        @click="activeTab = 'all'"
      >
        <span>Todas</span>
        <span class="text-[10px] px-1.5 py-0.5 rounded-full" :class="activeTab === 'all' ? 'bg-white/20 text-white' : 'bg-guaiqui-border text-guaiqui-text'">
          {{ notifStore.notifications.length }}
        </span>
      </button>

      <button
        class="px-4 py-1.5 text-xs font-bold rounded-full transition-colors flex items-center gap-1.5"
        :class="[activeTab === 'unread' ? 'bg-guaiqui-primary text-white shadow-guaiqui-sm' : 'bg-guaiqui-surface text-guaiqui-text-muted hover:text-guaiqui-text']"
        @click="activeTab = 'unread'"
      >
        <span>Sin leer</span>
        <span class="text-[10px] px-1.5 py-0.5 rounded-full" :class="activeTab === 'unread' ? 'bg-white/20 text-white' : 'bg-guaiqui-border text-guaiqui-text'">
          {{ notifStore.unreadCount }}
        </span>
      </button>
    </div>

    <!-- Notifications List -->
    <div v-if="filteredNotifications.length > 0" class="space-y-3">
      <NotificationItem
        v-for="item in filteredNotifications"
        :key="item.id"
        :notification="item"
        @click-item="handleItemClick"
        @mark-read="notifStore.markAsRead"
      />
    </div>

    <!-- Empty State -->
    <div v-else class="bg-white border border-guaiqui-border rounded-guaiqui-lg p-12 text-center shadow-guaiqui-sm">
      <div class="w-16 h-16 rounded-full bg-guaiqui-surface text-guaiqui-text-muted flex items-center justify-center text-3xl mx-auto mb-3">
        <i class="bi bi-bell-slash"></i>
      </div>
      <h3 class="font-display text-base font-bold text-guaiqui-text uppercase">
        No tienes notificaciones
      </h3>
      <p class="text-xs text-guaiqui-text-muted mt-1 max-w-sm mx-auto">
        {{ activeTab === 'unread' ? 'Has leído todas tus notificaciones. ¡Estás al día!' : 'Aquí aparecerán los avisos de tus canjes, trivias y premios.' }}
      </p>
    </div>
  </div>
</template>
