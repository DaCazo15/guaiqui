<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

const currentBalance = computed(() => {
  return authStore.wallet?.balance_cache ?? 0
})

import { APP_SIDEBAR_NAV_ITEMS, type AppNavItem } from '~/data/appNavData'
import { useCurrentTeam } from '~/composables/useCurrentTeam'

const navItems = APP_SIDEBAR_NAV_ITEMS
const { openPicker } = useCurrentTeam()

const handleNavClick = (e: MouseEvent, item: AppNavItem) => {
  if (item.name === 'Trivias') {
    e.preventDefault()
    openPicker('trivias')
  } else if (item.name === 'Tienda') {
    e.preventDefault()
    openPicker('tienda')
  }
}

const isItemActive = (item: AppNavItem) => {
  if (route.name === item.routeName || route.path === item.path) return true
  if (item.name === 'Trivias' && route.path.includes('/trivias')) return true
  if (item.name === 'Tienda' && route.path.includes('/tienda')) return true
  return false
}

const handleLogout = async () => {
  await authStore.logout()
}
</script>

<template>
  <aside class="hidden lg:flex flex-col w-64 bg-gradient-to-b from-[#050e12] via-[#071318] to-[#0a1c22] border-r border-cyan-950/80 min-h-screen p-4 sticky top-0 h-screen text-white select-none shadow-2xl">
    <!-- Brand Logo: FanActivo -->
    <NuxtLink
      to="/"
      class="flex items-center gap-2.5 px-3 py-3 mb-4 border-b border-cyan-950/80 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-500 rounded-xl transition-all"
    >
      <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center text-white shadow-md shadow-orange-500/25 shrink-0 group-hover:scale-105 transition-transform">
        <i class="bi bi-fire text-xl"></i>
      </div>
      <div>
        <div class="flex items-baseline gap-1">
          <span class="font-title font-black text-lg text-white tracking-wider leading-tight">FAN</span>
          <span class="font-title font-black text-lg text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-amber-400 tracking-wider leading-tight">ACTIVO</span>
        </div>
        <span class="text-[10px] text-cyan-400 font-bold tracking-widest uppercase block leading-none">
          Fan Zone
        </span>
      </div>
    </NuxtLink>

    <!-- User Mini Card: Avatar & Points Only (Reactive) -->
    <NuxtLink
      :to="{ name: 'app-perfil' }"
      class="bg-[#0c1e24] hover:bg-[#10272f] border border-cyan-900/60 hover:border-cyan-700/80 rounded-2xl p-2.5 mb-5 flex items-center justify-between shadow-lg backdrop-blur-md transition-all group cursor-pointer"
      title="Ver mi perfil"
    >
      <!-- Foto del perfil -->
      <div class="w-9 h-9 rounded-full bg-cyan-950 text-cyan-300 flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border-2 border-orange-500/80 ring-2 ring-cyan-500/20 shadow-sm group-hover:scale-105 transition-transform">
        <img
          v-if="authStore.profile?.avatar_url && !avatarError"
          :src="authStore.profile.avatar_url"
          :alt="authStore.profile?.display_name || 'Avatar'"
          class="w-full h-full object-cover"
          referrerpolicy="no-referrer"
          @error="avatarError = true"
        />
        <span v-else>
          {{ authStore.profile?.display_name?.charAt(0).toUpperCase() || 'F' }}
        </span>
      </div>

      <!-- Cantidad de puntos reactivos -->
      <div class="flex items-center gap-1.5 text-xs font-black text-amber-950 bg-gradient-to-r from-amber-300 to-yellow-400 border border-amber-400/80 px-2.5 py-1 rounded-full shadow-xs shrink-0 group-hover:brightness-105 transition-all">
        <PearlIcon size="xs" animated />
        <span class="tabular-nums">{{ formatPerlitas(currentBalance) }}</span>
      </div>
    </NuxtLink>

    <!-- Nav Links -->
    <nav class="flex-1 space-y-1 overflow-y-auto pr-1">
      <NuxtLink
        v-for="item in navItems"
        :key="item.routeName"
        :to="{ name: item.routeName }"
        @click="handleNavClick($event, item)"
        class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
        :class="[
          isItemActive(item)
            ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-white font-black shadow-lg shadow-orange-950/40 scale-[1.01]'
            : 'text-slate-300 hover:text-white hover:bg-cyan-950/50',
        ]"
      >
        <template v-if="item.path === '/app/perfil'">
          <div
            class="w-5 h-5 rounded-full overflow-hidden border shrink-0 flex items-center justify-center transition-all duration-200"
            :class="[
              route.path === item.path
                ? 'border-white ring-1 ring-white/60'
                : 'border-cyan-500/40 bg-cyan-950/60'
            ]"
          >
            <img
              v-if="authStore.profile?.avatar_url && !avatarError"
              :src="authStore.profile.avatar_url"
              :alt="authStore.profile?.display_name || 'Perfil'"
              class="w-full h-full object-cover"
              referrerpolicy="no-referrer"
              @error="avatarError = true"
            />
            <span
              v-else-if="authStore.profile?.display_name"
              class="text-[10px] font-bold"
              :class="route.path === item.path ? 'text-white' : 'text-cyan-300'"
            >
              {{ authStore.profile.display_name.charAt(0).toUpperCase() }}
            </span>
            <i v-else :class="['bi', item.icon, 'text-xs']"></i>
          </div>
        </template>
        <i v-else :class="['bi', item.icon, 'text-base shrink-0']"></i>
        <span class="truncate">{{ item.name }}</span>
      </NuxtLink>
    </nav>

    <!-- Logout Footer -->
    <div class="pt-4 border-t border-cyan-950/80">
      <button
        type="button"
        class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-950/30 transition-colors font-bold cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose-400"
        @click="handleLogout"
      >
        <i class="bi bi-box-arrow-right text-base"></i>
        <span>Cerrar Sesión</span>
      </button>
    </div>
  </aside>
</template>
