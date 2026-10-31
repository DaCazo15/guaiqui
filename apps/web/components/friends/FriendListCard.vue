<script setup lang="ts">
import { ref, computed } from 'vue'
import { BaseCard, BaseButton, PearlAmount } from '@guaiqui/ui'
import { useFriendships } from '~/composables/useFriendships'

const { friends, removeFriend, responding } = useFriendships()

const searchQuery = ref('')
const confirmingDeleteId = ref<string | null>(null)

const filteredFriends = computed(() => {
  if (!searchQuery.value.trim()) return friends.value
  const q = searchQuery.value.toLowerCase().trim()
  return friends.value.filter(
    (f) =>
      f.display_name.toLowerCase().includes(q) ||
      f.tier_name.toLowerCase().includes(q)
  )
})

function handleDelete(friendshipId: string) {
  confirmingDeleteId.value = friendshipId
}

async function confirmDelete(friendshipId: string) {
  await removeFriend(friendshipId)
  confirmingDeleteId.value = null
}
</script>

<template>
  <BaseCard class="p-5 sm:p-6 bg-white border border-guaiqui-border rounded-guaiqui-xl shadow-guaiqui-sm space-y-5">
    <!-- Header & Search -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-guaiqui-border">
      <div>
        <h2 class="font-display font-extrabold text-lg text-guaiqui-text uppercase tracking-wide flex items-center gap-2">
          <span>Mis Amigos</span>
          <span class="text-xs px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold">
            {{ friends.length }}
          </span>
        </h2>
        <p class="text-xs text-guaiqui-text-muted">
          Tu red de fanáticos amigos en la plataforma.
        </p>
      </div>

      <!-- Search filter -->
      <div v-if="friends.length > 0" class="relative w-full sm:w-64">
        <i class="bi bi-search absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs"></i>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Buscar amigos..."
          class="w-full pl-8 pr-3 py-1.5 bg-gray-50 border border-guaiqui-border rounded-guaiqui-lg text-xs text-guaiqui-text focus:outline-none focus:ring-1 focus:ring-guaiqui-primary focus:bg-white"
        />
      </div>
    </div>

    <!-- Lista de Amigos -->
    <div v-if="filteredFriends.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <div
        v-for="friend in filteredFriends"
        :key="friend.friendship_id"
        class="p-4 bg-gray-50 border border-gray-100 rounded-guaiqui-lg hover:border-gray-200 transition-all flex flex-col justify-between gap-3"
      >
        <div class="flex items-center gap-3">
          <div class="w-11 h-11 rounded-full bg-emerald-900 text-emerald-100 flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-emerald-500/30">
            <img
              v-if="friend.avatar_url"
              :src="friend.avatar_url"
              :alt="friend.display_name"
              class="w-full h-full object-cover"
            />
            <span v-else>{{ friend.display_name.charAt(0).toUpperCase() }}</span>
          </div>
          <div class="truncate flex-1">
            <p class="font-bold text-sm text-guaiqui-text truncate">{{ friend.display_name }}</p>
            <div class="flex items-center gap-2 mt-0.5">
              <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-white border border-gray-200 text-gray-700">
                {{ friend.tier_name }}
              </span>
              <span class="text-[10px] text-guaiqui-text-muted flex items-center gap-1">
                <i class="bi bi-award-fill text-amber-500"></i>
                {{ friend.badges_count }} insignias
              </span>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between pt-2 border-t border-gray-200/60 text-xs">
          <div class="flex items-center gap-1 text-emerald-800 font-bold">
            <PearlAmount :amount="friend.total_pearls" size="xs" />
          </div>

          <!-- Acciones -->
          <div v-if="confirmingDeleteId === friend.friendship_id" class="flex items-center gap-1.5">
            <button
              type="button"
              class="text-[11px] text-rose-600 font-bold px-2 py-0.5 hover:underline"
              :disabled="responding"
              @click="confirmDelete(friend.friendship_id)"
            >
              Confirmar
            </button>
            <button
              type="button"
              class="text-[11px] text-gray-500 px-2 py-0.5 hover:underline"
              @click="confirmingDeleteId = null"
            >
              Cancelar
            </button>
          </div>

          <button
            v-else
            type="button"
            class="text-[11px] text-gray-400 hover:text-rose-600 transition-colors p-1"
            title="Eliminar de amigos"
            @click="handleDelete(friend.friendship_id)"
          >
            <i class="bi bi-person-x"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Estado vacío de búsqueda -->
    <div v-else-if="friends.length > 0" class="py-8 text-center text-xs text-guaiqui-text-muted">
      No se encontraron amigos que coincidan con "{{ searchQuery }}".
    </div>

    <!-- Estado vacío general -->
    <div v-else class="text-center py-10 px-4 bg-gray-50/60 rounded-guaiqui-lg border border-dashed border-gray-200 space-y-3">
      <div class="w-12 h-12 rounded-full bg-emerald-50 text-emerald-600 mx-auto flex items-center justify-center text-xl">
        <i class="bi bi-people"></i>
      </div>
      <div>
        <p class="font-bold text-sm text-guaiqui-text">Aún no tienes amigos en tu lista</p>
        <p class="text-xs text-guaiqui-text-muted max-w-sm mx-auto mt-1">
          Busca fanáticos por su código personal o comparte el tuyo para empezar a comparar puntos y trivias.
        </p>
      </div>
    </div>
  </BaseCard>
</template>
