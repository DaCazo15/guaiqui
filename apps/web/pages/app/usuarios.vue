<script setup lang="ts">
import { ref, watch } from 'vue'
import { BaseCard, BaseInput, BaseButton } from '@guaiqui/ui'
import { useSocialProfile } from '~/composables/useSocialProfile'
import UserSearchCard from '~/components/user/UserSearchCard.vue'

definePageMeta({
  layout: 'app',
  middleware: ['auth'],
})

useSeoMeta({
  title: 'Buscador de FanActivo — FanActivo',
  description: 'Encuentra y sigue a otros fanáticos en la plataforma FanActivo.',
})

const socialProfile = useSocialProfile()
const searchQuery = ref('')
let debounceTimer: ReturnType<typeof setTimeout> | null = null

watch(searchQuery, (newVal) => {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    if (newVal.trim().length >= 2) {
      socialProfile.search(newVal.trim())
    } else {
      socialProfile.searchResults.value = []
    }
  }, 350)
})

async function handleAction(userId: string, currentStatus: string) {
  if (currentStatus === 'none') {
    await socialProfile.sendFollow(userId)
  } else if (currentStatus === 'pending') {
    await socialProfile.cancelFollow(userId)
  } else if (currentStatus === 'accepted') {
    await socialProfile.unfollow(userId)
  }
}
</script>

<template>
  <div class="space-y-6 max-w-4xl mx-auto">
    <!-- Encabezado de la Página -->
    <div class="bg-gradient-to-r from-[#050E12] via-[#071318] to-[#0A1C22] border border-cyan-900/60 text-white p-6 sm:p-8 rounded-guaiqui-2xl shadow-guaiqui-md">
      <div class="flex items-center gap-3 mb-2">
        <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-xl text-white shadow-md">
          <i class="bi bi-people-fill"></i>
        </div>
        <h1 class="font-display font-black text-2xl sm:text-3xl uppercase tracking-wide">
          Buscador de FanActivo
        </h1>
      </div>
      <p class="text-xs sm:text-sm text-slate-300 max-w-xl">
        Busca a otros fanáticos en FanActivo, conéctate con ellos y sigue su actividad de juego y canjes en la plataforma.
      </p>

      <!-- Barra de Búsqueda -->
      <div class="mt-5 relative max-w-lg">
        <div class="relative">
          <i class="bi bi-search absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 text-sm"></i>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar fanáticos por su nombre o usuario en FanActivo..."
            class="w-full pl-9 pr-4 py-2.5 bg-white text-slate-900 rounded-guaiqui-xl text-sm border-0 focus:ring-2 focus:ring-orange-400 shadow-sm placeholder:text-slate-400 font-medium"
          />
        </div>
      </div>
    </div>

    <!-- Mensajes Globales -->
    <div
      v-if="socialProfile.successMessage.value"
      class="p-3.5 bg-emerald-50 border border-emerald-300 rounded-guaiqui-xl text-emerald-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-check-circle-fill text-emerald-600"></i>
        <span>{{ socialProfile.successMessage.value }}</span>
      </div>
      <button @click="socialProfile.clearMessages()" class="text-emerald-700 hover:text-emerald-900 p-1">
        <i class="bi bi-x-lg text-xs"></i>
      </button>
    </div>

    <div
      v-if="socialProfile.error.value"
      class="p-3.5 bg-rose-50 border border-rose-300 rounded-guaiqui-xl text-rose-800 text-sm flex items-center justify-between shadow-xs animate-in fade-in"
    >
      <div class="flex items-center gap-2">
        <i class="bi bi-exclamation-circle-fill text-rose-600"></i>
        <span>{{ socialProfile.error.value }}</span>
      </div>
      <button @click="socialProfile.clearMessages()" class="text-rose-700 hover:text-rose-900 p-1">
        <i class="bi bi-x-lg text-xs"></i>
      </button>
    </div>

    <!-- Resultados de Búsqueda -->
    <BaseCard class="bg-white border-guaiqui-border p-5 rounded-guaiqui-2xl shadow-guaiqui-sm">
      <div class="flex items-center justify-between pb-3 mb-3 border-b border-guaiqui-border">
        <h2 class="font-display font-extrabold text-base text-guaiqui-text uppercase tracking-wide">
          Resultados de Búsqueda
        </h2>
        <span v-if="socialProfile.searchResults.value.length > 0" class="text-xs text-guaiqui-text-muted">
          {{ socialProfile.searchResults.value.length }} encontrado(s)
        </span>
      </div>

      <!-- Cargando -->
      <div v-if="socialProfile.searching.value" class="py-12 text-center text-guaiqui-text-muted">
        <div class="w-7 h-7 border-3 border-guaiqui-primary border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
        <p class="text-xs">Buscando fanáticos...</p>
      </div>

      <!-- Estado Inicial / Texto Corto -->
      <div v-else-if="searchQuery.trim().length < 2" class="py-12 text-center text-guaiqui-text-muted">
        <i class="bi bi-search text-3xl mb-2 text-slate-300 block"></i>
        <p class="text-sm font-semibold text-guaiqui-text">Encuentra a tus amigos</p>
        <p class="text-xs text-guaiqui-text-muted mt-1">Escribe al menos 2 letras para comenzar a buscar.</p>
      </div>

      <!-- Sin Resultados -->
      <div v-else-if="socialProfile.searchResults.value.length === 0" class="py-12 text-center text-guaiqui-text-muted">
        <i class="bi bi-person-x text-3xl mb-2 text-slate-300 block"></i>
        <p class="text-sm font-semibold text-guaiqui-text">No se encontraron fanáticos</p>
        <p class="text-xs text-guaiqui-text-muted mt-1">Intenta buscar con otro nombre o término.</p>
      </div>

      <!-- Cuadrícula de Resultados (UserSearchCard) -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5 sm:gap-4">
        <UserSearchCard
          v-for="u in socialProfile.searchResults.value"
          :key="u.id"
          :user="u"
          :loading="socialProfile.actionLoading.value"
          @action="handleAction"
        />
      </div>
    </BaseCard>
  </div>
</template>
