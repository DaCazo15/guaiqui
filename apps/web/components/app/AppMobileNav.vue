<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '~/stores/auth'

const route = useRoute()
const authStore = useAuthStore()
const avatarError = ref(false)

const navItems = [
  { name: 'Inicio', routeName: 'app', path: '/app', icon: 'bi-house-door-fill' },
  { name: 'Trivias', routeName: 'app-trivias', path: '/app/trivias', icon: 'bi-patch-question-fill' },
  { name: 'Billetera', routeName: 'app-billetera', path: '/app/billetera', icon: 'bi-wallet2' },
  { name: 'Tienda', routeName: 'app-tienda', path: '/app/tienda', icon: 'bi-bag-heart-fill' },
  { name: 'Perfil', routeName: 'app-perfil', path: '/app/perfil', icon: 'bi-person-fill' },
]
</script>

<template>
  <nav
    class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0B7A3B] bg-gradient-to-r from-[#064E27] via-[#0B7A3B] to-emerald-800 border-t-2 border-[#C8102E] shadow-2xl px-2 py-2 text-white"
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
        class="flex items-center justify-center min-w-[48px] min-h-[44px] p-2 rounded-xl transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
        :class="[
          route.name === item.routeName || route.path === item.path
            ? 'text-white font-black bg-black/30 ring-1 ring-white/30 shadow-inner'
            : 'text-emerald-100/75 hover:text-white hover:bg-white/10 font-semibold',
        ]"
      >
        <!-- Ícono personalizado para Perfil con foto circular del usuario -->
        <template v-if="item.path === '/app/perfil'">
          <div
            class="w-[28px] h-[28px] rounded-full overflow-hidden border flex items-center justify-center shrink-0 transition-colors duration-150"
            :class="[
              route.name === item.routeName || route.path === item.path
                ? 'border-white ring-2 ring-white shadow-xs'
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
              class="text-xs font-bold text-white bg-white/20 w-full h-full flex items-center justify-center leading-none"
            >
              {{ authStore.profile.display_name.charAt(0).toUpperCase() }}
            </span>
            <i v-else :class="['bi', item.icon, 'text-sm text-white']" aria-hidden="true"></i>
          </div>
        </template>
        <i v-else :class="['bi', item.icon, 'text-xl leading-none']" aria-hidden="true"></i>
        <span class="sr-only">{{ item.name }}</span>
      </NuxtLink>
    </div>
  </nav>
</template>
