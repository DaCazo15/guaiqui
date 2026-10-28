<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

import { APP_BOTTOM_NAV_ITEMS } from '~/data/appNavData'

const navItems = APP_BOTTOM_NAV_ITEMS
</script>

<template>
  <nav
    class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-gradient-to-b from-[#0e743a] via-[#09542a] to-[#043319] border-t-2 border-emerald-400/40 shadow-[0_-15px_40px_rgba(0,0,0,0.7)] px-3 py-2 text-white backdrop-blur-md"
    style="padding-bottom: max(0.5rem, env(safe-area-inset-bottom, 0px));"
    aria-label="Navegación principal inferior"
  >
    <div class="flex justify-around items-center">
      <NuxtLink
        v-for="item in navItems"
        :key="item.routeName"
        :to="{ name: item.routeName }"
        :aria-label="item.name"
        :aria-current="route.name === item.routeName || route.path === item.path ? 'page' : undefined"
        class="flex items-center justify-center min-w-[48px] min-h-[44px] p-2 rounded-2xl transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
        :class="[
          route.name === item.routeName || route.path === item.path
            ? 'bg-white text-slate-950 shadow-lg shadow-black/30 scale-105'
            : 'text-emerald-100/75 hover:text-white hover:bg-white/10',
        ]"
      >
        <!-- Ícono personalizado para Perfil con foto circular del usuario -->
        <template v-if="item.path === '/app/perfil'">
          <div
            class="w-[28px] h-[28px] rounded-full overflow-hidden border flex items-center justify-center shrink-0 transition-colors duration-200"
            :class="[
              route.name === item.routeName || route.path === item.path
                ? 'border-slate-950 ring-2 ring-slate-950 shadow-xs'
                : 'border-white/60 opacity-90'
            ]"
          >
            <img
              v-if="authStore.profile?.avatar_url && !avatarError"
              :src="authStore.profile.avatar_url"
              :alt="authStore.profile?.display_name || 'Perfil'"
              width="28"
              height="28"
              class="w-full h-full object-cover"
              referrerpolicy="no-referrer"
              @error="avatarError = true"
            />
            <span
              v-else-if="authStore.profile?.display_name"
              class="text-xs font-bold leading-none"
              :class="route.name === item.routeName || route.path === item.path ? 'text-slate-950' : 'text-white'"
            >
              {{ authStore.profile.display_name.charAt(0).toUpperCase() }}
            </span>
            <i
              v-else
              :class="[
                'bi',
                item.icon,
                'text-sm',
                route.name === item.routeName || route.path === item.path ? 'text-slate-950' : 'text-white'
              ]"
              aria-hidden="true"
            ></i>
          </div>
        </template>
        <i v-else :class="['bi', item.icon, 'text-xl leading-none']" aria-hidden="true"></i>
        <span class="sr-only">{{ item.name }}</span>
      </NuxtLink>
    </div>
  </nav>
</template>
