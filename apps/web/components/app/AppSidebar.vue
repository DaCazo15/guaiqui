<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'
import { formatPerlitas } from '@guaiqui/shared'
import { PearlIcon } from '@guaiqui/ui'

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

import { APP_SIDEBAR_NAV_ITEMS } from '~/data/appNavData'

const navItems = APP_SIDEBAR_NAV_ITEMS

const handleLogout = async () => {
  await authStore.logout()
}
</script>

<template>
  <aside class="hidden md:flex flex-col w-64 bg-gradient-to-b from-[#01170f] via-[#022c1e] to-[#043e1e] border-r border-emerald-500/20 min-h-screen p-4 sticky top-0 h-screen text-white select-none shadow-2xl">
    <!-- Brand Logo -->
    <div class="flex items-center gap-2.5 px-3 py-3 mb-4 border-b border-emerald-500/20">
      <div class="w-11 h-11 rounded-2xl bg-slate-900/60 p-1.5 border border-emerald-500/30 shadow-md backdrop-blur-md flex items-center justify-center shrink-0">
        <img src="/logo.png" alt="Guaiqueríes Logo" class="w-full h-full object-contain" />
      </div>
      <div>
        <h1 class="font-display text-lg font-black text-white uppercase tracking-wider leading-tight">
          Guaiqueríes
        </h1>
        <span class="text-[11px] text-emerald-400 font-bold tracking-widest uppercase drop-shadow-[0_0_10px_rgba(52,211,153,0.4)]">
          Fan Zone
        </span>
      </div>
    </div>

    <!-- User Mini Card & Pearls Balance -->
    <div class="bg-slate-950/50 border border-emerald-500/30 rounded-2xl p-3 mb-5 flex items-center justify-between shadow-lg backdrop-blur-md">
      <div class="flex items-center gap-2.5 overflow-hidden">
        <div class="w-8 h-8 rounded-full bg-emerald-950/70 text-emerald-300 flex items-center justify-center font-bold text-sm shrink-0 overflow-hidden border border-emerald-500/40">
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
        <div class="truncate">
          <p class="text-xs font-bold text-white truncate leading-tight">
            {{ authStore.profile?.display_name || 'Fanático' }}
          </p>
          <span class="text-[10px] text-emerald-300/70 font-medium">
            {{ authStore.profile?.municipality || 'Nueva Esparta' }}
          </span>
        </div>
      </div>
      <div class="flex items-center gap-1.5 text-xs font-black text-amber-950 bg-amber-300 border border-amber-400 px-2.5 py-1 rounded-full shadow-xs shrink-0">
        <PearlIcon size="xs" animated />
        <span>{{ formatPerlitas(authStore.wallet?.balance_cache || 0) }}</span>
      </div>
    </div>

    <!-- Nav Links -->
    <nav class="flex-1 space-y-1 overflow-y-auto pr-1">
      <NuxtLink
        v-for="item in navItems"
        :key="item.routeName"
        :to="{ name: item.routeName }"
        class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
        :class="[
          route.name === item.routeName || route.path === item.path
            ? 'bg-white text-slate-950 font-black shadow-lg shadow-black/25 scale-[1.01]'
            : 'text-emerald-100/75 hover:text-white hover:bg-white/10',
        ]"
      >
        <template v-if="item.path === '/app/perfil'">
          <div
            class="w-5 h-5 rounded-full overflow-hidden border shrink-0 flex items-center justify-center transition-all duration-200"
            :class="[
              route.path === item.path
                ? 'border-slate-950 ring-1 ring-slate-950'
                : 'border-white/50 bg-slate-950/40'
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
              :class="route.path === item.path ? 'text-slate-950' : 'text-emerald-300'"
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
    <div class="pt-4 border-t border-emerald-500/20">
      <button
        type="button"
        class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-950/40 transition-colors font-bold cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose-400"
        @click="handleLogout"
      >
        <i class="bi bi-box-arrow-right text-base"></i>
        <span>Cerrar Sesión</span>
      </button>
    </div>
  </aside>
</template>
