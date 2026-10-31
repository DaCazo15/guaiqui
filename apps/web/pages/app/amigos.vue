<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { BaseCard } from '@guaiqui/ui'
import { useFriendships } from '~/composables/useFriendships'
import FriendListCard from '~/components/friends/FriendListCard.vue'
import FriendRequestsCard from '~/components/friends/FriendRequestsCard.vue'
import FriendAddCard from '~/components/friends/FriendAddCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Mis Amigos y Comunidad — Fan Zone',
  description: 'Conecta con otros fanáticos del baloncesto, comparte códigos, envía solicitudes y compara tus posiciones.',
})

const { fetchFriendships, totalFriends, pendingIncomingCount } = useFriendships()

const activeTab = ref<'friends' | 'requests' | 'add'>('friends')

onMounted(async () => {
  await fetchFriendships()
  if (pendingIncomingCount.value > 0) {
    activeTab.value = 'requests'
  }
})
</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="font-display text-2xl md:text-3xl font-bold text-guaiqui-text uppercase tracking-wider">
          Comunidad de <span class="text-guaiqui-primary">Amigos</span>
        </h1>
        <p class="text-sm text-guaiqui-text-muted mt-1">
          Gestiona tu círculo de amigos, acepta solicitudes y desafía a otros fanáticos.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <NuxtLink to="/app/referidos">
          <button
            type="button"
            class="px-3 py-1.5 rounded-guaiqui-md bg-white border border-guaiqui-border hover:bg-slate-50 text-xs font-bold uppercase tracking-wider text-guaiqui-text transition-colors flex items-center gap-1.5 cursor-pointer shadow-guaiqui-xs"
          >
            <i class="bi bi-gift-fill text-amber-500"></i>
            <span>Programa de Referidos</span>
          </button>
        </NuxtLink>
        <NuxtLink to="/app/ranking">
          <button
            type="button"
            class="px-3 py-1.5 rounded-guaiqui-md bg-white border border-guaiqui-border hover:bg-slate-50 text-xs font-bold uppercase tracking-wider text-guaiqui-text transition-colors flex items-center gap-1.5 cursor-pointer shadow-guaiqui-xs"
          >
            <i class="bi bi-trophy-fill text-guaiqui-primary"></i>
            <span>Ver Ranking</span>
          </button>
        </NuxtLink>
      </div>
    </div>

    <!-- Navigation Tabs -->
    <div class="flex items-center gap-2 border-b border-guaiqui-border pb-2 overflow-x-auto">
      <button
        type="button"
        class="px-4 py-2 rounded-guaiqui-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-2 cursor-pointer"
        :class="activeTab === 'friends' ? 'bg-guaiqui-primary text-white shadow-guaiqui-xs' : 'bg-white text-guaiqui-text hover:bg-slate-50 border border-guaiqui-border'"
        @click="activeTab = 'friends'"
      >
        <i class="bi bi-people-fill"></i>
        <span>Amigos ({{ totalFriends }})</span>
      </button>

      <button
        type="button"
        class="px-4 py-2 rounded-guaiqui-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-2 cursor-pointer"
        :class="activeTab === 'requests' ? 'bg-guaiqui-primary text-white shadow-guaiqui-xs' : 'bg-white text-guaiqui-text hover:bg-slate-50 border border-guaiqui-border'"
        @click="activeTab = 'requests'"
      >
        <i class="bi bi-inbox-fill"></i>
        <span>Solicitudes</span>
        <span
          v-if="pendingIncomingCount > 0"
          class="px-1.5 py-0.2 rounded-full text-[10px] font-black bg-amber-400 text-amber-950"
        >
          {{ pendingIncomingCount }}
        </span>
      </button>

      <button
        type="button"
        class="px-4 py-2 rounded-guaiqui-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-2 cursor-pointer"
        :class="activeTab === 'add' ? 'bg-guaiqui-primary text-white shadow-guaiqui-xs' : 'bg-white text-guaiqui-text hover:bg-slate-50 border border-guaiqui-border'"
        @click="activeTab = 'add'"
      >
        <i class="bi bi-person-plus-fill"></i>
        <span>Agregar Fanático</span>
      </button>
    </div>

    <!-- Tab Contents -->
    <div v-if="activeTab === 'friends'">
      <FriendListCard />
    </div>

    <div v-else-if="activeTab === 'requests'">
      <FriendRequestsCard />
    </div>

    <div v-else-if="activeTab === 'add'">
      <FriendAddCard />
    </div>
  </div>
</template>
